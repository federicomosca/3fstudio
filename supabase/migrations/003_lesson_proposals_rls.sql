-- ============================================================
-- Migration 003 — RLS proposte lezioni + fix lesson_status enum
--
-- ATTENZIONE: eseguire in DUE step separati nel SQL Editor
-- (PostgreSQL non permette di usare un nuovo valore enum
--  nella stessa transazione in cui viene aggiunto)
-- ============================================================

-- ── STEP 1 — esegui questo blocco da solo ────────────────────
ALTER TYPE lesson_status ADD VALUE IF NOT EXISTS 'active';

-- ── STEP 2 — esegui questo blocco dopo aver eseguito STEP 1 ──

-- Imposta 'active' come default per le nuove lezioni
ALTER TABLE lessons
  ALTER COLUMN status SET DEFAULT 'active';

-- Allinea le lezioni esistenti (seed inserito senza status esplicito)
UPDATE lessons
SET status = 'active'
WHERE status NOT IN ('pending', 'rejected', 'cancelled');

-- RLS: i client possono vedere trainer/staff del proprio studio
DROP POLICY IF EXISTS clients_view_studio_staff ON users;
CREATE POLICY clients_view_studio_staff
ON users FOR SELECT
USING (
  has_role('client') AND
  id IN (
    SELECT user_id FROM user_studio_roles
    WHERE studio_id = my_studio_id()
      AND role IN ('trainer', 'class_owner', 'owner')
  )
);

-- Owner e trainer possono aggiornare lo status delle prenotazioni (presenze)
DROP POLICY IF EXISTS "staff can update booking attendance" ON bookings;
CREATE POLICY "staff can update booking attendance"
ON bookings
FOR UPDATE
USING (
  lesson_id IN (
    SELECT l.id FROM lessons l
    JOIN courses c ON c.id = l.course_id
    WHERE
      (has_role('owner')       AND c.studio_id = my_studio_id()) OR
      (has_role('class_owner') AND c.class_owner_id = auth.uid()) OR
      (has_role('trainer')     AND l.trainer_id = auth.uid())
  )
);

-- RLS: il class_owner può proporre lezioni (status pending) per i propri corsi
DROP POLICY IF EXISTS "class_owner can propose lessons" ON lessons;
CREATE POLICY "class_owner can propose lessons"
ON lessons
FOR INSERT
WITH CHECK (
  has_role('class_owner') AND
  status = 'pending' AND
  proposed_by = auth.uid() AND
  course_id IN (
    SELECT id FROM courses WHERE class_owner_id = auth.uid()
  )
);
