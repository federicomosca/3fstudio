import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createRemoteJWKSet, jwtVerify } from 'https://esm.sh/jose@5';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Admin client (service role) ────────────────────────────────────────
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // ── Verifica JWT con JOSE (supporta ES256 e HS256) ─────────────────────
    const jwt = req.headers.get('authorization')?.replace('Bearer ', '');
    if (!jwt) return errorResponse('Unauthorized', 401);

    let callerId: string;
    try {
      const JWKS = createRemoteJWKSet(
        new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
      );
      const { payload } = await jwtVerify(jwt, JWKS);
      callerId = payload.sub as string;
      if (!callerId) throw new Error('sub mancante');
    } catch {
      return errorResponse('Unauthorized', 401);
    }

    // ── Leggi parametri ────────────────────────────────────────────────────
    const {
      full_name,
      email,
      password,
      role,       // 'trainer' | 'class_owner' | 'client'
      studio_id,
      phone,
    }: {
      full_name: string;
      email: string;
      password: string;
      role: string;
      studio_id: string;
      phone?: string;
    } = await req.json();

    if (!full_name || !email || !password || !role || !studio_id) {
      return errorResponse('Parametri mancanti: full_name, email, password, role, studio_id', 400);
    }

    // Verifica che il caller sia owner dello studio specificato
    const { data: ownerCheck } = await adminClient
      .from('user_studio_roles')
      .select('role')
      .eq('user_id', callerId)
      .eq('studio_id', studio_id)
      .eq('role', 'owner')
      .maybeSingle();

    const { data: isAdminRow } = await adminClient
      .from('users')
      .select('is_admin')
      .eq('id', callerId)
      .maybeSingle();

    const isAdmin = isAdminRow?.is_admin === true;

    if (!ownerCheck && !isAdmin) {
      return errorResponse('Permesso negato: non sei owner di questo studio', 403);
    }

    // ── Crea auth user ─────────────────────────────────────────────────────
    const { data: newUserData, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: full_name },
    });

    if (createErr) return errorResponse(createErr.message, 400);
    const userId = newUserData.user.id;

    // ── Crea profilo pubblico ──────────────────────────────────────────────
    const { error: profileErr } = await adminClient.from('users').insert({
      id: userId,
      email,
      full_name,
      phone: phone ?? null,
    });

    if (profileErr) {
      await adminClient.auth.admin.deleteUser(userId);
      return errorResponse(`Errore profilo: ${profileErr.message}`, 500);
    }

    // ── Assegna ruolo studio ───────────────────────────────────────────────
    const rolesToInsert: { user_id: string; studio_id: string; role: string }[] = [
      { user_id: userId, studio_id, role },
    ];

    if (role === 'class_owner') {
      rolesToInsert.push({ user_id: userId, studio_id, role: 'trainer' });
    }

    const { error: roleErr } = await adminClient.from('user_studio_roles').insert(rolesToInsert);

    if (roleErr) {
      await adminClient.auth.admin.deleteUser(userId);
      return errorResponse(`Errore ruolo: ${roleErr.message}`, 500);
    }

    return new Response(
      JSON.stringify({ user_id: userId, email, full_name }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return errorResponse(`Errore interno: ${e}`, 500);
  }
});

function errorResponse(message: string, status: number) {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}
