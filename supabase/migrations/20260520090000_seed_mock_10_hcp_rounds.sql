-- Seed 10 complete mock rounds at roughly a 10-handicap level.
--
-- Distribution:
-- - Manila Southwoods: 3 rounds
-- - Alabang Country Club: 3 rounds
-- - Tagaytay Midlands: 4 rounds
--
-- This is idempotent for rows with round_external_id LIKE 'mock-10hcp-%'.

DO $$
DECLARE
  v_user_id UUID;
  v_course_id INT;
  v_tee_id INT;
  v_round_id INT;
  v_round_start TIMESTAMPTZ;
  v_round RECORD;
  v_hole RECORD;
  v_strokes INT;
  v_putts INT;
  v_tee_shot TEXT;
  v_approach TEXT;
  v_tee_club TEXT;
  v_approach_club TEXT;
  v_tee_distance INT;
  v_approach_distance INT;
  v_out_of_bounds INT;
  v_hazard INT;
  v_penalty INT;
  v_green_in_reg BOOLEAN;
  v_three_putt BOOLEAN;
  v_up_and_down BOOLEAN;
  v_sand_save BOOLEAN;
  v_putt_distances JSONB;
BEGIN
  SELECT user_id
    INTO v_user_id
    FROM courses
   WHERE course_name IN ('Manila Southwoods', 'Alabang Country Club', 'Tagaytay Midlands')
   GROUP BY user_id
  HAVING COUNT(DISTINCT course_name) = 3
   ORDER BY MIN(created_at)
   LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Could not find one user with all three seeded courses. Run supabase/seed.sql first.';
  END IF;

  DELETE FROM rounds
   WHERE user_id = v_user_id
     AND round_external_id LIKE 'mock-10hcp-%';

  FOR v_round IN
    SELECT *
      FROM (
        VALUES
          (1,  'mock-10hcp-manila-01',   'Manila Southwoods',    'White',   '2026-03-21'::date, '07:10', 252, 81,  8.5::numeric(4,1), 'Casual',     'Stroke Play', 'Sunny,Windy',   88, 'Walking',   7, 'Mock 10 HCP round: steady tee shots, a few loose approaches.', ARRAY[0,1,0,1,1,0,0,1,1,1,0,1,0,1,0,0,1,0]::INT[]),
          (2,  'mock-10hcp-manila-02',   'Manila Southwoods',    'White',   '2026-03-29'::date, '08:00', 246, 82,  9.4::numeric(4,1), 'Casual',     'Stroke Play', 'Cloudy',        84, 'Push Cart', 8, 'Mock 10 HCP round: solid putting, one costly double on the front.', ARRAY[1,0,0,1,0,1,0,1,2,0,0,1,0,1,0,1,0,1]::INT[]),
          (3,  'mock-10hcp-manila-03',   'Manila Southwoods',    'White',   '2026-04-06'::date, '13:20', 265, 84, 11.1::numeric(4,1), 'Practice',   'Stroke Play', 'Sunny',         91, 'Riding',    6, 'Mock 10 HCP round: good recovery day with pressure from missed fairways.', ARRAY[1,1,0,2,1,0,0,1,1,1,0,1,0,1,1,0,1,0]::INT[]),
          (4,  'mock-10hcp-alabang-01',  'Alabang Country Club', 'Regular', '2026-04-13'::date, '07:30', 238, 82, 10.8::numeric(4,1), 'Tournament', 'Stroke Play', 'Sunny',         87, 'Walking',   8, 'Mock 10 HCP round: tournament-like card with pars mixed through each side.', ARRAY[1,0,1,0,1,0,1,0,1,1,0,0,1,1,0,1,0,1]::INT[]),
          (5,  'mock-10hcp-alabang-02',  'Alabang Country Club', 'Regular', '2026-04-20'::date, '12:40', 250, 83, 11.7::numeric(4,1), 'Casual',     'Stableford',  'Windy',         92, 'Riding',    7, 'Mock 10 HCP round: windy conditions with several missed greens.', ARRAY[0,1,1,0,2,0,1,0,1,1,1,0,0,1,1,0,0,1]::INT[]),
          (6,  'mock-10hcp-alabang-03',  'Alabang Country Club', 'Regular', '2026-04-27'::date, '09:10', 258, 85, 13.5::numeric(4,1), 'Casual',     'Stroke Play', 'Cloudy,Windy',  86, 'Push Cart', 6, 'Mock 10 HCP round: penalty-heavy finish but realistic 10 HCP profile.', ARRAY[1,0,1,0,2,1,1,0,1,1,1,0,1,1,0,1,0,1]::INT[]),
          (7,  'mock-10hcp-tagaytay-01', 'Tagaytay Midlands',    'Member',  '2026-05-03'::date, '06:50', 242, 82, 10.0::numeric(4,1), 'Casual',     'Stroke Play', 'Sunny',         79, 'Walking',   9, 'Mock 10 HCP round: strong short game and controlled misses.', ARRAY[0,0,1,1,1,0,0,1,1,1,0,1,0,1,1,0,0,1]::INT[]),
          (8,  'mock-10hcp-tagaytay-02', 'Tagaytay Midlands',    'Member',  '2026-05-08'::date, '14:00', 260, 83, 10.9::numeric(4,1), 'Practice',   'Stroke Play', 'Rainy,Windy',   75, 'Riding',    6, 'Mock 10 HCP round: wet-course scoring with conservative club choices.', ARRAY[1,0,1,0,1,0,1,1,1,0,1,0,1,1,0,1,0,1]::INT[]),
          (9,  'mock-10hcp-tagaytay-03', 'Tagaytay Midlands',    'Member',  '2026-05-12'::date, '08:20', 249, 84, 11.7::numeric(4,1), 'Casual',     'Match Play',  'Cloudy',        81, 'Push Cart', 7, 'Mock 10 HCP round: average ball striking with one doubled approach hole.', ARRAY[0,1,1,1,0,0,1,1,1,1,0,0,1,2,0,1,0,1]::INT[]),
          (10, 'mock-10hcp-tagaytay-04', 'Tagaytay Midlands',    'Member',  '2026-05-17'::date, '10:30', 255, 85, 12.6::numeric(4,1), 'Tournament', 'Stroke Play', 'Sunny,Windy',   83, 'Walking',   8, 'Mock 10 HCP round: tougher scoring day with fairway misses under wind.', ARRAY[1,1,0,1,1,0,1,1,1,0,1,1,0,2,0,1,0,1]::INT[])
      ) AS rounds(
        seq,
        external_id,
        course_name,
        tee_name,
        date_played,
        start_time,
        duration_minutes,
        total_score,
        whs_differential,
        round_type,
        round_format,
        conditions,
        temperature,
        walking_vs_riding,
        mental_state,
        notes,
        deltas
      )
  LOOP
    SELECT course_id
      INTO v_course_id
      FROM courses
     WHERE user_id = v_user_id
       AND course_name = v_round.course_name
     LIMIT 1;

    IF v_course_id IS NULL THEN
      RAISE EXCEPTION 'Missing course % for user %', v_round.course_name, v_user_id;
    END IF;

    SELECT tee_id
      INTO v_tee_id
      FROM tees
     WHERE course_id = v_course_id
       AND tee_name = v_round.tee_name
     LIMIT 1;

    IF v_tee_id IS NULL THEN
      RAISE EXCEPTION 'Missing tee % for course %', v_round.tee_name, v_round.course_name;
    END IF;

    v_round_start := (v_round.date_played::TEXT || ' ' || v_round.start_time || ':00+08')::TIMESTAMPTZ;

    INSERT INTO rounds (
      user_id,
      course_id,
      tee_id,
      date_played,
      holes_played,
      round_type,
      round_format,
      conditions,
      temperature,
      walking_vs_riding,
      started_at,
      finished_at,
      mental_state,
      round_external_id,
      notes,
      whs_differential,
      total_score
    )
    VALUES (
      v_user_id,
      v_course_id,
      v_tee_id,
      v_round.date_played,
      '18',
      v_round.round_type,
      v_round.round_format,
      v_round.conditions,
      v_round.temperature,
      v_round.walking_vs_riding,
      v_round_start,
      v_round_start + (v_round.duration_minutes::TEXT || ' minutes')::INTERVAL,
      v_round.mental_state,
      v_round.external_id,
      v_round.notes,
      v_round.whs_differential,
      v_round.total_score
    )
    RETURNING round_id INTO v_round_id;

    FOR v_hole IN
      SELECT
        h.hole_number,
        h.par,
        th.yardage,
        d.delta
      FROM holes h
      JOIN tee_holes th
        ON th.tee_id = v_tee_id
       AND th.hole_number = h.hole_number
      JOIN UNNEST(v_round.deltas) WITH ORDINALITY AS d(delta, hole_number)
        ON d.hole_number = h.hole_number
      WHERE h.course_id = v_course_id
      ORDER BY h.hole_number
    LOOP
      v_strokes := v_hole.par + v_hole.delta;

      v_putts := CASE
        WHEN v_hole.delta < 0 THEN 1
        WHEN v_hole.delta = 0 THEN CASE WHEN (v_hole.hole_number + v_round.seq) % 5 = 0 THEN 1 ELSE 2 END
        WHEN v_hole.delta = 1 THEN CASE WHEN (v_hole.hole_number + v_round.seq) % 6 = 0 THEN 3 ELSE 2 END
        ELSE CASE WHEN (v_hole.hole_number + v_round.seq) % 3 = 0 THEN 3 ELSE 2 END
      END;

      v_green_in_reg := CASE
        WHEN v_hole.par = 3 THEN v_hole.delta <= 0 OR v_putts >= 3
        WHEN v_hole.delta < 0 THEN TRUE
        WHEN v_hole.delta = 0 THEN v_putts >= 2
        WHEN v_hole.delta = 1 THEN v_putts >= 3
        ELSE FALSE
      END;

      v_three_putt := v_putts >= 3;
      v_out_of_bounds := CASE
        WHEN NOT v_green_in_reg AND v_hole.delta >= 2 AND (v_hole.hole_number + v_round.seq) % 4 = 0 THEN 1
        ELSE 0
      END;
      v_hazard := CASE
        WHEN NOT v_green_in_reg AND v_hole.delta >= 1 AND (v_hole.hole_number + v_round.seq) % 7 = 0 THEN 1
        ELSE 0
      END;
      v_penalty := v_out_of_bounds + v_hazard;

      IF v_hole.par = 3 THEN
        v_tee_shot := CASE
          WHEN v_green_in_reg THEN 'Green'
          WHEN v_hazard > 0 THEN 'Short water'
          WHEN (v_hole.hole_number + v_round.seq) % 4 = 0 THEN 'Bunker Short'
          WHEN (v_hole.hole_number + v_round.seq) % 2 = 0 THEN 'Left'
          ELSE 'Short'
        END;
        v_approach := 'N/A';
      ELSE
        v_tee_shot := CASE
          WHEN v_out_of_bounds > 0 THEN 'Out Right'
          WHEN v_hazard > 0 AND (v_hole.hole_number + v_round.seq) % 2 = 0 THEN 'Right water'
          WHEN (v_hole.hole_number + v_round.seq) % 3 = 0 THEN 'Fairway'
          WHEN (v_hole.hole_number + v_round.seq) % 5 = 0 THEN 'Bunker Left'
          WHEN (v_hole.hole_number + v_round.seq) % 2 = 0 THEN 'Left'
          ELSE 'Right'
        END;

        v_approach := CASE
          WHEN v_green_in_reg THEN 'Green'
          WHEN v_out_of_bounds > 0 THEN 'Out Long'
          WHEN v_hazard > 0 THEN 'Long Water'
          WHEN (v_hole.hole_number + v_round.seq) % 4 = 0 THEN 'Bunker Short'
          WHEN (v_hole.hole_number + v_round.seq) % 3 = 0 THEN 'Short'
          WHEN (v_hole.hole_number + v_round.seq) % 2 = 0 THEN 'Right'
          ELSE 'Long'
        END;
      END IF;

      v_tee_distance := CASE
        WHEN v_hole.par = 3 THEN v_hole.yardage
        WHEN v_tee_shot LIKE 'Out %' OR v_tee_shot LIKE '%water' THEN GREATEST(185, LEAST(235, (v_hole.yardage * 0.50)::INT))
        WHEN v_tee_shot LIKE 'Bunker %' THEN GREATEST(205, LEAST(245, (v_hole.yardage * 0.56)::INT))
        WHEN v_tee_shot = 'Fairway' THEN GREATEST(225, LEAST(270, (v_hole.yardage * 0.62)::INT))
        ELSE GREATEST(210, LEAST(255, (v_hole.yardage * 0.58)::INT))
      END;

      v_approach_distance := CASE
        WHEN v_hole.par = 3 THEN NULL
        ELSE LEAST(350, GREATEST(0, v_hole.yardage - v_tee_distance))
      END;

      v_tee_club := CASE
        WHEN v_hole.par = 3 AND v_hole.yardage >= 175 THEN '5i'
        WHEN v_hole.par = 3 AND v_hole.yardage >= 155 THEN '7i'
        WHEN v_hole.par = 3 THEN '8i'
        WHEN v_hole.par = 5 AND v_hole.yardage >= 490 THEN 'Driver'
        WHEN v_hole.par >= 4 THEN 'Driver'
        ELSE 'Hybrid'
      END;

      v_approach_club := CASE
        WHEN v_hole.par = 3 THEN NULL
        WHEN v_approach_distance >= 230 THEN '5-Wood'
        WHEN v_approach_distance >= 200 THEN 'Hybrid'
        WHEN v_approach_distance >= 175 THEN '5i'
        WHEN v_approach_distance >= 155 THEN '7i'
        WHEN v_approach_distance >= 135 THEN '8i'
        WHEN v_approach_distance >= 115 THEN '9i'
        WHEN v_approach_distance >= 90 THEN 'PW'
        ELSE 'SW'
      END;

      v_up_and_down := NOT v_green_in_reg AND v_putts = 1 AND v_strokes <= v_hole.par;
      v_sand_save := (
        v_tee_shot LIKE 'Bunker %'
        OR v_approach LIKE 'Bunker %'
      ) AND v_putts = 1 AND v_strokes <= v_hole.par;

      v_putt_distances := CASE v_putts
        WHEN 1 THEN jsonb_build_array(CASE WHEN v_green_in_reg THEN 9 + ((v_hole.hole_number + v_round.seq) % 7) ELSE 4 + ((v_hole.hole_number + v_round.seq) % 5) END)
        WHEN 2 THEN jsonb_build_array(14 + ((v_hole.hole_number * 3 + v_round.seq) % 18), 2 + ((v_hole.hole_number + v_round.seq) % 3))
        WHEN 3 THEN jsonb_build_array(28 + ((v_hole.hole_number * 2 + v_round.seq) % 16), 5 + ((v_hole.hole_number + v_round.seq) % 5), 1)
        ELSE '[]'::JSONB
      END;

      INSERT INTO hole_stats (
        round_id,
        hole_number,
        strokes,
        putts,
        tee_shot,
        approach,
        tee_club,
        approach_club,
        out_of_bounds_count,
        penalty_strokes,
        hazard_count,
        green_in_reg,
        three_putt,
        gir_opportunity,
        fairway_opportunity,
        up_and_down_success,
        sand_save_success,
        putt_distances,
        tee_shot_distance,
        approach_distance,
        pin_position,
        hole_stat_external_id
      )
      VALUES (
        v_round_id,
        v_hole.hole_number,
        v_strokes,
        v_putts,
        v_tee_shot,
        v_approach,
        v_tee_club,
        v_approach_club,
        v_out_of_bounds,
        v_penalty,
        v_hazard,
        v_green_in_reg,
        v_three_putt,
        TRUE,
        v_hole.par >= 4,
        v_up_and_down,
        v_sand_save,
        v_putt_distances,
        v_tee_distance,
        v_approach_distance,
        CASE (v_hole.hole_number + v_round.seq) % 3
          WHEN 0 THEN 'Front'
          WHEN 1 THEN 'Middle'
          ELSE 'Back'
        END,
        v_round.external_id || '-h' || LPAD(v_hole.hole_number::TEXT, 2, '0')
      );
    END LOOP;
  END LOOP;
END $$;
