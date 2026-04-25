-- ============================================================
-- Migration 034 — Policy RLS base mancanti
--
-- Le policy iniziali erano definite nel Supabase Dashboard e non
-- tracciate nelle migration. Questo file le aggiunge tutte.
-- ============================================================

-- ── COURSES ──────────────────────────────────────────────────────────────────

-- Tutti gli utenti dello studio possono leggere i corsi
-- (serve anche per la join courses!inner in lessons_provider)
DROP POLICY IF EXISTS "studio members can view courses" ON courses;
CREATE POLICY "studio members can view courses"
ON courses FOR SELECT TO authenticated
USING (
  studio_id IN (
    SELECT studio_id FROM user_studio_roles WHERE user_id = auth.uid()
  )
);

-- Owner: crea, modifica, elimina corsi del proprio studio
DROP POLICY IF EXISTS "owner can insert courses" ON courses;
CREATE POLICY "owner can insert courses"
ON courses FOR INSERT TO authenticated
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can update courses" ON courses;
CREATE POLICY "owner can update courses"
ON courses FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id = my_studio_id())
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can delete courses" ON courses;
CREATE POLICY "owner can delete courses"
ON courses FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id = my_studio_id());

-- ── ROOMS ─────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "studio members can view rooms" ON rooms;
CREATE POLICY "studio members can view rooms"
ON rooms FOR SELECT TO authenticated
USING (
  studio_id IN (
    SELECT studio_id FROM user_studio_roles WHERE user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "owner can insert rooms" ON rooms;
CREATE POLICY "owner can insert rooms"
ON rooms FOR INSERT TO authenticated
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can update rooms" ON rooms;
CREATE POLICY "owner can update rooms"
ON rooms FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id = my_studio_id())
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can delete rooms" ON rooms;
CREATE POLICY "owner can delete rooms"
ON rooms FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id = my_studio_id());

-- ── LESSONS ───────────────────────────────────────────────────────────────────

-- Client: vede le lezioni del proprio studio
DROP POLICY IF EXISTS "client can view studio lessons" ON lessons;
CREATE POLICY "client can view studio lessons"
ON lessons FOR SELECT TO authenticated
USING (
  has_role('client') AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
);

-- Owner: inserisce e aggiorna le lezioni del proprio studio
-- (DELETE e UPDATE proposta-eliminazione già coperti da 018)
DROP POLICY IF EXISTS "owner can insert lessons" ON lessons;
CREATE POLICY "owner can insert lessons"
ON lessons FOR INSERT TO authenticated
WITH CHECK (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
);

DROP POLICY IF EXISTS "owner can update lessons" ON lessons;
CREATE POLICY "owner can update lessons"
ON lessons FOR UPDATE TO authenticated
USING (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
)
WITH CHECK (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
);

DROP POLICY IF EXISTS "owner can delete lessons" ON lessons;
CREATE POLICY "owner can delete lessons"
ON lessons FOR DELETE TO authenticated
USING (
  has_role('owner') AND
  course_id IN (
    SELECT id FROM courses WHERE studio_id = my_studio_id()
  )
);

-- ── PUBLIC.USERS ──────────────────────────────────────────────────────────────

-- Ogni utente legge e aggiorna il proprio profilo
DROP POLICY IF EXISTS "users read own profile" ON users;
CREATE POLICY "users read own profile"
ON users FOR SELECT TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS "users update own profile" ON users;
CREATE POLICY "users update own profile"
ON users FOR UPDATE TO authenticated
USING   (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Owner legge tutti gli utenti del proprio studio
DROP POLICY IF EXISTS "owner reads studio users" ON users;
CREATE POLICY "owner reads studio users"
ON users FOR SELECT TO authenticated
USING (
  has_role('owner') AND
  id IN (
    SELECT user_id FROM user_studio_roles WHERE studio_id = my_studio_id()
  )
);

-- Staff legge gli utenti del proprio studio
-- (serve per visualizzare nome trainer/clienti nel roster)
DROP POLICY IF EXISTS "staff reads studio users" ON users;
CREATE POLICY "staff reads studio users"
ON users FOR SELECT TO authenticated
USING (
  (has_role('trainer') OR has_role('class_owner')) AND
  id IN (
    SELECT user_id FROM user_studio_roles WHERE studio_id = my_studio_id()
  )
);

-- ── PLANS ─────────────────────────────────────────────────────────────────────

-- Owner: crea, modifica, elimina piani del proprio studio
-- (SELECT già coperto da migration 025)
DROP POLICY IF EXISTS "owner can insert plans" ON plans;
CREATE POLICY "owner can insert plans"
ON plans FOR INSERT TO authenticated
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can update plans" ON plans;
CREATE POLICY "owner can update plans"
ON plans FOR UPDATE TO authenticated
USING   (has_role('owner') AND studio_id = my_studio_id())
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner can delete plans" ON plans;
CREATE POLICY "owner can delete plans"
ON plans FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id = my_studio_id());

-- ── USER_PLANS ────────────────────────────────────────────────────────────────

-- Client: legge i propri piani attivi
DROP POLICY IF EXISTS "client reads own user_plans" ON user_plans;
CREATE POLICY "client reads own user_plans"
ON user_plans FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Owner: legge e gestisce i piani degli utenti del proprio studio
DROP POLICY IF EXISTS "owner manages studio user_plans" ON user_plans;
CREATE POLICY "owner manages studio user_plans"
ON user_plans FOR ALL TO authenticated
USING (
  has_role('owner') AND
  user_id IN (
    SELECT user_id FROM user_studio_roles WHERE studio_id = my_studio_id()
  )
)
WITH CHECK (has_role('owner'));

-- ── USER_STUDIO_ROLES ─────────────────────────────────────────────────────────

-- Owner: legge tutti i ruoli del proprio studio
-- (SELECT proprio già coperto da migration 011)
DROP POLICY IF EXISTS "owner reads studio roles" ON user_studio_roles;
CREATE POLICY "owner reads studio roles"
ON user_studio_roles FOR SELECT TO authenticated
USING (has_role('owner') AND studio_id = my_studio_id());

-- Owner: inserisce e elimina ruoli nel proprio studio
DROP POLICY IF EXISTS "owner manages studio roles" ON user_studio_roles;
CREATE POLICY "owner manages studio roles"
ON user_studio_roles FOR INSERT TO authenticated
WITH CHECK (has_role('owner') AND studio_id = my_studio_id());

DROP POLICY IF EXISTS "owner deletes studio roles" ON user_studio_roles;
CREATE POLICY "owner deletes studio roles"
ON user_studio_roles FOR DELETE TO authenticated
USING (has_role('owner') AND studio_id = my_studio_id());

-- ── WAITLIST ──────────────────────────────────────────────────────────────────

-- Client: inserisce e rimuove se stesso dalla lista d'attesa
DROP POLICY IF EXISTS "client can join waitlist" ON waitlist;
CREATE POLICY "client can join waitlist"
ON waitlist FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "client can leave waitlist" ON waitlist;
CREATE POLICY "client can leave waitlist"
ON waitlist FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- Tutti gli utenti dello studio leggono la lista d'attesa delle lezioni
DROP POLICY IF EXISTS "studio members read waitlist" ON waitlist;
CREATE POLICY "studio members read waitlist"
ON waitlist FOR SELECT TO authenticated
USING (
  lesson_id IN (
    SELECT l.id FROM lessons l
    JOIN courses c ON c.id = l.course_id
    WHERE c.studio_id = my_studio_id()
  )
);
