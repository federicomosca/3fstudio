-- ============================================================
-- Migration 005 — default_studio_id + Storage avatar policies
-- Eseguire nel Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Colonna default_studio_id su users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS default_studio_id uuid
    REFERENCES studios(id) ON DELETE SET NULL;

-- 2. Storage: assicurarsi che il bucket 'avatars' sia pubblico
--    (se già esiste lo aggiorna; se non esiste lo crea)
INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true)
  ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Policy: lettura pubblica degli avatar
DROP POLICY IF EXISTS "public can view avatars" ON storage.objects;
CREATE POLICY "public can view avatars"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

-- 4. Policy: upload del proprio avatar (INSERT)
DROP POLICY IF EXISTS "users can upload own avatar" ON storage.objects;
CREATE POLICY "users can upload own avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. Policy: sovrascrittura del proprio avatar (UPDATE — necessaria per upsert)
DROP POLICY IF EXISTS "users can update own avatar" ON storage.objects;
CREATE POLICY "users can update own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 6. Policy: eliminazione del proprio avatar (DELETE)
DROP POLICY IF EXISTS "users can delete own avatar" ON storage.objects;
CREATE POLICY "users can delete own avatar"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
