-- Clients can read plans for their studio
DROP POLICY IF EXISTS "clients see studio plans" ON plans;
CREATE POLICY "clients see studio plans"
  ON plans FOR SELECT
  USING (
    studio_id IN (
      SELECT studio_id FROM user_studio_roles WHERE user_id = auth.uid()
    )
  );
