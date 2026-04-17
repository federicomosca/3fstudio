-- 009_admin_studios_policy.sql
-- Permette agli utenti con is_admin = true di leggere tutte le sedi.
-- Usa la tabella users (non user_studio_roles) per evitare la join ricorsiva
-- che causa timeout con le RLS policies sulle sedi.

DO $$ BEGIN
  CREATE POLICY "admin_can_read_all_studios"
    ON public.studios
    FOR SELECT
    TO authenticated
    USING (
      (SELECT is_admin FROM public.users WHERE id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
