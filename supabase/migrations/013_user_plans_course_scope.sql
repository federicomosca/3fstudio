-- ============================================================
-- Migration 013 — Course-scoped plans + credit deduction tracking
--
-- user_plans.course_id (nullable):
--   NULL  → piano "Aperto" (valido per qualsiasi corso)
--   UUID  → piano limitato a quel corso specifico
--
-- bookings.credits_deducted (bool):
--   Evita la doppia scalata crediti se il trainer annulla/risegna
--   la presenza più volte.
-- ============================================================

ALTER TABLE public.user_plans
  ADD COLUMN IF NOT EXISTS course_id uuid
    REFERENCES public.courses(id) ON DELETE SET NULL;

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS credits_deducted boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_user_plans_course ON public.user_plans(course_id);
