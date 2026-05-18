-- Per-shot distance and pin location additions to hole_stats.
-- Distances are stored canonically: shot distances in yards, putt distances in feet.
-- All columns are nullable so existing rows remain valid without backfill.

alter table hole_stats
    add column if not exists putt_distances    jsonb,
    add column if not exists tee_shot_distance int,
    add column if not exists approach_distance int,
    add column if not exists pin_position      text;

alter table hole_stats
    add constraint hole_stats_tee_shot_distance
        check (tee_shot_distance is null or tee_shot_distance between 30 and 450),
    add constraint hole_stats_approach_distance
        check (approach_distance is null or approach_distance between 5 and 350),
    add constraint hole_stats_pin_position
        check (pin_position is null or pin_position in ('Front', 'Middle', 'Back')),
    add constraint hole_stats_putt_distances_shape
        check (
            putt_distances is null
            or (jsonb_typeof(putt_distances) = 'array' and jsonb_array_length(putt_distances) <= 6)
        );
