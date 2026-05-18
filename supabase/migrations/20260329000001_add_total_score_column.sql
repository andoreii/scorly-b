-- =============================================================
-- Add total_score column to rounds
-- =============================================================
--
-- Denormalized roll-up of hole_stats.strokes. Originally landed in
-- scorly-v1 alongside a historical-rounds import; scorly-b ships the
-- schema change only — no seed data.

ALTER TABLE rounds
    ADD COLUMN IF NOT EXISTS total_score INT;

COMMENT ON COLUMN rounds.total_score IS
    'Cached sum of hole_stats.strokes for this round.';
