-- ============================================================
-- Migration 031 — bookings SELECT policies
--
-- Previously there was no explicit SELECT policy for staff or
-- clients on the bookings table, so trainers/class_owners saw
-- an empty booking list and lesson cards always showed 0/N.
-- ============================================================

-- Users can always read their own bookings (client calendar, my-bookings screen)
DROP POLICY IF EXISTS "users can view own bookings" ON bookings;
CREATE POLICY "users can view own bookings"
ON bookings FOR SELECT
USING (auth.uid() = user_id);

-- Staff (owner/class_owner/trainer) can read all bookings for their studio's lessons
-- Required for: lesson capacity count, roster screen
DROP POLICY IF EXISTS "staff can view studio lesson bookings" ON bookings;
CREATE POLICY "staff can view studio lesson bookings"
ON bookings FOR SELECT
USING (
  (has_role('owner') OR has_role('class_owner') OR has_role('trainer'))
  AND lesson_id IN (
    SELECT l.id FROM lessons l
    JOIN courses c ON c.id = l.course_id
    WHERE c.studio_id = my_studio_id()
  )
);

-- Clients can read all bookings for their studio's lessons
-- Required for: lesson capacity count displayed in the calendar
DROP POLICY IF EXISTS "clients can view studio lesson bookings" ON bookings;
CREATE POLICY "clients can view studio lesson bookings"
ON bookings FOR SELECT
USING (
  has_role('client')
  AND lesson_id IN (
    SELECT l.id FROM lessons l
    JOIN courses c ON c.id = l.course_id
    WHERE c.studio_id = my_studio_id()
  )
);
