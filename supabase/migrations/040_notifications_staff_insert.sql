-- Allow any studio member to insert notifications (staff need this when cancelling lessons)
CREATE POLICY "studio members can insert notifs"
  ON notifications FOR INSERT
  WITH CHECK (studio_id IN (
    SELECT studio_id FROM user_studio_roles
    WHERE user_id = auth.uid()
  ));
