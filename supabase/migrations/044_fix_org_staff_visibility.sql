-- ============================================================
-- Migration 044 — Fix visibilità trainer/corsi org-wide per client
--
-- Problema: "org members can read staff profiles" usa una subquery
-- su user_studio_roles che gira con i permessi del client.
-- La chain RLS può bloccare i trainer delle altre sedi.
--
-- Fix: SECURITY DEFINER function che legge user_studio_roles
-- bypassando RLS, come già fatto per my_org_studio_ids().
-- ============================================================

CREATE OR REPLACE FUNCTION public.org_staff_user_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT user_id
  FROM public.user_studio_roles
  WHERE role IN ('trainer', 'class_owner', 'owner')
    AND studio_id IN (SELECT public.my_org_studio_ids())
$$;

DROP POLICY IF EXISTS "org members can read staff profiles" ON public.users;
CREATE POLICY "org members can read staff profiles"
ON public.users FOR SELECT TO authenticated
USING (id IN (SELECT public.org_staff_user_ids()));
