-- ============================================================
-- Migration 014 — user_plans status (active / suspended / cancelled)
--
-- active    → piano in uso, valido per prenotazioni
-- suspended → congelato temporaneamente, non usabile
-- cancelled → terminato dall'owner, escluso dalla vista cliente
-- ============================================================

ALTER TABLE public.user_plans
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'cancelled'));

CREATE INDEX IF NOT EXISTS idx_user_plans_status ON public.user_plans(status);
