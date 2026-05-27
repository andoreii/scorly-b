-- Wipe all rounds and courses (and everything that hangs off them),
-- and reset their id sequences so the next inserts start at 1.
-- One-off cleanup before inserting real data. Run manually; not a migration.
--
-- TRUNCATE order: rounds before courses (rounds -> courses is ON DELETE
-- RESTRICT, but CASCADE on TRUNCATE overrides that; listing rounds first
-- is just for clarity). CASCADE also clears hole_stats, tees, holes,
-- and tee_holes via their FK chains.

BEGIN;

TRUNCATE TABLE rounds, courses RESTART IDENTITY CASCADE;

COMMIT;
