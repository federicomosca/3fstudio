import { readFileSync } from 'fs';

const TOKEN = 'sbp_117b9c4efe6b741702fa23403e4e596913675862';
const REF   = 'qndkjgagyupogaibozbw';

const sql = `
-- 1. Fix my_role(): ritorna il ruolo con priorità più alta
CREATE OR REPLACE FUNCTION my_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM user_studio_roles
  WHERE user_id = auth.uid()
  ORDER BY
    CASE role
      WHEN 'owner'       THEN 1
      WHEN 'class_owner' THEN 2
      WHEN 'trainer'     THEN 3
      WHEN 'client'      THEN 4
      ELSE 5
    END
  LIMIT 1;
$$;

-- 2. has_role(): controlla se l'utente ha uno specifico ruolo
CREATE OR REPLACE FUNCTION has_role(r user_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_studio_roles
    WHERE user_id = auth.uid() AND role = r
  );
$$;

-- 3. Owner può vedere tutti gli utenti del suo studio
DROP POLICY IF EXISTS owners_view_studio_members ON users;
CREATE POLICY owners_view_studio_members
ON users FOR SELECT
USING (
  has_role('owner') AND
  id IN (
    SELECT user_id FROM user_studio_roles
    WHERE studio_id = my_studio_id()
  )
);

-- 4. Staff (trainer / class_owner) può vedere i membri del suo studio
DROP POLICY IF EXISTS staff_view_studio_members ON users;
CREATE POLICY staff_view_studio_members
ON users FOR SELECT
USING (
  (has_role('trainer') OR has_role('class_owner')) AND
  id IN (
    SELECT user_id FROM user_studio_roles
    WHERE studio_id = my_studio_id()
  )
);
`;

const res  = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: sql }),
});
const body = await res.json();
if (!res.ok || body.message) {
  console.error('Errore:', JSON.stringify(body, null, 2));
  process.exit(1);
}
console.log('RLS fix applicato:', JSON.stringify(body));
