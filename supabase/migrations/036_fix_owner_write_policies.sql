-- ============================================================
-- Migration 036 — Fix policy INSERT/UPDATE/DELETE owner
--
-- Le policy di scrittura in 034 usano my_studio_id() (restituisce
-- un solo studio). Per owner multi-sede si usa my_owned_studio_ids().
-- ============================================================

-- ── LESSONS ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "owner can insert lessons" ON lessons;
CREATE POLICY "owner can insert lessons"
ON lessons FOR INSERT TO authenticated
WITH CHECK (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses
    WHERE studio_id IN (SELECT my_owned_studio_ids())
  )
);

DROP POLICY IF EXISTS "owner can update lessons" ON lessons;
CREATE POLICY "owner can update lessons"
ON lessons FOR UPDATE TO authenticated
USING (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses
    WHERE studio_id IN (SELECT my_owned_studio_ids())
  )
)
WITH CHECK (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses
    WHERE studio_id IN (SELECT my_owned_studio_ids())
  )
);

DROP POLICY IF EXISTS "owner can delete lessons" ON lessons;
CREATE POLICY "owner can delete lessons"
ON lessons FOR DELETE TO authenticated
USING (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses
    WHERE studio_id IN (SELECT my_owned_studio_ids())
  )
);

-- ── COURSES ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "owner can insert courses" ON courses;
CREATE POLICY "owner can insert courses"
ON courses FOR INSERT TO authenticated
WITH CHECK (
  has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids())
);

DROP POLICY IF EXISTS "owner can update courses" ON courses;
CREATE POLICY "owner can update courses"
ON courses FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()))
WITH CHECK (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));

DROP POLICY IF EXISTS "owner can delete courses" ON courses;
CREATE POLICY "owner can delete courses"
ON courses FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));

-- ── ROOMS ─────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "owner can insert rooms" ON rooms;
CREATE POLICY "owner can insert rooms"
ON rooms FOR INSERT TO authenticated
WITH CHECK (
  has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids())
);

DROP POLICY IF EXISTS "owner can update rooms" ON rooms;
CREATE POLICY "owner can update rooms"
ON rooms FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()))
WITH CHECK (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));

DROP POLICY IF EXISTS "owner can delete rooms" ON rooms;
CREATE POLICY "owner can delete rooms"
ON rooms FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));

-- ── PLANS ─────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "owner can insert plans" ON plans;
CREATE POLICY "owner can insert plans"
ON plans FOR INSERT TO authenticated
WITH CHECK (
  has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids())
);

DROP POLICY IF EXISTS "owner can update plans" ON plans;
CREATE POLICY "owner can update plans"
ON plans FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()))
WITH CHECK (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));

DROP POLICY IF EXISTS "owner can delete plans" ON plans;
CREATE POLICY "owner can delete plans"
ON plans FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id IN (SELECT my_owned_studio_ids()));
