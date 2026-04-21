-- SECURITY DEFINER breaks the circular RLS dependency:
-- courses policy → lessons → courses (infinite recursion)
CREATE OR REPLACE FUNCTION trainer_assigned_course_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT DISTINCT course_id FROM lessons WHERE trainer_id = auth.uid()
$$;

DROP POLICY IF EXISTS "trainer sees assigned courses" ON courses;
CREATE POLICY "trainer sees assigned courses"
  ON courses FOR SELECT
  USING (
    has_role('trainer') AND
    id IN (SELECT trainer_assigned_course_ids())
  );
