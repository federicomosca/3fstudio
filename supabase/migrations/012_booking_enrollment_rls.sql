-- ============================================================
-- Migration 012 — RLS enforcement: clients can only book
--                 courses they are enrolled in
--
-- Un client può:
--   • Inserire una prenotazione "prova" (pending + is_trial = true)
--     per qualsiasi lezione del proprio studio
--   • Inserire una prenotazione confermata (confirmed) SOLO se ha
--     già almeno una prenotazione confirmed/attended per una lezione
--     dello stesso corso (= è "iscritto" al corso)
-- ============================================================

-- Rimuovi la vecchia policy permissiva, se esiste
DROP POLICY IF EXISTS "clients can book lessons"           ON bookings;
DROP POLICY IF EXISTS "clients can insert bookings"        ON bookings;
DROP POLICY IF EXISTS "users can insert own bookings"      ON bookings;
DROP POLICY IF EXISTS "authenticated users can book"       ON bookings;
DROP POLICY IF EXISTS "clients can book enrolled or trial" ON bookings;

-- Nuova policy INSERT
--
-- Logica:
--  • Se lo status NON è 'confirmed' (es. pending/trial) → sempre consentito
--  • Se lo status È 'confirmed' → solo se il client ha già almeno una
--    prenotazione confirmed/attended per una lezione dello stesso corso
CREATE POLICY "clients can book enrolled or trial"
ON bookings
FOR INSERT
WITH CHECK (
  -- Deve essere la propria prenotazione
  auth.uid() = user_id
  AND (
    -- Non-confirmed (trial, pending, ecc.) → sempre permesso
    status <> 'confirmed'::booking_status

    -- Confirmed → solo se già iscritto al corso
    OR EXISTS (
      SELECT 1
      FROM   bookings b
      JOIN   lessons  l_existing ON l_existing.id = b.lesson_id
      JOIN   lessons  l_new      ON l_new.id      = lesson_id
      WHERE  b.user_id            = auth.uid()
        AND  b.status            IN ('confirmed'::booking_status, 'attended'::booking_status)
        AND  l_existing.course_id = l_new.course_id
    )
  )
);

-- Cancella anche la vecchia policy di UPDATE (se troppo permissiva),
-- mantenendo quella corretta di migration 003
-- (nessuna modifica necessaria, già presente)
