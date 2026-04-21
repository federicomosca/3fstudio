-- Sconto 2° corso a livello studio
ALTER TABLE studios
  ADD COLUMN IF NOT EXISTS second_course_discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0;

-- Modalità consentite per corso (quali formule l'owner abilita)
ALTER TABLE courses
  ADD COLUMN IF NOT EXISTS allows_group    BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allows_shared   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allows_personal BOOLEAN NOT NULL DEFAULT false;
