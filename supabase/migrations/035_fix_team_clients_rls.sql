-- ============================================================
-- Migration 035 — Fix RLS per team e clienti
--
-- Problema: la policy "owner reads studio roles" usa my_studio_id()
-- su user_studio_roles stessa — potenziale ricorsione / valore
-- errato in contesto multi-sede.
--
-- Fix: funzione SECURITY DEFINER che legge user_studio_roles
-- bypassando RLS, usata nelle policy di users e user_studio_roles.
-- ============================================================

-- Restituisce tutti gli studio_id in cui l'utente corrente è owner.
-- SECURITY DEFINER: bypassa RLS su user_studio_roles.
CREATE OR REPLACE FUNCTION my_owned_studio_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT studio_id
  FROM public.user_studio_roles
  WHERE user_id = auth.uid()
    AND role    = 'owner'
$$;

-- Restituisce tutti gli user_id che appartengono a uno studio dato.
-- SECURITY DEFINER: bypassa RLS su user_studio_roles.
CREATE OR REPLACE FUNCTION studio_member_ids(p_studio_id uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT user_id
  FROM public.user_studio_roles
  WHERE studio_id = p_studio_id
$$;

-- ── user_studio_roles: rimpiazza la policy con una senza ricorsione ────────────

DROP POLICY IF EXISTS "owner reads studio roles" ON user_studio_roles;
CREATE POLICY "owner reads studio roles"
ON user_studio_roles FOR SELECT TO authenticated
USING (
  studio_id IN (SELECT my_owned_studio_ids())
);

-- ── users: rimpiazza le policy che usavano subquery su user_studio_roles ───────

DROP POLICY IF EXISTS "owner reads studio users" ON users;
CREATE POLICY "owner reads studio users"
ON users FOR SELECT TO authenticated
USING (
  id IN (
    SELECT studio_member_ids(s)
    FROM (SELECT unnest(array(SELECT my_owned_studio_ids()))) AS t(s)
  )
);

DROP POLICY IF EXISTS "staff reads studio users" ON users;
CREATE POLICY "staff reads studio users"
ON users FOR SELECT TO authenticated
USING (
  (has_role('trainer') OR has_role('class_owner')) AND
  id IN (SELECT studio_member_ids(my_studio_id()))
);

-- ── user_plans: rimpiazza la policy con la versione sicura ────────────────────

DROP POLICY IF EXISTS "owner manages studio user_plans" ON user_plans;
CREATE POLICY "owner manages studio user_plans"
ON user_plans FOR ALL TO authenticated
USING (
  user_id IN (
    SELECT studio_member_ids(s)
    FROM (SELECT unnest(array(SELECT my_owned_studio_ids()))) AS t(s)
  )
)
WITH CHECK (
  has_role('owner')
);
