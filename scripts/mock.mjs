/**
 * Mock data seed per AL.FA.SE asd — Vincenzo Alagna
 *
 * Utenti:
 *   - Vincenzo Alagna → owner + class_owner + trainer (entrambi gli studi)
 *   - Marco Russo     → trainer (sede principale)
 *   - Sara Conti      → class_owner + trainer (sede principale)
 *   - 4 clienti di test
 *
 * Studi:
 *   - AL.FA.SE asd — Via Aquileia 34, Palermo (sede principale)
 *   - AL.FA.SE asd — Filiale (sede secondaria)
 *
 * Idempotente: cancella tutto prima di inserire.
 */
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL     = 'https://qndkjgagyupogaibozbw.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuZGtqZ2FneXVwb2dhaWJvemJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjAwOTk1NywiZXhwIjoyMDkxNTg1OTU3fQ.cpF0UJSvwdNqWGCGH8myGEQ_0cSQwWJwbnf-a85BqIg';

const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ─── helpers ────────────────────────────────────────────────────────────────

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

function dt(offsetDays, hour, minute = 0) {
  const d = new Date('2026-04-13T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + offsetDays);
  d.setUTCHours(hour, minute, 0, 0);
  return d.toISOString();
}

// ─── main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('=== AL.FA.SE asd — Mock seed ===\n');

  // ── 0. Clean up ────────────────────────────────────────────────────────────
  console.log('0. Pulizia dati precedenti...');
  await sb.from('waitlist').delete().neq('position', -999);
  await sb.from('bookings').delete().neq('status', '__never__');
  await sb.from('user_plans').delete().neq('credits_remaining', -999);
  await sb.from('lessons').delete().neq('capacity', -999);
  await sb.from('courses').delete().neq('name', '__never__');
  await sb.from('rooms').delete().neq('name', '__never__');
  await sb.from('plans').delete().neq('name', '__never__');
  await sb.from('user_studio_roles').delete().in('role', ['trainer', 'client', 'class_owner', 'owner']);
  await sb.from('studios').delete().neq('name', '__never__');

  const mockEmails = [
    'vincenzo@albase.it',
    'marco@albase.it',
    'sara@albase.it',
    'cliente1@albase.it', 'cliente2@albase.it', 'cliente3@albase.it', 'cliente4@albase.it',
    // vecchi mock
    'vicio@testgym.it', 'luca@testgym.it', 'francesca@testgym.it',
    'alice@test.it', 'bob@test.it', 'chiara@test.it', 'davide@test.it',
  ];
  const { data: authList } = await sb.auth.admin.listUsers();
  for (const u of authList.users) {
    if (mockEmails.includes(u.email)) await sb.auth.admin.deleteUser(u.id);
  }
  await sb.from('users').delete().in('email', mockEmails);
  console.log('  Fatto.\n');

  // ── 1. Studios ─────────────────────────────────────────────────────────────
  console.log('1. Studi...');
  const [sedePrincipale, sedeFiliale] = await insert('studios', [
    {
      name:        'AL.FA.SE asd',
      address:     'Via Aquileia, 34 – Palermo',
      description: 'Qui non ti alleni, impari ad allenarti.',
    },
    {
      name:        'AL.FA.SE asd — Filiale',
      address:     'Via Regione Siciliana, 3604 – Palermo',
      description: 'Seconda sede AL.FA.SE.',
    },
  ]);
  console.log(`  ${sedePrincipale.name} (${sedePrincipale.id})`);
  console.log(`  ${sedeFiliale.name}   (${sedeFiliale.id})\n`);

  // ── 2. Auth users ──────────────────────────────────────────────────────────
  console.log('2. Utenti auth...');
  const vincenzoAuth = await upsertAuthUser('vincenzo@albase.it', 'Vicio123!',   'Vincenzo Alagna');
  const marcoAuth    = await upsertAuthUser('marco@albase.it',    'Trainer123!', 'Marco Russo');
  const saraAuth     = await upsertAuthUser('sara@albase.it',     'Trainer123!', 'Sara Conti');
  const c1Auth       = await upsertAuthUser('cliente1@albase.it', 'Client123!',  'Giulia Messina');
  const c2Auth       = await upsertAuthUser('cliente2@albase.it', 'Client123!',  'Antonio Lombardo');
  const c3Auth       = await upsertAuthUser('cliente3@albase.it', 'Client123!',  'Maria Trovato');
  const c4Auth       = await upsertAuthUser('cliente4@albase.it', 'Client123!',  'Salvatore Amato');
  console.log('  vincenzo, marco, sara, 4 clienti — creati.\n');

  // ── 3. Profili pubblici ────────────────────────────────────────────────────
  console.log('3. Profili pubblici...');
  for (const [auth, fullName, phone] of [
    [vincenzoAuth, 'Vincenzo Alagna',   '3208907595'],
    [marcoAuth,    'Marco Russo',       null],
    [saraAuth,     'Sara Conti',        null],
    [c1Auth,       'Giulia Messina',    null],
    [c2Auth,       'Antonio Lombardo',  null],
    [c3Auth,       'Maria Trovato',     null],
    [c4Auth,       'Salvatore Amato',   null],
  ]) {
    await sb.from('users').upsert(
      { id: auth.id, email: auth.email, full_name: fullName, phone },
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

  // ── 4. Ruoli studio ────────────────────────────────────────────────────────
  console.log('4. Ruoli...');
  await insert('user_studio_roles', [
    // Vincenzo: owner + class_owner + trainer su entrambi gli studi
    { user_id: vincenzoAuth.id, studio_id: sedePrincipale.id, role: 'owner'       },
    { user_id: vincenzoAuth.id, studio_id: sedePrincipale.id, role: 'class_owner' },
    { user_id: vincenzoAuth.id, studio_id: sedePrincipale.id, role: 'trainer'     },
    { user_id: vincenzoAuth.id, studio_id: sedeFiliale.id,    role: 'owner'       },
    { user_id: vincenzoAuth.id, studio_id: sedeFiliale.id,    role: 'class_owner' },
    { user_id: vincenzoAuth.id, studio_id: sedeFiliale.id,    role: 'trainer'     },
    // Marco: trainer sede principale
    { user_id: marcoAuth.id, studio_id: sedePrincipale.id, role: 'trainer' },
    // Sara: class_owner + trainer sede principale
    { user_id: saraAuth.id, studio_id: sedePrincipale.id, role: 'class_owner' },
    { user_id: saraAuth.id, studio_id: sedePrincipale.id, role: 'trainer'     },
    // Clienti: sede principale
    { user_id: c1Auth.id, studio_id: sedePrincipale.id, role: 'client' },
    { user_id: c2Auth.id, studio_id: sedePrincipale.id, role: 'client' },
    { user_id: c3Auth.id, studio_id: sedePrincipale.id, role: 'client' },
    { user_id: c4Auth.id, studio_id: sedePrincipale.id, role: 'client' },
  ]);
  console.log('  Fatto.\n');

  // ── 5. Sale ────────────────────────────────────────────────────────────────
  console.log('5. Sale...');
  const [salaGrande, salaPiccola] = await insert('rooms', [
    { name: 'Sala Grande',   studio_id: sedePrincipale.id, capacity: 15 },
    { name: 'Sala Specchi',  studio_id: sedePrincipale.id, capacity: 8  },
  ]);
  const [salaFiliale] = await insert('rooms', [
    { name: 'Sala Unica', studio_id: sedeFiliale.id, capacity: 10 },
  ]);
  console.log(`  ${salaGrande.name}, ${salaPiccola.name}, ${salaFiliale.name}\n`);

  // ── 6. Corsi ───────────────────────────────────────────────────────────────
  console.log('6. Corsi...');
  const [percorsoM3F, posturale, kettlebell, bodyweight, animalFlow, pt] = await insert('courses', [
    {
      name: 'Percorso M3F',
      studio_id: sedePrincipale.id,
      type: 'group',
      description: 'Metodo di allenamento funzionale progressivo.',
      class_owner_id: vincenzoAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Ginnastica Posturale',
      studio_id: sedePrincipale.id,
      type: 'group',
      description: 'Analisi posturale e rieducazione motoria.',
      class_owner_id: saraAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Kettlebell Training',
      studio_id: sedePrincipale.id,
      type: 'group',
      description: 'Allenamento con kettlebell per forza e resistenza.',
      class_owner_id: vincenzoAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Body Weight Training',
      studio_id: sedePrincipale.id,
      type: 'group',
      description: 'Allenamento a corpo libero ad alta intensità.',
      class_owner_id: vincenzoAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Animal Flow',
      studio_id: sedePrincipale.id,
      type: 'group',
      description: 'Movimento corporeo ispirato al mondo animale.',
      class_owner_id: saraAuth.id,
      cancel_window_hours: 24,
    },
    {
      name: 'Personal Training',
      studio_id: sedePrincipale.id,
      type: 'personal',
      description: 'Sessione di allenamento personalizzata 1:1.',
      class_owner_id: vincenzoAuth.id,
      cancel_window_hours: 48,
    },
  ]);
  console.log(`  ${[percorsoM3F, posturale, kettlebell, bodyweight, animalFlow, pt].map(c => c.name).join(', ')}\n`);

  // ── 7. Piani ───────────────────────────────────────────────────────────────
  console.log('7. Piani...');
  const [piano10, pianoMensile, pianoProva, pianoPrep] = await insert('plans', [
    { name: 'Pacchetto 10 lezioni', studio_id: sedePrincipale.id, type: 'credits',   credits: 10,  price: 80,  duration_days: 90  },
    { name: 'Mensile Unlimited',    studio_id: sedePrincipale.id, type: 'unlimited',  credits: null, price: 70, duration_days: 30  },
    { name: 'Lezione di prova',     studio_id: sedePrincipale.id, type: 'trial',      credits: 1,   price: 0,  duration_days: 30  },
    {
      name: 'Prep. Atletica Forze Armate',
      studio_id: sedePrincipale.id,
      type: 'credits',
      credits: 20,
      price: 140,
      duration_days: 180,
    },
  ]);
  console.log(`  ${[piano10, pianoMensile, pianoProva, pianoPrep].map(p => p.name).join(', ')}\n`);

  // ── 8. Piani utenti ────────────────────────────────────────────────────────
  console.log('8. Piani utenti...');
  await insert('user_plans', [
    { user_id: c1Auth.id, plan_id: piano10.id,     credits_remaining: 7,  expires_at: '2026-07-01' },
    { user_id: c2Auth.id, plan_id: pianoMensile.id, credits_remaining: null, expires_at: '2026-05-13' },
    { user_id: c3Auth.id, plan_id: pianoProva.id,  credits_remaining: 1,  expires_at: '2026-04-27' },
    { user_id: c4Auth.id, plan_id: pianoPrep.id,   credits_remaining: 14, expires_at: '2026-10-01' },
  ]);
  console.log('  Fatto.\n');

  // ── 9. Lezioni ─────────────────────────────────────────────────────────────
  console.log('9. Lezioni...');
  const lessons = [];

  // Lezioni passate (ultime 2 settimane)
  for (const [day, hour, course, room, cap, trainer] of [
    [-13, 9,  percorsoM3F, salaGrande,  15, vincenzoAuth],
    [-13, 18, kettlebell,  salaPiccola,  8, marcoAuth   ],
    [-11, 9,  posturale,   salaGrande,  15, saraAuth    ],
    [-11, 17, pt,          salaPiccola,  1, vincenzoAuth],
    [-9,  9,  percorsoM3F, salaGrande,  15, vincenzoAuth],
    [-9,  18, bodyweight,  salaPiccola,  8, marcoAuth   ],
    [-7,  9,  animalFlow,  salaGrande,  15, saraAuth    ],
    [-7,  17, pt,          salaPiccola,  1, vincenzoAuth],
    [-6,  10, kettlebell,  salaPiccola,  8, marcoAuth   ],
    [-4,  9,  posturale,   salaGrande,  15, saraAuth    ],
    [-2,  9,  percorsoM3F, salaGrande,  15, vincenzoAuth],
    [-2,  18, bodyweight,  salaPiccola,  8, marcoAuth   ],
  ]) {
    lessons.push({
      course_id:  course.id,
      room_id:    room.id,
      trainer_id: trainer.id,
      starts_at:  dt(day, hour),
      ends_at:    dt(day, hour + 1),
      capacity:   cap,
    });
  }

  // Lezioni future (oggi + 2 settimane)
  for (const [day, hour, course, room, cap, trainer] of [
    [0,  9,  percorsoM3F, salaGrande,  15, vincenzoAuth],
    [0,  18, kettlebell,  salaPiccola,  8, marcoAuth   ],
    [1,  9,  posturale,   salaGrande,  15, saraAuth    ],
    [1,  17, pt,          salaPiccola,  1, vincenzoAuth],
    [2,  18, bodyweight,  salaPiccola,  8, marcoAuth   ],
    [4,  9,  animalFlow,  salaGrande,  15, saraAuth    ],
    [4,  18, kettlebell,  salaPiccola,  8, vincenzoAuth],
    [5,  17, pt,          salaPiccola,  1, vincenzoAuth],
    [7,  9,  percorsoM3F, salaGrande,  15, marcoAuth   ],
    [7,  18, bodyweight,  salaPiccola,  8, vincenzoAuth],
    [8,  9,  posturale,   salaGrande,  15, saraAuth    ],
    [9,  17, pt,          salaPiccola,  1, vincenzoAuth],
    [9,  18, kettlebell,  salaPiccola,  8, marcoAuth   ],
    [11, 9,  animalFlow,  salaGrande,  15, saraAuth    ],
    [11, 18, bodyweight,  salaPiccola,  8, vincenzoAuth],
    [13, 9,  percorsoM3F, salaGrande,  15, vincenzoAuth],
    [13, 17, pt,          salaPiccola,  1, vincenzoAuth],
    [14, 9,  posturale,   salaGrande,  15, saraAuth    ],
    [14, 18, kettlebell,  salaPiccola,  8, marcoAuth   ],
  ]) {
    lessons.push({
      course_id:  course.id,
      room_id:    room.id,
      trainer_id: trainer.id,
      starts_at:  dt(day, hour),
      ends_at:    dt(day, hour + 1),
      capacity:   cap,
    });
  }

  const insertedLessons = await insert('lessons', lessons);
  console.log(`  ${insertedLessons.length} lezioni create.\n`);

  // ── 10. Prenotazioni ───────────────────────────────────────────────────────
  console.log('10. Prenotazioni...');
  const futureLessons = insertedLessons.filter(l => new Date(l.starts_at) > new Date());
  const pastLessons   = insertedLessons.filter(l => new Date(l.starts_at) <= new Date());

  const bookings = [];

  // Passate
  for (const l of pastLessons.filter(l => l.course_id === percorsoM3F.id).slice(0, 4)) {
    bookings.push({ user_id: c1Auth.id, lesson_id: l.id, status: 'confirmed' });
    bookings.push({ user_id: c2Auth.id, lesson_id: l.id, status: 'confirmed' });
  }
  for (const l of pastLessons.filter(l => l.course_id === posturale.id).slice(0, 3)) {
    bookings.push({ user_id: c3Auth.id, lesson_id: l.id, status: 'confirmed' });
  }

  // Future
  const m3fFuture  = futureLessons.filter(l => l.course_id === percorsoM3F.id);
  const postFuture = futureLessons.filter(l => l.course_id === posturale.id);
  const ptFuture   = futureLessons.filter(l => l.course_id === pt.id);
  const kbFuture   = futureLessons.filter(l => l.course_id === kettlebell.id);

  for (const l of m3fFuture.slice(0, 4))  bookings.push({ user_id: c1Auth.id, lesson_id: l.id, status: 'confirmed' });
  for (const l of m3fFuture.slice(0, 3))  bookings.push({ user_id: c2Auth.id, lesson_id: l.id, status: 'confirmed' });
  for (const l of postFuture.slice(0, 3)) bookings.push({ user_id: c3Auth.id, lesson_id: l.id, status: 'confirmed' });
  for (const l of kbFuture.slice(0, 2))   bookings.push({ user_id: c4Auth.id, lesson_id: l.id, status: 'confirmed' });
  for (const l of ptFuture.slice(0, 2))   bookings.push({ user_id: c1Auth.id, lesson_id: l.id, status: 'confirmed' });
  if (m3fFuture[4]) bookings.push({ user_id: c4Auth.id, lesson_id: m3fFuture[4].id, status: 'cancelled' });

  // Dedup
  const seen = new Set();
  const deduped = bookings.filter(b => {
    const key = `${b.user_id}-${b.lesson_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  await insert('bookings', deduped);
  console.log(`  ${deduped.length} prenotazioni create.\n`);

  // ── 11. Waitlist ───────────────────────────────────────────────────────────
  console.log('11. Waitlist...');
  if (ptFuture[0]) {
    const alreadyBooked = deduped.find(b => b.lesson_id === ptFuture[0].id && b.status === 'confirmed');
    if (!alreadyBooked) {
      await insert('bookings', [{ user_id: c2Auth.id, lesson_id: ptFuture[0].id, status: 'confirmed' }]);
    }
    await insert('waitlist', [{ user_id: c3Auth.id, lesson_id: ptFuture[0].id, position: 1 }]);
    console.log('  Maria Trovato in waitlist sul PT.\n');
  }

  // ── Riepilogo ──────────────────────────────────────────────────────────────
  console.log('=== Seed completato ===\n');
  console.log('Studio principale : AL.FA.SE asd — Via Aquileia 34, Palermo');
  console.log('Studio secondario : AL.FA.SE asd — Filiale, Via Regione Siciliana 3604, Palermo\n');
  console.log('Credenziali:');
  console.log('  vincenzo@albase.it   / Vicio123!    → owner + class_owner + trainer (entrambi gli studi)');
  console.log('  marco@albase.it      / Trainer123!  → trainer (sede principale)');
  console.log('  sara@albase.it       / Trainer123!  → class_owner + trainer (sede principale)');
  console.log('  cliente1@albase.it   / Client123!   → Giulia Messina   — 7 crediti');
  console.log('  cliente2@albase.it   / Client123!   → Antonio Lombardo — unlimited');
  console.log('  cliente3@albase.it   / Client123!   → Maria Trovato    — prova, waitlist PT');
  console.log('  cliente4@albase.it   / Client123!   → Salvatore Amato  — 14 crediti prep');
  console.log('  federicomosca@pm.me  → admin (is_admin=true)\n');
  console.log(`Corsi: Percorso M3F, Ginnastica Posturale, Kettlebell, Body Weight, Animal Flow, Personal Training`);
  console.log(`Lezioni: ${insertedLessons.length} totali  |  Prenotazioni: ${deduped.length}`);
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
