-- 010_remove_admin.sql
-- Rimuove il concetto di "admin" app-level: l'owner è il top-level user.

-- Rimuove prima la policy che dipende dalla colonna
DROP POLICY IF EXISTS "admin_can_read_all_studios" ON public.studios;

ALTER TABLE public.users DROP COLUMN IF EXISTS is_admin;

-- Assicura che ogni owner veda gli studio a cui appartiene
-- (policy già esistente nel base schema, questa è idempotente)
DO $$ BEGIN
  CREATE POLICY "owner_sees_own_studios"
    ON public.studios
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_studio_roles
        WHERE studio_id = studios.id
          AND user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
