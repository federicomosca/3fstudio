-- ============================================================
-- Migration 004 — lezioni di prova (trial bookings)
-- Eseguire nel Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Aggiunge 'pending' all'enum booking_status
DO $$ BEGIN
  ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'pending';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Colonna is_trial su bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS is_trial boolean NOT NULL DEFAULT false;

-- 3. Indice per query "prenotazioni prova in attesa di uno studio"
CREATE INDEX IF NOT EXISTS idx_bookings_pending_trial
  ON bookings(status, is_trial) WHERE status = 'pending';
