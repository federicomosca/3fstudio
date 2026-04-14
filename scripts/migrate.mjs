/**
 * Applica la migration 001 via Supabase Management API.
 * Richiede SUPABASE_ACCESS_TOKEN (personal access token dal dashboard).
 *
 * Alternativa: incollare supabase/migrations/001_roles_and_attendance.sql
 * nel Supabase Dashboard → SQL Editor.
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const PROJECT_REF = 'qndkjgagyupogaibozbw';
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN;

if (!ACCESS_TOKEN) {
  console.error('Imposta SUPABASE_ACCESS_TOKEN e riprova.');
  console.error('Oppure esegui il file SQL manualmente nel Supabase Dashboard → SQL Editor.');
  process.exit(1);
}

const __dir = dirname(fileURLToPath(import.meta.url));
const sql = readFileSync(join(__dir, '../supabase/migrations/001_roles_and_attendance.sql'), 'utf8');

const res = await fetch(
  `https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`,
  {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  }
);

const body = await res.json();
if (!res.ok) {
  console.error('Errore:', JSON.stringify(body, null, 2));
  process.exit(1);
}
console.log('Migration applicata con successo.');
console.log(JSON.stringify(body, null, 2));
