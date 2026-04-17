-- 008_shared_course_type.sql
-- Aggiunge il tipo di corso "shared" (semi-personal, 2-3 persone).

DO $$ BEGIN
  ALTER TYPE course_type ADD VALUE IF NOT EXISTS 'shared';
EXCEPTION WHEN undefined_object THEN
  -- La colonna usa text+check invece di enum — aggiorna il constraint.
  ALTER TABLE public.courses
    DROP CONSTRAINT IF EXISTS courses_type_check;
  ALTER TABLE public.courses
    ADD CONSTRAINT courses_type_check
    CHECK (type IN ('group', 'personal', 'shared'));
END $$;
