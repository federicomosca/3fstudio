-- Migration 017 — aggiunge il valore delete_pending all'enum lesson_status
-- Necessario per il flusso "trainer propone eliminazione lezione"

ALTER TYPE lesson_status ADD VALUE IF NOT EXISTS 'delete_pending';
