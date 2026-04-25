-- ============================================================
-- Migration 037 — SELECT lezioni per owner multi-sede
--
-- Migration 019 usa my_studio_id() che restituisce un solo studio.
-- Per owner con più sedi, le lezioni degli altri studi non erano visibili.
-- Aggiungiamo una policy separata che usa my_owned_studio_ids().
-- ============================================================

DROP POLICY IF EXISTS "owner sees all studio lessons" ON lessons;
CREATE POLICY "owner sees all studio lessons"
ON lessons FOR SELECT TO authenticated
USING (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses
    WHERE studio_id IN (SELECT my_owned_studio_ids())
  )
);
