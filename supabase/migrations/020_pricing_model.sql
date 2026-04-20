-- Tariffa oraria base per corso
ALTER TABLE courses
  ADD COLUMN hourly_rate NUMERIC(10,2) NOT NULL DEFAULT 0;

-- Moltiplicatori tariffari a livello studio
ALTER TABLE studios
  ADD COLUMN group_surcharge_pct    NUMERIC(5,2) NOT NULL DEFAULT 20,
  ADD COLUMN shared_surcharge_pct   NUMERIC(5,2) NOT NULL DEFAULT 50,
  ADD COLUMN personal_surcharge_pct NUMERIC(5,2) NOT NULL DEFAULT 100,
  ADD COLUMN open_surcharge_pct     NUMERIC(5,2) NOT NULL DEFAULT 15;

-- Snapshot tariffario e formula sull'assegnazione piano
ALTER TABLE user_plans
  ADD COLUMN formula        TEXT,            -- 'group'|'shared'|'personal'|'open'
  ADD COLUMN rate_snapshot  NUMERIC(10,2),   -- tariffa effettiva al momento dell'assegnazione
  ADD COLUMN price_paid     NUMERIC(10,2);   -- prezzo effettivo pagato dal cliente
