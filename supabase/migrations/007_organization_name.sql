-- 007_organization_name.sql
-- Aggiunge il nome dell'organizzazione alla sede (es. "AL.FA.SE asd").
-- Separato dal nome della sede fisica (es. "Via Aquileia 34").

alter table public.studios
  add column if not exists organization_name text;

-- Pre-popola con il valore attuale di name per le sedi esistenti
update public.studios set organization_name = 'AL.FA.SE asd';
