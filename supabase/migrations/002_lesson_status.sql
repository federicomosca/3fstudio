-- ============================================================
-- Migration 002 — lesson status + proposal workflow
-- Consente ai class_owner di proporre lezioni che l'owner approva
-- Eseguire nel Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. status è un enum (lesson_status) — aggiunge i valori mancanti
DO $$ BEGIN
  ALTER TYPE lesson_status ADD VALUE IF NOT EXISTS 'pending';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE lesson_status ADD VALUE IF NOT EXISTS 'rejected';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Chi ha proposto la lezione
DO $$ BEGIN
  ALTER TABLE lessons
    ADD COLUMN proposed_by uuid REFERENCES users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- 3. Nota opzionale in caso di rifiuto
DO $$ BEGIN
  ALTER TABLE lessons
    ADD COLUMN review_note text;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- 4. Indice per query "lezioni pending di uno studio" (via course)
CREATE INDEX IF NOT EXISTS idx_lessons_status ON lessons(status);

-- 5. RLS: i client vedono solo lezioni active
--    (se non c'era già questa policy)
-- Le policy esistenti potrebbero già filtrare per status = 'active',
-- altrimenti aggiungere:
-- CREATE POLICY "clients see active lessons" ON lessons
--   FOR SELECT USING (status = 'active');
