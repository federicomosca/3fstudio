-- La funzione promote_from_waitlist ordina per created_at, non per position.
-- Il campo position non è usato per la logica di promozione, quindi
-- aggiungiamo un DEFAULT 0 per evitare il NOT NULL constraint error.
ALTER TABLE waitlist ALTER COLUMN position SET DEFAULT 0;
