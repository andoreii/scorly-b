-- Directional hazard counts on hole_stats.
--
-- The Trend page's wind rose breaks down fairway / green misses by
-- direction AND severity (clean / bunker / water / OB). Aggregate
-- out_of_bounds_count and hazard_count remain authoritative for
-- effective penalty math; these new columns are additive and feed the
-- rose only. Default 0 so legacy rows continue to load. Range capped at
-- 5 (matching the existing out_of_bounds_count cap) — a single hole
-- never realistically produces more than a handful of trouble shots in
-- any one direction.

ALTER TABLE hole_stats
    ADD COLUMN out_of_bounds_left  INT NOT NULL DEFAULT 0 CHECK (out_of_bounds_left  BETWEEN 0 AND 5),
    ADD COLUMN out_of_bounds_right INT NOT NULL DEFAULT 0 CHECK (out_of_bounds_right BETWEEN 0 AND 5),
    ADD COLUMN out_of_bounds_long  INT NOT NULL DEFAULT 0 CHECK (out_of_bounds_long  BETWEEN 0 AND 5),
    ADD COLUMN out_of_bounds_short INT NOT NULL DEFAULT 0 CHECK (out_of_bounds_short BETWEEN 0 AND 5),
    ADD COLUMN hazard_left         INT NOT NULL DEFAULT 0 CHECK (hazard_left         BETWEEN 0 AND 5),
    ADD COLUMN hazard_right        INT NOT NULL DEFAULT 0 CHECK (hazard_right        BETWEEN 0 AND 5),
    ADD COLUMN hazard_long         INT NOT NULL DEFAULT 0 CHECK (hazard_long         BETWEEN 0 AND 5),
    ADD COLUMN hazard_short        INT NOT NULL DEFAULT 0 CHECK (hazard_short        BETWEEN 0 AND 5);
