-- Collapse the per-direction OB / hazard columns into a single
-- `penalty_events_json` text column.
--
-- Before this migration `hole_stats` carried ten counter columns
-- (`out_of_bounds_count`, `out_of_bounds_left/right/long/short`,
-- `hazard_count`, `hazard_left/right/long/short`). Each row stored what
-- amounted to a histogram of penalty events, which made downstream
-- queries clumsy (per-event ordering was lost, "direction unknown"
-- collapsed silently into the total counter, every new dimension
-- required another schema change).
--
-- The new shape is a JSON-encoded text array of objects:
--
--     [
--       { "kind": "outOfBounds", "direction": "left", "phase": "tee"      },
--       { "kind": "hazard",      "direction": null,   "phase": "approach" }
--     ]
--
-- Each array entry is one stroke that finished in trouble. `kind` is
-- `outOfBounds` (stroke + distance, ball is gone) or `hazard` (water /
-- penalty area, takes a drop). `direction` is one of `left`, `right`,
-- `long`, `short`, or null (the v1/v2 case where only a count was
-- recorded). `phase` is `tee`, `approach`, or absent for backfilled
-- legacy rows where the old counter columns did not retain the source
-- shot. Order matches stroke order on the hole.
--
-- Stored as TEXT (not JSONB) to mirror the existing `arg_shots_json`
-- convention: the Swift data layer treats the column as an opaque
-- string and encodes / decodes through a single `[PenaltyEvent]`
-- codec, keeping PostgREST round-tripping symmetric on both
-- columns. The backfill below walks the legacy columns and builds the
-- JSON text in place, then drops the old columns. Domain code derives
-- the per-direction counts as computed properties over this list so
-- the old per-field accessors keep working in Swift without churn.

ALTER TABLE hole_stats
    ADD COLUMN penalty_events_json TEXT;

-- Backfill: walk each row, emit one JSON object per recorded event,
-- and serialize the resulting array to text. Directional counts
-- produce objects with `direction` set; any residual count beyond the
-- sum of directions yields direction=null objects (the v1 / v2 case
-- where only the total was tracked).
UPDATE hole_stats AS h
SET penalty_events_json = events.json_text
FROM (
    SELECT
        hs.hole_stat_id,
        (
            SELECT jsonb_agg(
                jsonb_build_object('kind', kind, 'direction', direction)
                ORDER BY ord, n
            )::text
            FROM (
                SELECT 'outOfBounds' AS kind, 'left'  AS direction, 1 AS ord, generate_series(1, COALESCE(hs.out_of_bounds_left,  0)) AS n
                UNION ALL
                SELECT 'outOfBounds', 'right', 2, generate_series(1, COALESCE(hs.out_of_bounds_right, 0))
                UNION ALL
                SELECT 'outOfBounds', 'long',  3, generate_series(1, COALESCE(hs.out_of_bounds_long,  0))
                UNION ALL
                SELECT 'outOfBounds', 'short', 4, generate_series(1, COALESCE(hs.out_of_bounds_short, 0))
                UNION ALL
                SELECT 'outOfBounds', NULL, 5, generate_series(
                    1,
                    GREATEST(
                        0,
                        COALESCE(hs.out_of_bounds_count, 0)
                            - COALESCE(hs.out_of_bounds_left,  0)
                            - COALESCE(hs.out_of_bounds_right, 0)
                            - COALESCE(hs.out_of_bounds_long,  0)
                            - COALESCE(hs.out_of_bounds_short, 0)
                    )
                )
                UNION ALL
                SELECT 'hazard', 'left',  6, generate_series(1, COALESCE(hs.hazard_left,  0))
                UNION ALL
                SELECT 'hazard', 'right', 7, generate_series(1, COALESCE(hs.hazard_right, 0))
                UNION ALL
                SELECT 'hazard', 'long',  8, generate_series(1, COALESCE(hs.hazard_long,  0))
                UNION ALL
                SELECT 'hazard', 'short', 9, generate_series(1, COALESCE(hs.hazard_short, 0))
                UNION ALL
                SELECT 'hazard', NULL, 10, generate_series(
                    1,
                    GREATEST(
                        0,
                        COALESCE(hs.hazard_count, 0)
                            - COALESCE(hs.hazard_left,  0)
                            - COALESCE(hs.hazard_right, 0)
                            - COALESCE(hs.hazard_long,  0)
                            - COALESCE(hs.hazard_short, 0)
                    )
                )
            ) AS expanded(kind, direction, ord, n)
        ) AS json_text
    FROM hole_stats AS hs
    WHERE COALESCE(hs.out_of_bounds_count, 0) > 0
       OR COALESCE(hs.hazard_count,         0) > 0
) AS events
WHERE h.hole_stat_id = events.hole_stat_id;

COMMENT ON COLUMN hole_stats.penalty_events_json IS
'JSON-encoded [PenaltyEvent] — one object per OB / hazard stroke, in stroke order. Replaces the per-direction counter columns dropped in this migration.';

ALTER TABLE hole_stats
    DROP COLUMN out_of_bounds_count,
    DROP COLUMN out_of_bounds_left,
    DROP COLUMN out_of_bounds_right,
    DROP COLUMN out_of_bounds_long,
    DROP COLUMN out_of_bounds_short,
    DROP COLUMN hazard_count,
    DROP COLUMN hazard_left,
    DROP COLUMN hazard_right,
    DROP COLUMN hazard_long,
    DROP COLUMN hazard_short;
