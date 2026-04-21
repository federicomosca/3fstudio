DROP POLICY IF EXISTS "owners can insert notifs" ON notifications;

CREATE POLICY "owners can insert notifs"
  ON notifications FOR INSERT
  WITH CHECK (studio_id IN (
    SELECT studio_id FROM user_studio_roles
    WHERE user_id = auth.uid() AND role = 'owner'
  ));
