-- v2 Phase C — make every aggregate offline-syncable + add the goals table.
--
-- Two-part migration:
--
-- 1) Add `*_external_id` UUID columns to every user-data table. v1 only had
--    `round_external_id`; v2's offline-first sync engine needs an idempotency
--    key on every insert so retried writes (e.g. after a network hiccup) land
--    exactly once. Every column is UNIQUE per parent and nullable so v1
--    historical rows aren't broken — the SyncEngine fills it in for new
--    rows, and a future backfill can populate legacy rows.
--
-- 2) Create the `goals` table for Phase B6 / Phase J9. Same RLS pattern as
--    every other user-scoped table: own row only, enforced by `auth.uid()`.

------------------------------------------------------------------------------
-- 1) External-ID columns on existing tables
------------------------------------------------------------------------------

ALTER TABLE courses    ADD COLUMN IF NOT EXISTS course_external_id    TEXT;
ALTER TABLE tees       ADD COLUMN IF NOT EXISTS tee_external_id       TEXT;
ALTER TABLE holes      ADD COLUMN IF NOT EXISTS hole_external_id      TEXT;
ALTER TABLE tee_holes  ADD COLUMN IF NOT EXISTS tee_hole_external_id  TEXT;
ALTER TABLE hole_stats ADD COLUMN IF NOT EXISTS hole_stat_external_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS courses_course_external_id_key
  ON courses (course_external_id) WHERE course_external_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS tees_tee_external_id_key
  ON tees (tee_external_id) WHERE tee_external_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS holes_hole_external_id_key
  ON holes (hole_external_id) WHERE hole_external_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS tee_holes_tee_hole_external_id_key
  ON tee_holes (tee_hole_external_id) WHERE tee_hole_external_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hole_stats_hole_stat_external_id_key
  ON hole_stats (hole_stat_external_id) WHERE hole_stat_external_id IS NOT NULL;

------------------------------------------------------------------------------
-- 2) goals table
------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS goals (
    goal_id          SERIAL      PRIMARY KEY,
    user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal_external_id TEXT        UNIQUE,                  -- client UUID, idempotency key
    kind             TEXT        NOT NULL,                -- GoalKind discriminator + payload (JSON-encoded)
    payload          JSONB       NOT NULL,                -- associated values for the GoalKind case
    title            TEXT        NOT NULL,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    deadline         DATE,
    archived_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS goals_user_id_idx     ON goals (user_id);
CREATE INDEX IF NOT EXISTS goals_archived_at_idx ON goals (archived_at);

ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users select own goals"
    ON goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own goals"
    ON goals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own goals"
    ON goals FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own goals"
    ON goals FOR DELETE
    USING (auth.uid() = user_id);
