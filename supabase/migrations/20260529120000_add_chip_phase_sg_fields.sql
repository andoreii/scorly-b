-- Adds the per-hole chip-phase fields that the new SG calculator
-- consumes. All additive nullable columns so existing rows decode
-- unchanged and the SG layer falls back to lie-based defaults when
-- the user hasn't recorded per-shot data.

ALTER TABLE hole_stats
    ADD COLUMN IF NOT EXISTS approach_landing_distance INTEGER,
    ADD COLUMN IF NOT EXISTS arg_shots_json TEXT,
    ADD COLUMN IF NOT EXISTS layup_lie TEXT,
    ADD COLUMN IF NOT EXISTS layup_distance INTEGER;

COMMENT ON COLUMN hole_stats.approach_landing_distance IS
    'Yards from pin where the approach (or par-3 tee shot) finished. Nil = lie-based default applied at SG time.';
COMMENT ON COLUMN hole_stats.arg_shots_json IS
    'JSON array of around-the-green shots: [{"lie": "rough_left", "distance_to_pin_yards": 25}]. Nil = lie-based defaults used.';
COMMENT ON COLUMN hole_stats.layup_lie IS
    'Par-5 only: lie where the layup landed.';
COMMENT ON COLUMN hole_stats.layup_distance IS
    'Par-5 only: yards remaining to pin after the layup.';
