CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  studio_id  uuid REFERENCES studios(id) ON DELETE CASCADE,
  title      text NOT NULL,
  body       text,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES users(id)
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members see own studio notifs"
  ON notifications FOR SELECT
  USING (studio_id IN (
    SELECT studio_id FROM user_studio_roles WHERE user_id = auth.uid()
  ));

CREATE POLICY "owners can insert notifs"
  ON notifications FOR INSERT
  WITH CHECK (studio_id IN (
    SELECT studio_id FROM user_studio_roles
    WHERE user_id = auth.uid() AND role = 'owner'
  ));

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS notifications_seen_at timestamptz DEFAULT now();

-- Allow users to update their own notifications_seen_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'user updates own seen_at'
  ) THEN
    CREATE POLICY "user updates own seen_at"
      ON public.users FOR UPDATE
      USING (id = auth.uid())
      WITH CHECK (id = auth.uid());
  END IF;
END $$;
