-- Migration 019 — staff can see all lessons for their studio
-- Previously trainers could only see lessons where trainer_id = their own id.
-- Now all staff (trainer, class_owner, owner) see every lesson in their studio.

DROP POLICY IF EXISTS "staff see studio lessons" ON lessons;
CREATE POLICY "staff see studio lessons"
ON lessons FOR SELECT
USING (
  (has_role('trainer') OR has_role('class_owner') OR has_role('owner')) AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
);
