const TOKEN = 'sbp_117b9c4efe6b741702fa23403e4e596913675862';
const REF   = 'qndkjgagyupogaibozbw';

const sql = `
-- ── Nuove colonne su users ────────────────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone                text,
  ADD COLUMN IF NOT EXISTS bio                  text,
  ADD COLUMN IF NOT EXISTS specializations      text[],
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

-- ── Nuove colonne su studios ──────────────────────────────────────────────────
ALTER TABLE studios
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS is_personal  boolean NOT NULL DEFAULT false;

-- ── RPC complete_registration (SECURITY DEFINER → bypassa RLS) ───────────────
CREATE OR REPLACE FUNCTION complete_registration(
  p_full_name          text,
  p_phone              text    DEFAULT NULL,
  p_bio                text    DEFAULT NULL,
  p_specializations    text[]  DEFAULT NULL,
  p_role               text    DEFAULT 'client',
  p_studio_name        text    DEFAULT NULL,
  p_studio_address     text    DEFAULT NULL,
  p_studio_description text    DEFAULT NULL,
  p_is_personal_studio boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_email     text;
  v_studio_id uuid;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  -- 1. Crea / aggiorna profilo pubblico
  INSERT INTO public.users (id, email, full_name, phone, bio, specializations)
  VALUES (v_uid, v_email, p_full_name, p_phone, p_bio, p_specializations)
  ON CONFLICT (id) DO UPDATE
    SET full_name        = EXCLUDED.full_name,
        phone            = COALESCE(EXCLUDED.phone,            users.phone),
        bio              = COALESCE(EXCLUDED.bio,              users.bio),
        specializations  = COALESCE(EXCLUDED.specializations,  users.specializations);

  -- 2. Owner: crea studio + ruolo
  IF p_role = 'owner' AND p_studio_name IS NOT NULL THEN
    INSERT INTO studios (name, address, description, is_personal)
    VALUES (p_studio_name, p_studio_address, p_studio_description, false)
    RETURNING id INTO v_studio_id;

    INSERT INTO user_studio_roles (user_id, studio_id, role)
    VALUES (v_uid, v_studio_id, 'owner');

    UPDATE public.users SET default_studio_id = v_studio_id WHERE id = v_uid;

    RETURN jsonb_build_object('studio_id', v_studio_id, 'role', 'owner');

  -- 3. Trainer indipendente: crea studio personale con tutti i ruoli
  ELSIF p_role = 'trainer' AND p_is_personal_studio AND p_studio_name IS NOT NULL THEN
    INSERT INTO studios (name, address, description, is_personal)
    VALUES (p_studio_name, p_studio_address, p_studio_description, true)
    RETURNING id INTO v_studio_id;

    INSERT INTO user_studio_roles (user_id, studio_id, role) VALUES (v_uid, v_studio_id, 'owner');
    INSERT INTO user_studio_roles (user_id, studio_id, role) VALUES (v_uid, v_studio_id, 'class_owner');
    INSERT INTO user_studio_roles (user_id, studio_id, role) VALUES (v_uid, v_studio_id, 'trainer');

    UPDATE public.users SET default_studio_id = v_studio_id WHERE id = v_uid;

    RETURN jsonb_build_object('studio_id', v_studio_id, 'role', 'trainer', 'is_class_owner', true);

  -- 4. Trainer che cerca studio dopo
  ELSIF p_role = 'trainer' THEN
    RETURN jsonb_build_object('role', 'trainer', 'needs_studio', true);

  -- 5. Client
  ELSE
    RETURN jsonb_build_object('role', 'client');
  END IF;
END;
$$;

-- ── Policy INSERT su studios per il RPC (non serve, SECURITY DEFINER) ─────────
-- Il RPC bypassa RLS quindi non serve una INSERT policy.
-- Tuttavia l'utente autenticato deve poter aggiornare il proprio studio dopo.
DROP POLICY IF EXISTS owner_insert_studio ON studios;
CREATE POLICY owner_insert_studio ON studios FOR INSERT
  WITH CHECK (
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
console.log('Migration OK:', JSON.stringify(body));
