-- ============================================================
-- Migration 043 — Studio info visibile a tutti i membri dell'org
--
-- Problema: i client vedono solo la loro sede e non possono
-- leggere i trainer/corsi delle altre sedi della stessa org.
-- La StudioInfoScreen mostra dati incompleti.
--
-- Fix:
-- 1. my_org_studio_ids(): restituisce tutti gli studio_id
--    dell'organizzazione dell'utente corrente (SECURITY DEFINER)
-- 2. Estende policy studios/courses a org-wide
-- 3. Aggiunge policy per leggere ruoli e profili trainer/owner
-- ============================================================

-- Helper SECURITY DEFINER: bypassa RLS su studios e user_studio_roles
CREATE OR REPLACE FUNCTION public.my_org_studio_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  -- Sedi con organization_name: tutte della stessa org
  SELECT s2.id
  FROM public.studios s2
  WHERE s2.organization_name IS NOT NULL
    AND s2.organization_name IN (
      SELECT s1.organization_name
      FROM public.studios s1
      JOIN public.user_studio_roles usr ON usr.studio_id = s1.id
      WHERE usr.user_id = auth.uid()
    )
  UNION
  -- Sedi senza organization_name: solo quelle dell'utente
  SELECT s3.id
  FROM public.studios s3
  WHERE s3.organization_name IS NULL
    AND EXISTS (
      SELECT 1 FROM public.user_studio_roles
      WHERE studio_id = s3.id AND user_id = auth.uid()
    )
$$;

-- ── Studios ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "users can read own studios" ON public.studios;
CREATE POLICY "users can read org studios"
ON public.studios FOR SELECT TO authenticated
USING (id IN (SELECT public.my_org_studio_ids()));

-- ── Courses ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "studio members can view courses" ON public.courses;
CREATE POLICY "org members can view courses"
ON public.courses FOR SELECT TO authenticated
USING (studio_id IN (SELECT public.my_org_studio_ids()));

-- ── user_studio_roles: lettura ruoli staff di tutta l'org ─────────────────────
-- (si aggiunge alla policy "user_studio_roles_select" che permette
--  all'utente di leggere le proprie righe)

DROP POLICY IF EXISTS "org members can read staff roles" ON public.user_studio_roles;
CREATE POLICY "org members can read staff roles"
ON public.user_studio_roles FOR SELECT TO authenticated
USING (
  role IN ('trainer', 'class_owner', 'owner') AND
  studio_id IN (SELECT public.my_org_studio_ids())
);

-- ── users: lettura profili trainer/owner di tutta l'org ───────────────────────

DROP POLICY IF EXISTS "org members can read staff profiles" ON public.users;
CREATE POLICY "org members can read staff profiles"
ON public.users FOR SELECT TO authenticated
USING (
  id IN (
    SELECT user_id FROM public.user_studio_roles
    WHERE role IN ('trainer', 'class_owner', 'owner')
      AND studio_id IN (SELECT public.my_org_studio_ids())
  )
);
