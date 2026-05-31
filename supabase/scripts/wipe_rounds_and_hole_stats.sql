-- Wipe all rounds and per-hole stats, then reset their id sequences.
-- One-off cleanup before entering fresh round data. Run manually; not a migration.
--
-- `hole_stats` is listed explicitly so its `hole_stat_id` sequence is reset
-- alongside `rounds.round_id`. New inserts will start again at 1 for both.

BEGIN;

TRUNCATE TABLE hole_stats, rounds RESTART IDENTITY CASCADE;

COMMIT;
