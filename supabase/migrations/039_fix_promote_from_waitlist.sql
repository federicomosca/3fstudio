-- Fix promote_from_waitlist: course_id is on user_plans, not on plans
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
  -- course_id lives on user_plans, not on plans
  SELECT up.id, up.credits_remaining
  INTO v_plan_id, v_credits
  FROM user_plans up
  JOIN plans p ON p.id = up.plan_id
  WHERE up.user_id = v_next_user_id
    AND up.status = 'active'
    AND (up.expires_at IS NULL OR up.expires_at >= now())
    AND p.type = 'credits'
    AND up.credits_remaining IS NOT NULL
    AND up.credits_remaining > 0
    AND (up.course_id IS NULL OR up.course_id = v_course_id)
  ORDER BY
    CASE WHEN up.course_id = v_course_id THEN 0 ELSE 1 END
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
