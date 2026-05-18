-- Replace time_of_day (derived text) with actual started_at / finished_at
-- timestamps so the app can track round duration.

ALTER TABLE rounds
    DROP CONSTRAINT IF EXISTS rounds_time_of_day;

ALTER TABLE rounds
    DROP COLUMN IF EXISTS time_of_day;

ALTER TABLE rounds
    ADD COLUMN IF NOT EXISTS started_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ;
