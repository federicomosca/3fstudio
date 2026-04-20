ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS delete_request_note TEXT;
