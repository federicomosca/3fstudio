-- Migration 041 — Allow course class_owner_id to propose lessons
--
-- The existing "class_owner can propose lessons" policy requires has_role('class_owner')
-- but a user can be set as class_owner_id on a course without that role entry.
-- This policy grants INSERT to anyone who is the class_owner_id of the course,
-- which is the actual source of truth for proposal authority.

DROP POLICY IF EXISTS "class_owner can propose lessons" ON lessons;

CREATE POLICY "class_owner can propose lessons"
ON lessons FOR INSERT TO authenticated
WITH CHECK (
  status = 'pending' AND
  proposed_by = auth.uid() AND
  course_id IN (
    SELECT id FROM courses WHERE class_owner_id = auth.uid()
  )
);
