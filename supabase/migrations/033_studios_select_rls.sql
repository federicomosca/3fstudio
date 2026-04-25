-- ============================================================
-- Migration 033 — SELECT policy su studios per utenti normali
--
-- Problema: l'unica policy SELECT su studios era per is_admin.
-- Owner, trainer e client non potevano leggere la propria sede
-- tramite la join user_studio_roles → studios, quindi
-- userSediProvider tornava vuoto e currentStudioIdProvider = null.
-- ============================================================

CREATE POLICY "users can read own studios"
ON public.studios
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_studio_roles
    WHERE studio_id = studios.id
      AND user_id   = auth.uid()
  )
);
