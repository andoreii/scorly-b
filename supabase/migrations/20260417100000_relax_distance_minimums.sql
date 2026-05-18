-- Relax tee-shot and approach distance minimums to allow 0.
-- The wheel UI now bottoms out at 0 (acts as "no value / missed") so the
-- original 30-yard / 5-yard floors reject legitimate inputs.

alter table hole_stats
    drop constraint if exists hole_stats_tee_shot_distance,
    drop constraint if exists hole_stats_approach_distance;

alter table hole_stats
    add constraint hole_stats_tee_shot_distance
        check (tee_shot_distance is null or tee_shot_distance between 0 and 450),
    add constraint hole_stats_approach_distance
        check (approach_distance is null or approach_distance between 0 and 350);
