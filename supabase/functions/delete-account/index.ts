import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const errorResponse = (msg: string, status = 400) =>
  new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // ── Verifica JWT ────────────────────────────────────────────────────────
    const jwt = req.headers.get('authorization')?.replace('Bearer ', '');
    if (!jwt) return errorResponse('Unauthorized', 401);

    let userId: string;
    try {
      const jwks = createRemoteJWKSet(
        new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
      );
      const { payload } = await jwtVerify(jwt, jwks);
      userId = payload.sub as string;
    } catch {
      // Fallback: verifica con getUser
      const anonClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!);
      const { data: { user }, error } = await anonClient.auth.getUser(jwt);
      if (error || !user) return errorResponse('Unauthorized', 401);
      userId = user.id;
    }

    // ── 1. Avatar da Storage (best effort) ──────────────────────────────────
    try {
      await adminClient.storage.from('avatars').remove([`${userId}/avatar`]);
    } catch (_) { /* ignora se non esiste */ }

    // ── 2. Elimina il profilo da public.users ────────────────────────────────
    // Questo rimuove in cascade bookings, user_plans, user_studio_roles (FK CASCADE).
    // Va fatto prima di deleteUser perché public.users referenzia auth.users;
    // senza questa delete esplicita il db solleva FK violation se CASCADE non è
    // configurato sulla colonna id di public.users.
    const { error: profileError } = await adminClient
      .from('users')
      .delete()
      .eq('id', userId);
    if (profileError) throw profileError;

    // ── 3. Elimina l'utente da auth ──────────────────────────────────────────
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return errorResponse(msg, 500);
  }
});
