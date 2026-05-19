-- =============================================================
-- Scorly/B — Development seed data
-- Run via: supabase seed --linked
-- Requires: at least one user in auth.users
-- =============================================================

DO $$
DECLARE
  v_user_id    UUID  := 'c33a2b8f-cf18-47cc-8987-f5fe84000183';
  v_course1_id INT;
  v_course2_id INT;
  v_course3_id INT;
  v_tee_id     INT;
BEGIN

  -- ─── public.users profile ─────────────────────────────────
  INSERT INTO public.users (id, handicap_index, created_at)
    VALUES (v_user_id, NULL, now())
    ON CONFLICT (id) DO NOTHING;

  -- ─── Course 1: Manila Southwoods (Masters) ────────────────
  INSERT INTO courses (user_id, course_name, location, notes, course_external_id)
    VALUES (v_user_id, 'Manila Southwoods', 'Carmona, Cavite', 'Masters Course', gen_random_uuid()::text)
    ON CONFLICT (user_id, course_name) DO NOTHING
    RETURNING course_id INTO v_course1_id;

  IF v_course1_id IS NOT NULL THEN
    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index, hole_external_id) VALUES
      (v_course1_id,  1, 4,  7, gen_random_uuid()::text),
      (v_course1_id,  2, 4, 11, gen_random_uuid()::text),
      (v_course1_id,  3, 3, 17, gen_random_uuid()::text),
      (v_course1_id,  4, 5,  1, gen_random_uuid()::text),
      (v_course1_id,  5, 4,  9, gen_random_uuid()::text),
      (v_course1_id,  6, 4,  5, gen_random_uuid()::text),
      (v_course1_id,  7, 3, 15, gen_random_uuid()::text),
      (v_course1_id,  8, 5,  3, gen_random_uuid()::text),
      (v_course1_id,  9, 4, 13, gen_random_uuid()::text),
      (v_course1_id, 10, 4,  8, gen_random_uuid()::text),
      (v_course1_id, 11, 3, 16, gen_random_uuid()::text),
      (v_course1_id, 12, 4, 10, gen_random_uuid()::text),
      (v_course1_id, 13, 5,  2, gen_random_uuid()::text),
      (v_course1_id, 14, 4,  6, gen_random_uuid()::text),
      (v_course1_id, 15, 4, 12, gen_random_uuid()::text),
      (v_course1_id, 16, 3, 18, gen_random_uuid()::text),
      (v_course1_id, 17, 5,  4, gen_random_uuid()::text),
      (v_course1_id, 18, 4, 14, gen_random_uuid()::text)
    ON CONFLICT (course_id, hole_number) DO NOTHING;

    -- Black tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course1_id, 'Black', 74.1, 140, 7167, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 402, gen_random_uuid()::text),
        (v_tee_id,  2, 398, gen_random_uuid()::text),
        (v_tee_id,  3, 178, gen_random_uuid()::text),
        (v_tee_id,  4, 548, gen_random_uuid()::text),
        (v_tee_id,  5, 410, gen_random_uuid()::text),
        (v_tee_id,  6, 385, gen_random_uuid()::text),
        (v_tee_id,  7, 195, gen_random_uuid()::text),
        (v_tee_id,  8, 532, gen_random_uuid()::text),
        (v_tee_id,  9, 375, gen_random_uuid()::text),
        (v_tee_id, 10, 388, gen_random_uuid()::text),
        (v_tee_id, 11, 165, gen_random_uuid()::text),
        (v_tee_id, 12, 395, gen_random_uuid()::text),
        (v_tee_id, 13, 526, gen_random_uuid()::text),
        (v_tee_id, 14, 418, gen_random_uuid()::text),
        (v_tee_id, 15, 385, gen_random_uuid()::text),
        (v_tee_id, 16, 172, gen_random_uuid()::text),
        (v_tee_id, 17, 520, gen_random_uuid()::text),
        (v_tee_id, 18, 371, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;

    -- White tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course1_id, 'White', 71.2, 130, 6485, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 370, gen_random_uuid()::text),
        (v_tee_id,  2, 365, gen_random_uuid()::text),
        (v_tee_id,  3, 155, gen_random_uuid()::text),
        (v_tee_id,  4, 510, gen_random_uuid()::text),
        (v_tee_id,  5, 375, gen_random_uuid()::text),
        (v_tee_id,  6, 355, gen_random_uuid()::text),
        (v_tee_id,  7, 170, gen_random_uuid()::text),
        (v_tee_id,  8, 495, gen_random_uuid()::text),
        (v_tee_id,  9, 345, gen_random_uuid()::text),
        (v_tee_id, 10, 355, gen_random_uuid()::text),
        (v_tee_id, 11, 145, gen_random_uuid()::text),
        (v_tee_id, 12, 365, gen_random_uuid()::text),
        (v_tee_id, 13, 490, gen_random_uuid()::text),
        (v_tee_id, 14, 385, gen_random_uuid()::text),
        (v_tee_id, 15, 355, gen_random_uuid()::text),
        (v_tee_id, 16, 150, gen_random_uuid()::text),
        (v_tee_id, 17, 485, gen_random_uuid()::text),
        (v_tee_id, 18, 340, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;
  END IF;

  -- ─── Course 2: Alabang Country Club ───────────────────────
  INSERT INTO courses (user_id, course_name, location, notes, course_external_id)
    VALUES (v_user_id, 'Alabang Country Club', 'Alabang, Muntinlupa', NULL, gen_random_uuid()::text)
    ON CONFLICT (user_id, course_name) DO NOTHING
    RETURNING course_id INTO v_course2_id;

  IF v_course2_id IS NOT NULL THEN
    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index, hole_external_id) VALUES
      (v_course2_id,  1, 4,  3, gen_random_uuid()::text),
      (v_course2_id,  2, 5, 11, gen_random_uuid()::text),
      (v_course2_id,  3, 4,  7, gen_random_uuid()::text),
      (v_course2_id,  4, 3, 17, gen_random_uuid()::text),
      (v_course2_id,  5, 4,  1, gen_random_uuid()::text),
      (v_course2_id,  6, 5, 13, gen_random_uuid()::text),
      (v_course2_id,  7, 4,  5, gen_random_uuid()::text),
      (v_course2_id,  8, 3, 15, gen_random_uuid()::text),
      (v_course2_id,  9, 4,  9, gen_random_uuid()::text),
      (v_course2_id, 10, 4,  4, gen_random_uuid()::text),
      (v_course2_id, 11, 4, 10, gen_random_uuid()::text),
      (v_course2_id, 12, 3, 16, gen_random_uuid()::text),
      (v_course2_id, 13, 5,  2, gen_random_uuid()::text),
      (v_course2_id, 14, 4,  8, gen_random_uuid()::text),
      (v_course2_id, 15, 4, 12, gen_random_uuid()::text),
      (v_course2_id, 16, 5,  6, gen_random_uuid()::text),
      (v_course2_id, 17, 3, 18, gen_random_uuid()::text),
      (v_course2_id, 18, 4, 14, gen_random_uuid()::text)
    ON CONFLICT (course_id, hole_number) DO NOTHING;

    -- Championship tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course2_id, 'Championship', 72.8, 133, 6804, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 388, gen_random_uuid()::text),
        (v_tee_id,  2, 520, gen_random_uuid()::text),
        (v_tee_id,  3, 405, gen_random_uuid()::text),
        (v_tee_id,  4, 182, gen_random_uuid()::text),
        (v_tee_id,  5, 410, gen_random_uuid()::text),
        (v_tee_id,  6, 515, gen_random_uuid()::text),
        (v_tee_id,  7, 390, gen_random_uuid()::text),
        (v_tee_id,  8, 168, gen_random_uuid()::text),
        (v_tee_id,  9, 392, gen_random_uuid()::text),
        (v_tee_id, 10, 380, gen_random_uuid()::text),
        (v_tee_id, 11, 395, gen_random_uuid()::text),
        (v_tee_id, 12, 175, gen_random_uuid()::text),
        (v_tee_id, 13, 525, gen_random_uuid()::text),
        (v_tee_id, 14, 400, gen_random_uuid()::text),
        (v_tee_id, 15, 385, gen_random_uuid()::text),
        (v_tee_id, 16, 505, gen_random_uuid()::text),
        (v_tee_id, 17, 162, gen_random_uuid()::text),
        (v_tee_id, 18, 407, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;

    -- Regular tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course2_id, 'Regular', 70.1, 125, 6218, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 355, gen_random_uuid()::text),
        (v_tee_id,  2, 480, gen_random_uuid()::text),
        (v_tee_id,  3, 372, gen_random_uuid()::text),
        (v_tee_id,  4, 158, gen_random_uuid()::text),
        (v_tee_id,  5, 375, gen_random_uuid()::text),
        (v_tee_id,  6, 475, gen_random_uuid()::text),
        (v_tee_id,  7, 358, gen_random_uuid()::text),
        (v_tee_id,  8, 148, gen_random_uuid()::text),
        (v_tee_id,  9, 360, gen_random_uuid()::text),
        (v_tee_id, 10, 348, gen_random_uuid()::text),
        (v_tee_id, 11, 362, gen_random_uuid()::text),
        (v_tee_id, 12, 152, gen_random_uuid()::text),
        (v_tee_id, 13, 485, gen_random_uuid()::text),
        (v_tee_id, 14, 368, gen_random_uuid()::text),
        (v_tee_id, 15, 352, gen_random_uuid()::text),
        (v_tee_id, 16, 465, gen_random_uuid()::text),
        (v_tee_id, 17, 140, gen_random_uuid()::text),
        (v_tee_id, 18, 370, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;
  END IF;

  -- ─── Course 3: Tagaytay Midlands ──────────────────────────
  INSERT INTO courses (user_id, course_name, location, notes, course_external_id)
    VALUES (v_user_id, 'Tagaytay Midlands', 'Tagaytay, Cavite', NULL, gen_random_uuid()::text)
    ON CONFLICT (user_id, course_name) DO NOTHING
    RETURNING course_id INTO v_course3_id;

  IF v_course3_id IS NOT NULL THEN
    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index, hole_external_id) VALUES
      (v_course3_id,  1, 4,  5, gen_random_uuid()::text),
      (v_course3_id,  2, 3, 15, gen_random_uuid()::text),
      (v_course3_id,  3, 5,  1, gen_random_uuid()::text),
      (v_course3_id,  4, 4,  9, gen_random_uuid()::text),
      (v_course3_id,  5, 4,  3, gen_random_uuid()::text),
      (v_course3_id,  6, 3, 17, gen_random_uuid()::text),
      (v_course3_id,  7, 5,  7, gen_random_uuid()::text),
      (v_course3_id,  8, 4, 11, gen_random_uuid()::text),
      (v_course3_id,  9, 4, 13, gen_random_uuid()::text),
      (v_course3_id, 10, 4,  6, gen_random_uuid()::text),
      (v_course3_id, 11, 5,  2, gen_random_uuid()::text),
      (v_course3_id, 12, 4, 10, gen_random_uuid()::text),
      (v_course3_id, 13, 3, 16, gen_random_uuid()::text),
      (v_course3_id, 14, 4,  4, gen_random_uuid()::text),
      (v_course3_id, 15, 5,  8, gen_random_uuid()::text),
      (v_course3_id, 16, 4, 12, gen_random_uuid()::text),
      (v_course3_id, 17, 3, 18, gen_random_uuid()::text),
      (v_course3_id, 18, 4, 14, gen_random_uuid()::text)
    ON CONFLICT (course_id, hole_number) DO NOTHING;

    -- Championship tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course3_id, 'Championship', 73.4, 136, 6940, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 392, gen_random_uuid()::text),
        (v_tee_id,  2, 178, gen_random_uuid()::text),
        (v_tee_id,  3, 538, gen_random_uuid()::text),
        (v_tee_id,  4, 415, gen_random_uuid()::text),
        (v_tee_id,  5, 405, gen_random_uuid()::text),
        (v_tee_id,  6, 170, gen_random_uuid()::text),
        (v_tee_id,  7, 525, gen_random_uuid()::text),
        (v_tee_id,  8, 388, gen_random_uuid()::text),
        (v_tee_id,  9, 380, gen_random_uuid()::text),
        (v_tee_id, 10, 398, gen_random_uuid()::text),
        (v_tee_id, 11, 542, gen_random_uuid()::text),
        (v_tee_id, 12, 410, gen_random_uuid()::text),
        (v_tee_id, 13, 185, gen_random_uuid()::text),
        (v_tee_id, 14, 402, gen_random_uuid()::text),
        (v_tee_id, 15, 530, gen_random_uuid()::text),
        (v_tee_id, 16, 395, gen_random_uuid()::text),
        (v_tee_id, 17, 168, gen_random_uuid()::text),
        (v_tee_id, 18, 419, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;

    -- Member tees
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage, tee_external_id)
      VALUES (v_course3_id, 'Member', 70.8, 127, 6320, gen_random_uuid()::text)
      ON CONFLICT (course_id, tee_name) DO NOTHING
      RETURNING tee_id INTO v_tee_id;
    IF v_tee_id IS NOT NULL THEN
      INSERT INTO tee_holes (tee_id, hole_number, yardage, tee_hole_external_id) VALUES
        (v_tee_id,  1, 362, gen_random_uuid()::text),
        (v_tee_id,  2, 155, gen_random_uuid()::text),
        (v_tee_id,  3, 495, gen_random_uuid()::text),
        (v_tee_id,  4, 382, gen_random_uuid()::text),
        (v_tee_id,  5, 372, gen_random_uuid()::text),
        (v_tee_id,  6, 148, gen_random_uuid()::text),
        (v_tee_id,  7, 485, gen_random_uuid()::text),
        (v_tee_id,  8, 358, gen_random_uuid()::text),
        (v_tee_id,  9, 350, gen_random_uuid()::text),
        (v_tee_id, 10, 368, gen_random_uuid()::text),
        (v_tee_id, 11, 502, gen_random_uuid()::text),
        (v_tee_id, 12, 378, gen_random_uuid()::text),
        (v_tee_id, 13, 162, gen_random_uuid()::text),
        (v_tee_id, 14, 370, gen_random_uuid()::text),
        (v_tee_id, 15, 492, gen_random_uuid()::text),
        (v_tee_id, 16, 362, gen_random_uuid()::text),
        (v_tee_id, 17, 145, gen_random_uuid()::text),
        (v_tee_id, 18, 389, gen_random_uuid()::text)
      ON CONFLICT (tee_id, hole_number) DO NOTHING;
    END IF;
  END IF;

  RAISE NOTICE 'Seed complete for user %', v_user_id;
END $$;
