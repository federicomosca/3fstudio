-- ============================================================
-- Migration 030 — atomic capacity check + waitlist auto-promotion
-- ============================================================

-- Atomic booking with capacity check.
-- Returns 'booked' if the spot was reserved, 'full' if the lesson is at capacity.
CREATE OR REPLACE FUNCTION book_if_available(
  p_lesson_id uuid,
  p_user_id   uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_capacity    int;
  v_booked_count int;
BEGIN
  -- Lock the lesson row to prevent concurrent overbooking
  SELECT capacity INTO v_capacity
  FROM lessons
  WHERE id = p_lesson_id
  FOR UPDATE;

  SELECT COUNT(*) INTO v_booked_count
  FROM bookings
  WHERE lesson_id = p_lesson_id
    AND status NOT IN ('cancelled', 'pending');

  IF v_booked_count >= v_capacity THEN
    RETURN 'full';
  END IF;

  INSERT INTO bookings (lesson_id, user_id, status)
  VALUES (p_lesson_id, p_user_id, 'confirmed')
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET status = 'confirmed';

  RETURN 'booked';
END;
$$;

-- Promotes the first waitlisted user (FIFO) into a confirmed booking.
-- Also deducts one credit from their best matching plan if they are on a credits plan.
-- Returns the promoted user_id, or NULL if the waitlist was empty.
CREATE OR REPLACE FUNCTION promote_from_waitlist(p_lesson_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next_user_id uuid;
  v_course_id    uuid;
  v_plan_id      uuid;
  v_credits      int;
BEGIN
  SELECT user_id INTO v_next_user_id
  FROM waitlist
  WHERE lesson_id = p_lesson_id
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_next_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO bookings (lesson_id, user_id, status)
  VALUES (p_lesson_id, v_next_user_id, 'confirmed')
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET status = 'confirmed';

  SELECT course_id INTO v_course_id
  FROM lessons
  WHERE id = p_lesson_id;

  -- Find best credit plan (course-specific takes priority over open plan)
  SELECT up.id, up.credits_remaining
  INTO v_plan_id, v_credits
  FROM user_plans up
  JOIN plans p ON p.id = up.plan_id
  WHERE up.user_id = v_next_user_id
    AND (up.expires_at IS NULL OR up.expires_at >= now())
    AND up.credits_remaining IS NOT NULL
    AND up.credits_remaining > 0
    AND (p.course_id IS NULL OR p.course_id = v_course_id)
  ORDER BY
    CASE WHEN p.course_id = v_course_id THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_plan_id IS NOT NULL THEN
    UPDATE user_plans
    SET credits_remaining = credits_remaining - 1
    WHERE id = v_plan_id;
  END IF;

  DELETE FROM waitlist
  WHERE lesson_id = p_lesson_id AND user_id = v_next_user_id;

  RETURN v_next_user_id;
END;
$$;
