-- ============================================================
-- Migration 015 — RLS write policies for studios table
--
-- Problema: mancano le policy INSERT / UPDATE / DELETE sulla
-- tabella studios. Il DELETE dal client Flutter ritorna 0 righe
-- senza errore perché RLS blocca silenziosamente l'operazione.
--
-- Fix: un gym_owner può modificare ed eliminare le sedi a cui
-- appartiene; può anche inserire nuove sedi (il seed/admin-create
-- assegna poi il ruolo).
-- ============================================================

-- ── INSERT ────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE POLICY "owner_can_insert_studio"
    ON public.studios
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── UPDATE ────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE POLICY "owner_can_update_studio"
    ON public.studios
    FOR UPDATE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_studio_roles
        WHERE studio_id = studios.id
          AND user_id  = auth.uid()
          AND role     = 'owner'
      )
    )
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── DELETE ────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE POLICY "owner_can_delete_studio"
    ON public.studios
    FOR DELETE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_studio_roles
        WHERE studio_id = studios.id
          AND user_id  = auth.uid()
          AND role     = 'owner'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
