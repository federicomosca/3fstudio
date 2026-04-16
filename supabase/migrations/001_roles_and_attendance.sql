-- ============================================================
-- Migration 001 — ruoli multipli, class_owner, presenze
-- Eseguire nel Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Aggiunge valori all'enum user_role
DO $$ BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'class_owner';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Aggiunge valori all'enum booking_status
DO $$ BEGIN
  ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'attended';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'no_show';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3. is_admin su users (superadmin app-level)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

UPDATE users SET is_admin = true WHERE email = 'federicomosca@pm.me';

-- 4. Supporto multi-ruolo in user_studio_roles:
--    rimuove il vecchio unique (user_id, studio_id)
--    e aggiunge unique (user_id, studio_id, role)
DO $$ BEGIN
  ALTER TABLE user_studio_roles
    DROP CONSTRAINT IF EXISTS user_studio_roles_user_id_studio_id_key;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE user_studio_roles
    ADD CONSTRAINT user_studio_roles_user_studio_role_key
    UNIQUE (user_id, studio_id, role);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

-- 5. class_owner_id e cancel_window_hours su courses
ALTER TABLE courses
  ADD COLUMN IF NOT EXISTS class_owner_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cancel_window_hours int NOT NULL DEFAULT 24;

-- 6. Indice per query "lezioni di un class_owner"
CREATE INDEX IF NOT EXISTS idx_courses_class_owner ON courses(class_owner_id);
CREATE INDEX IF NOT EXISTS idx_lessons_trainer ON lessons(trainer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_status ON bookings(user_id, status);
