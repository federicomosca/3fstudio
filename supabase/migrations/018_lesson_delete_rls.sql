-- Migration 018 — RLS per la proposta/eliminazione lezioni da parte di trainer e class_owner
--
-- Problemi risolti:
--   1. Trainer non può aggiornare status → propose_delete non funziona (UPDATE silenzioso)
--   2. Class_owner non può eliminare lezioni → delete diretto non funziona
--   3. Class_owner non può eliminare prenotazioni associate alla lezione eliminata

-- ── Trainer: può proporre eliminazione (status active → delete_pending) ────────
DROP POLICY IF EXISTS "trainer can propose lesson deletion" ON lessons;
CREATE POLICY "trainer can propose lesson deletion"
ON lessons FOR UPDATE
USING (
  has_role('trainer') AND
  trainer_id = auth.uid() AND
  status = 'active'
)
WITH CHECK (
  status = 'delete_pending'
);

-- ── Class owner: può eliminare lezioni dei propri corsi ──────────────────────
DROP POLICY IF EXISTS "class_owner can delete own course lessons" ON lessons;
CREATE POLICY "class_owner can delete own course lessons"
ON lessons FOR DELETE
USING (
  has_role('class_owner') AND
  course_id IN (
    SELECT id FROM courses WHERE class_owner_id = auth.uid()
  )
);

-- ── Class owner: può eliminare le prenotazioni delle lezioni che elimina ─────
DROP POLICY IF EXISTS "class_owner can delete course lesson bookings" ON bookings;
CREATE POLICY "class_owner can delete course lesson bookings"
ON bookings FOR DELETE
USING (
  lesson_id IN (
    SELECT l.id FROM lessons l
    JOIN courses c ON c.id = l.course_id
    WHERE c.class_owner_id = auth.uid()
      AND has_role('class_owner')
  )
);
