import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://qndkjgagyupogaibozbw.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuZGtqZ2FneXVwb2dhaWJvemJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjAwOTk1NywiZXhwIjoyMDkxNTg1OTU3fQ.cpF0UJSvwdNqWGCGH8myGEQ_0cSQwWJwbnf-a85BqIg';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function upsertAuthUser(email, password, displayName, appMetadata = {}) {
  const { data: list } = await supabase.auth.admin.listUsers();
  const existing = list?.users?.find(u => u.email === email);
  if (existing) {
    console.log(`  Deleting existing: ${email}`);
    await supabase.auth.admin.deleteUser(existing.id);
  }
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: displayName },
    app_metadata: appMetadata,
  });
  if (error) throw new Error(`createUser ${email}: ${error.message}`);
  console.log(`  Auth user created: ${email} → ${data.user.id}`);
  return data.user;
}

async function upsertUserProfile(id, fields) {
  const { error } = await supabase.from('users').upsert({ id, ...fields }, { onConflict: 'id' });
  if (error) console.warn(`  users upsert warn: ${error.message}`);
}

async function main() {
  console.log('=== Seeding Place ===\n');

  // ── 1. Admin ──────────────────────────────────────────────────────────────
  console.log('1. Admin user');
  const admin = await upsertAuthUser(
    'federicomosca@pm.me',
    'Pbe@Q^Ndz@Kkf5gwUs#V',
    'Federico Mosca',
    { role: 'admin' },
  );
  await upsertUserProfile(admin.id, { email: 'federicomosca@pm.me' });

  // ── 2. Gym owner ──────────────────────────────────────────────────────────
  console.log('\n2. Gym owner');
  const owner = await upsertAuthUser(
    'gymowner@test.it',
    'gymownpsw',
    'Gym Owner',
    { role: 'owner' },
  );
  await upsertUserProfile(owner.id, { email: 'gymowner@test.it' });

  // ── 3. Studio ─────────────────────────────────────────────────────────────
  console.log('\n3. Studio');
  // Delete existing studios to keep seed idempotent
  await supabase.from('studios').delete().neq('id', '00000000-0000-0000-0000-000000000000');

  const { data: studio, error: studioErr } = await supabase
    .from('studios')
    .insert({ name: 'TestGym' })
    .select()
    .single();
  if (studioErr) throw new Error(`studio insert: ${studioErr.message}`);
  console.log(`  Studio: ${studio.name} (${studio.id})`);

  // ── 4. Link owner → studio ────────────────────────────────────────────────
  console.log('\n4. user_studio_roles');
  await supabase.from('user_studio_roles').delete().eq('user_id', owner.id);
  const { error: roleErr } = await supabase.from('user_studio_roles').insert({
    user_id: owner.id,
    studio_id: studio.id,
    role: 'owner',
  });
  if (roleErr) throw new Error(`role insert: ${roleErr.message}`);
  console.log('  Owner linked to TestGym.');

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log('\n=== Done ===');
  console.log('  Admin  → federicomosca@pm.me  / Pbe@Q^Ndz@Kkf5gwUs#V');
  console.log('  Owner  → gymowner@test.it      / gymownpsw');
  console.log(`  Studio → TestGym (id: ${studio.id})`);
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });