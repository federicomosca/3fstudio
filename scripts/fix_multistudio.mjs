const TOKEN = 'sbp_117b9c4efe6b741702fa23403e4e596913675862';
const REF   = 'qndkjgagyupogaibozbw';

const sql = `
-- 1. default_studio_id su users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS default_studio_id uuid REFERENCES studios(id) ON DELETE SET NULL;

-- 2. Owner può vedere tutti gli studi di cui è proprietario
DROP POLICY IF EXISTS owners_view_all_their_studios ON studios;
CREATE POLICY owners_view_all_their_studios
ON studios FOR SELECT
USING (
  id IN (
    SELECT studio_id FROM user_studio_roles
    WHERE user_id = auth.uid() AND role = 'owner'
  )
);
`;

const res  = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: sql }),
});
const body = await res.json();
if (body.message) { console.error('Errore:', body.message); process.exit(1); }
console.log('OK:', JSON.stringify(body));
