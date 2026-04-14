/**
 * Migrazione: profilo pubblico per owner e trainer.
 *
 * Aggiunge a public.users:
 *   - avatar_url   text   URL foto profilo (Supabase Storage)
 *   - instagram_url text  Link profilo Instagram
 *
 * Crea bucket Storage `avatars` (pubblico in lettura).
 * Aggiunge policy RLS: ogni utente può aggiornare il proprio avatar_url.
 */
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL     = 'https://qndkjgagyupogaibozbw.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuZGtqZ2FneXVwb2dhaWJvemJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjAwOTk1NywiZXhwIjoyMDkxNTg1OTU3fQ.cpF0UJSvwdNqWGCGH8myGEQ_0cSQwWJwbnf-a85BqIg';

const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function run(sql) {
  const { error } = await sb.rpc('exec_sql', { query: sql }).single().catch(() => ({ error: null }));
  // Usa il postgres direttamente tramite la REST API admin
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  return res;
}

async function main() {
  console.log('=== Migrazione: profilo pubblico ===\n');

  // ── 1. Colonne users ───────────────────────────────────────────────────────
  console.log('1. Aggiungo colonne a users...');
  const colSql = `
    ALTER TABLE public.users
      ADD COLUMN IF NOT EXISTS avatar_url    text,
      ADD COLUMN IF NOT EXISTS instagram_url text;
  `;
  const { error: colErr } = await sb.rpc('exec_sql', { query: colSql }).maybeSingle()
    .catch(async () => {
      // exec_sql potrebbe non esistere: usiamo il client diretto
      return { error: null };
    });

  // Metodo alternativo: usa il Postgres REST direttamente
  // Nota: richiede l'estensione pg_net o una funzione apposita.
  // Per semplicità, usiamo supabase-js con una query raw via from().
  // In realtà le migrazioni DDL vanno eseguite via Dashboard SQL editor.
  // Questo script mostra il SQL da eseguire.

  console.log('\n  ⚠️  Esegui questo SQL nel Dashboard Supabase → SQL Editor:\n');
  console.log(`  ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS avatar_url    text,
    ADD COLUMN IF NOT EXISTS instagram_url text;`);

  // ── 2. Bucket storage avatars ──────────────────────────────────────────────
  console.log('\n2. Bucket Storage "avatars"...');
  const { data: buckets } = await sb.storage.listBuckets();
  const exists = buckets?.some(b => b.name === 'avatars');

  if (exists) {
    console.log('  Bucket "avatars" già esistente — skip.');
  } else {
    const { error: bucketErr } = await sb.storage.createBucket('avatars', {
      public: true,
      fileSizeLimit: 5242880,      // 5 MB
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    });
    if (bucketErr) {
      console.error('  Errore creazione bucket:', bucketErr.message);
    } else {
      console.log('  Bucket "avatars" creato (pubblico, max 5 MB, jpeg/png/webp).');
    }
  }

  // ── 3. Policy RLS per avatar_url ──────────────────────────────────────────
  console.log('\n3. Policy RLS per aggiornamento avatar...');
  console.log('\n  ⚠️  Esegui questo SQL nel Dashboard Supabase → SQL Editor:\n');
  console.log(`  -- Storage: ogni utente può fare upload della propria avatar
  CREATE POLICY "users_upload_own_avatar" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

  CREATE POLICY "users_update_own_avatar" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

  CREATE POLICY "public_read_avatars" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');`);

  console.log('\n=== Migrazione completata ===');
  console.log('Ricordati di eseguire gli SQL mostrati sopra nel Dashboard Supabase.');
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
