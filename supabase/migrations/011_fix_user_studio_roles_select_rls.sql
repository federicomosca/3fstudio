-- ============================================================
-- Migration 011 — Fix RLS SELECT su user_studio_roles
--
-- Problema: la policy esistente filtra per studio_id = my_studio_id(),
-- impedendo di vedere le righe di tutte le sedi in una sola query.
-- Risultato: nel dropdown sedi l'utente vede solo la prima sede.
--
-- Fix: la policy SELECT deve permettere all'utente di leggere
-- TUTTE le proprie righe (qualunque studio_id).
-- ============================================================

-- Rimuove eventuali policy SELECT troppo restrittive
DROP POLICY IF EXISTS "user_studio_roles_select" ON public.user_studio_roles;
DROP POLICY IF EXISTS "Users can view their own studio roles" ON public.user_studio_roles;
DROP POLICY IF EXISTS "users_own_roles" ON public.user_studio_roles;
DROP POLICY IF EXISTS "user sees own roles" ON public.user_studio_roles;

-- Crea la policy corretta: l'utente vede tutte le sue righe
DO $$ BEGIN
  CREATE POLICY "user_studio_roles_select"
    ON public.user_studio_roles
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
