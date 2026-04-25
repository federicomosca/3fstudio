-- ============================================================
-- Migration 032 — booked_count e waitlist_count su lessons
--
-- Problema: bookings e waitlist hanno RLS che limita i client
-- a vedere solo le proprie righe. La query `bookings(status)` nel
-- client restituiva 0 o 1 invece del conteggio reale.
--
-- Fix: counter denormalizzati su lessons, aggiornati da trigger
-- SECURITY DEFINER — leggibili da chiunque possa leggere la lezione.
-- ============================================================

ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS booked_count   integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS waitlist_count integer NOT NULL DEFAULT 0;

-- Inizializza dai dati esistenti
UPDATE lessons l
SET booked_count = (
  SELECT COUNT(*) FROM bookings b
  WHERE b.lesson_id = l.id
    AND b.status NOT IN ('cancelled', 'pending')
);

UPDATE lessons l
SET waitlist_count = (
  SELECT COUNT(*) FROM waitlist w
  WHERE w.lesson_id = l.id
);

-- ── Trigger booked_count ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_lesson_booked_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('cancelled', 'pending') THEN
      UPDATE lessons SET booked_count = booked_count + 1 WHERE id = NEW.lesson_id;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status NOT IN ('cancelled', 'pending') AND NEW.status IN ('cancelled', 'pending') THEN
      UPDATE lessons SET booked_count = GREATEST(booked_count - 1, 0) WHERE id = NEW.lesson_id;
    ELSIF OLD.status IN ('cancelled', 'pending') AND NEW.status NOT IN ('cancelled', 'pending') THEN
      UPDATE lessons SET booked_count = booked_count + 1 WHERE id = NEW.lesson_id;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.status NOT IN ('cancelled', 'pending') THEN
      UPDATE lessons SET booked_count = GREATEST(booked_count - 1, 0) WHERE id = OLD.lesson_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_bookings_update_lesson_count ON bookings;
CREATE TRIGGER trg_bookings_update_lesson_count
AFTER INSERT OR UPDATE OR DELETE ON bookings
FOR EACH ROW EXECUTE FUNCTION sync_lesson_booked_count();

-- ── Trigger waitlist_count ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_lesson_waitlist_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE lessons SET waitlist_count = waitlist_count + 1 WHERE id = NEW.lesson_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE lessons SET waitlist_count = GREATEST(waitlist_count - 1, 0) WHERE id = OLD.lesson_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_waitlist_update_lesson_count ON waitlist;
CREATE TRIGGER trg_waitlist_update_lesson_count
AFTER INSERT OR DELETE ON waitlist
FOR EACH ROW EXECUTE FUNCTION sync_lesson_waitlist_count();
