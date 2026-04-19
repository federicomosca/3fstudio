-- 016: Add is_active flag to user_studio_roles
-- Allows owner to archive trainers and clients per-studio
-- without deleting their auth account or data.

ALTER TABLE user_studio_roles
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
