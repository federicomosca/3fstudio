import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

function b64UrlDecode(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

async function verifyJWT(token: string, supabaseUrl: string): Promise<string | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;

  let header: { alg: string; kid?: string };
  let payload: { sub?: string; exp?: number };
  try {
    header = JSON.parse(new TextDecoder().decode(b64UrlDecode(headerB64)));
    payload = JSON.parse(new TextDecoder().decode(b64UrlDecode(payloadB64)));
  } catch { return null; }

  if (payload.exp && payload.exp < Date.now() / 1000) return null;
  if (!payload.sub) return null;

  const msg = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sig = b64UrlDecode(sigB64);

  try {
    if (header.alg === 'HS256') {
      const secret = Deno.env.get('SUPABASE_JWT_SECRET');
      if (!secret) return null;
      const key = await crypto.subtle.importKey(
        'raw', new TextEncoder().encode(secret),
        { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
      );
      const ok = await crypto.subtle.verify('HMAC', key, sig, msg);
      return ok ? payload.sub : null;
    }

    if (header.alg === 'ES256') {
      const resp = await fetch(`${supabaseUrl}/auth/v1/.well-known/jwks.json`);
      if (!resp.ok) return null;
      const { keys } = await resp.json() as { keys: JsonWebKey[] };
      const jwk = (keys ?? []).find((k: any) => !header.kid || k.kid === header.kid);
      if (!jwk) return null;
      const key = await crypto.subtle.importKey(
        'jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify'],
      );
      const ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, sig, msg);
      return ok ? payload.sub ?? null : null;
    }
  } catch { return null; }

  return null;
}

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

    const jwt = req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
    if (!jwt) return errorResponse('Unauthorized', 401);

    const callerId = await verifyJWT(jwt, supabaseUrl);
    if (!callerId) return errorResponse('Unauthorized', 401);

    const { data: ownerRows } = await adminClient
      .from('user_studio_roles')
      .select('role')
      .eq('user_id', callerId)
      .eq('role', 'owner');

    const isOwner = (ownerRows ?? []).length > 0;

    if (!isOwner) {
      return errorResponse('Permesso negato', 403);
    }

    const { name, address, organization_name }: {
      name: string;
      address?: string;
      organization_name?: string;
    } = await req.json();

    if (!name?.trim()) {
      return errorResponse('Il nome della sede è obbligatorio', 400);
    }

    const { data: studio, error: studioErr } = await adminClient
      .from('studios')
      .insert({
        name: name.trim(),
        ...(address?.trim() ? { address: address.trim() } : {}),
        ...(organization_name?.trim() ? { organization_name: organization_name.trim() } : {}),
      })
      .select('id, name, address, organization_name')
      .single();

    if (studioErr) return errorResponse(studioErr.message, 500);

    const { error: roleErr } = await adminClient
      .from('user_studio_roles')
      .insert({ user_id: callerId, studio_id: studio.id, role: 'owner' });

    if (roleErr) {
      await adminClient.from('studios').delete().eq('id', studio.id);
      return errorResponse(roleErr.message, 500);
    }

    return new Response(
      JSON.stringify(studio),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return errorResponse(`Errore interno: ${e}`, 500);
  }
});
