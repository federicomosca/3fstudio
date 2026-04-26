-- Migration 042 — Proposer can see their own pending lessons
--
-- Migration 041 relaxed the INSERT to use class_owner_id instead of has_role('class_owner').
-- A user who is class_owner_id of a course but has only the 'trainer' role can now insert
-- pending lessons, but the existing SELECT policy ("staff see studio lessons", migration 019)
-- still requires has_role('trainer|class_owner|owner'). This policy covers the gap by letting
-- anyone see lessons they proposed, regardless of role.

CREATE POLICY "proposer sees own pending lessons"
ON lessons FOR SELECT TO authenticated
USING (proposed_by = auth.uid());
