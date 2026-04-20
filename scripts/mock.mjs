/**
 * Minimal test seed — 1 owner, 2 trainer, 2 client
 * Idempotente: cancella tutto prima di inserire.
 */
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL     = 'https://qndkjgagyupogaibozbw.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuZGtqZ2FneXVwb2dhaWJvemJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjAwOTk1NywiZXhwIjoyMDkxNTg1OTU3fQ.cpF0UJSvwdNqWGCGH8myGEQ_0cSQwWJwbnf-a85BqIg';

const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function insert(table, rows) {
  const arr = Array.isArray(rows) ? rows : [rows];
  const { data, error } = await sb.from(table).insert(arr).select();
  if (error) throw new Error(`[${table}] ${error.message}`);
  return data;
}

async function upsertAuthUser(email, password, fullName) {
  const { data: list } = await sb.auth.admin.listUsers();
  const existing = list?.users?.find(u => u.email === email);
  if (existing) {
    await sb.auth.admin.updateUser(existing.id, {
      password,
      user_metadata: { display_name: fullName },
    });
    return existing;
  }
  const { data, error } = await sb.auth.admin.createUser({
    email, password,
    email_confirm: true,
    user_metadata: { display_name: fullName },
  });
  if (error) throw new Error(`createUser ${email}: ${error.message}`);
  return data.user;
}

function dt(offsetDays, hour) {
  const d = new Date('2026-04-19T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + offsetDays);
  d.setUTCHours(hour, 0, 0, 0);
  return d.toISOString();
}

async function main() {
  console.log('=== 3F Training — Test seed ===\n');

  // ── 0. Clean up ────────────────────────────────────────────────────────────
  console.log('0. Pulizia...');
  await sb.from('waitlist').delete().neq('position', -999);
  await sb.from('bookings').delete().neq('status', '__never__');
  await sb.from('user_plans').delete().neq('credits_remaining', -999);
  await sb.from('lessons').delete().neq('capacity', -999);
  await sb.from('courses').delete().neq('name', '__never__');
  await sb.from('rooms').delete().neq('name', '__never__');
  await sb.from('plans').delete().neq('name', '__never__');
  await sb.from('user_studio_roles').delete().in('role', ['trainer', 'client', 'class_owner', 'owner']);
  await sb.from('studios').delete().neq('name', '__never__');

  const allEmails = [
    'owner@3f.it', 't1@3f.it', 't2@3f.it', 'c1@3f.it', 'c2@3f.it',
    // vecchi mock
    'vincenzo@albase.it', 'marco@albase.it', 'sara@albase.it',
    'cliente1@albase.it', 'cliente2@albase.it', 'cliente3@albase.it', 'cliente4@albase.it',
    'vicio@testgym.it', 'luca@testgym.it', 'francesca@testgym.it',
    'alice@test.it', 'bob@test.it', 'chiara@test.it', 'davide@test.it',
  ];
  const { data: authList } = await sb.auth.admin.listUsers();
  for (const u of authList.users) {
    if (allEmails.includes(u.email)) await sb.auth.admin.deleteUser(u.id);
  }
  await sb.from('users').delete().in('email', allEmails);
  console.log('  Fatto.\n');

  // ── 1. Studio ──────────────────────────────────────────────────────────────
  console.log('1. Studio...');
  const [studio] = await insert('studios', {
    name:        'AL.FA.SE asd',
    address:     'Via Aquileia, 34 – Palermo',
    description: 'Qui non ti alleni, impari ad allenarti.',
  });
  console.log(`  ${studio.name} (${studio.id})\n`);

  // ── 2. Auth users ──────────────────────────────────────────────────────────
  console.log('2. Utenti...');
  const ownerAuth = await upsertAuthUser('owner@3f.it', 'owner123', 'Owner Test');
  const t1Auth    = await upsertAuthUser('t1@3f.it',    'train123', 'Trainer Uno');
  const t2Auth    = await upsertAuthUser('t2@3f.it',    'train123', 'Trainer Due');
  const c1Auth    = await upsertAuthUser('c1@3f.it',    'client123', 'Client Uno');
  const c2Auth    = await upsertAuthUser('c2@3f.it',    'client123', 'Client Due');
  console.log('  owner, t1, t2, c1, c2 — creati.\n');

  // ── 3. Profili ─────────────────────────────────────────────────────────────
  console.log('3. Profili...');
  for (const [auth, fullName] of [
    [ownerAuth, 'Owner Test'],
    [t1Auth,    'Trainer Uno'],
    [t2Auth,    'Trainer Due'],
    [c1Auth,    'Client Uno'],
    [c2Auth,    'Client Due'],
  ]) {
    await sb.from('users').upsert(
      { id: auth.id, email: auth.email, full_name: fullName },
      { onConflict: 'id' },
    );
  }

  // Admin (Federico)
  const { data: authAll } = await sb.auth.admin.listUsers();
  const adminAuth = authAll.users.find(u => u.email === 'federicomosca@pm.me');
  if (adminAuth) {
    await sb.from('users').upsert(
      { id: adminAuth.id, email: adminAuth.email, full_name: 'Federico Mosca', is_admin: true },
      { onConflict: 'id' },
    );
  }
  console.log('  Fatto.\n');

  // ── 4. Ruoli ───────────────────────────────────────────────────────────────
  console.log('4. Ruoli...');
  await insert('user_studio_roles', [
    { user_id: ownerAuth.id, studio_id: studio.id, role: 'owner'       },
    { user_id: ownerAuth.id, studio_id: studio.id, role: 'class_owner' },
    { user_id: ownerAuth.id, studio_id: studio.id, role: 'trainer'     },
    { user_id: t1Auth.id,    studio_id: studio.id, role: 'trainer'     },
    { user_id: t2Auth.id,    studio_id: studio.id, role: 'class_owner' },
    { user_id: t2Auth.id,    studio_id: studio.id, role: 'trainer'     },
    { user_id: c1Auth.id,    studio_id: studio.id, role: 'client'      },
    { user_id: c2Auth.id,    studio_id: studio.id, role: 'client'      },
  ]);
  console.log('  Fatto.\n');

  // ── 5. Sala ────────────────────────────────────────────────────────────────
  console.log('5. Sala...');
  const [sala] = await insert('rooms', { name: 'Sala Principale', studio_id: studio.id, capacity: 15 });
  console.log(`  ${sala.name}\n`);

  // ── 6. Corsi ───────────────────────────────────────────────────────────────
  console.log('6. Corsi...');
  const [corsoA, corsoB] = await insert('courses', [
    {
      name: 'Corso A',
      studio_id: studio.id,
      type: 'group',
      description: 'Corso di test A.',
      class_owner_id: ownerAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Corso B',
      studio_id: studio.id,
      type: 'group',
      description: 'Corso di test B.',
      class_owner_id: t2Auth.id,
      cancel_window_hours: 24,
    },
  ]);
  console.log(`  ${corsoA.name}, ${corsoB.name}\n`);

  // ── 7. Piani ───────────────────────────────────────────────────────────────
  console.log('7. Piani...');
  const [piano10, pianoMensile] = await insert('plans', [
    { name: 'Pacchetto 10', studio_id: studio.id, type: 'credits',   credits: 10,  price: 80, duration_days: 90 },
    { name: 'Mensile',      studio_id: studio.id, type: 'unlimited', credits: null, price: 70, duration_days: 30 },
  ]);
  await insert('user_plans', [
    { user_id: c1Auth.id, plan_id: piano10.id,     credits_remaining: 8,    expires_at: '2026-07-01' },
    { user_id: c2Auth.id, plan_id: pianoMensile.id, credits_remaining: null, expires_at: '2026-05-19' },
  ]);
  console.log('  Fatto.\n');

  // ── 8. Lezioni ─────────────────────────────────────────────────────────────
  console.log('8. Lezioni...');
  const lessonRows = [];
  for (const [day, hour, course, trainer] of [
    // passate
    [-7, 9,  corsoA, ownerAuth],
    [-5, 18, corsoB, t2Auth   ],
    [-3, 9,  corsoA, t1Auth   ],
    [-1, 18, corsoB, t2Auth   ],
    // future
    [0,  9,  corsoA, ownerAuth],
    [1,  18, corsoB, t2Auth   ],
    [3,  9,  corsoA, t1Auth   ],
    [5,  18, corsoB, t2Auth   ],
    [7,  9,  corsoA, ownerAuth],
  ]) {
    lessonRows.push({
      course_id:  course.id,
      room_id:    sala.id,
      trainer_id: trainer.id,
      starts_at:  dt(day, hour),
      ends_at:    dt(day, hour + 1),
      capacity:   15,
    });
  }
  const lessons = await insert('lessons', lessonRows);
  console.log(`  ${lessons.length} lezioni create.\n`);

  // ── 9. Prenotazioni ────────────────────────────────────────────────────────
  console.log('9. Prenotazioni...');
  const future = lessons.filter(l => new Date(l.starts_at) > new Date());
  const bookings = [];
  for (const l of future.slice(0, 3)) bookings.push({ user_id: c1Auth.id, lesson_id: l.id, status: 'confirmed' });
  for (const l of future.slice(0, 2)) bookings.push({ user_id: c2Auth.id, lesson_id: l.id, status: 'confirmed' });
  await insert('bookings', bookings);
  console.log(`  ${bookings.length} prenotazioni create.\n`);

  // ── Riepilogo ──────────────────────────────────────────────────────────────
  console.log('=== Seed completato ===\n');
  console.log('Credenziali:');
  console.log('  owner@3f.it   / owner123   → owner + class_owner + trainer');
  console.log('  t1@3f.it      / train123   → trainer');
  console.log('  t2@3f.it      / train123   → class_owner + trainer');
  console.log('  c1@3f.it      / client123  → client (8 crediti)');
  console.log('  c2@3f.it      / client123  → client (mensile)');
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
