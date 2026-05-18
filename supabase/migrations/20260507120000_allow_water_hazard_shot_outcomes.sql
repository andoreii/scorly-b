-- Allow water-hazard outcomes for tee shots and approaches.
-- The Trouble → Water picker in the iOS app emits these four strings,
-- but the original CHECK constraints rejected them, causing the entire
-- hole_stats batch insert to fail and silently drop all per-hole stats
-- for any round that included a water selection.

alter table hole_stats
    drop constraint if exists hole_stats_tee_shot,
    drop constraint if exists hole_stats_approach;

alter table hole_stats
    add constraint hole_stats_tee_shot check (tee_shot in (
        'Fairway', 'Left', 'Right', 'Short', 'Long',
        'Out Left', 'Out Right', 'Out Short', 'Out Long',
        'Bunker Left', 'Bunker Right', 'Bunker Short', 'Bunker Long',
        'Left water', 'Right water', 'Short water', 'Long Water',
        'Green'
    )),
    add constraint hole_stats_approach check (approach in (
        'Green', 'Left', 'Right', 'Short', 'Long',
        'Out Left', 'Out Right', 'Out Short', 'Out Long',
        'Bunker Left', 'Bunker Right', 'Bunker Short', 'Bunker Long',
        'Left water', 'Right water', 'Short water', 'Long Water',
        'N/A'
    ));
