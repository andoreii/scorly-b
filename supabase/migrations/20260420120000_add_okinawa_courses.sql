-- =============================================================
-- Add seven Okinawa, Japan courses
--   1. Ginoza Country Club            — source: hole19golf.com/courses/ginoza-cc
--   2. Atta Terrace Golf Resort       — source: terrace.co.jp/en/atta/course/
--   3. Southern Links Golf Resort     — source: reserve.accordiagolf.com/en/global/golfCourse/okinawa/southernlinks/layout
--   4. Chura Orchard Golf Club        — source: hole19golf.com/courses/chura-orchard-golf-club
--   5. Okinawa Country Club Golf      — source: reserve.accordiagolf.com/golfCourse/okinawa/okinawa/layout (par 70)
--   6. Palm Hills Golf Resort Club    — source: reserve.accordiagolf.com/en/global/golfCourse/okinawa/palmhills/layout (Palm + Hills nines)
--   7. PGM Golf Resort                — source: hole19golf.com/courses/pgm-golf-resort-okinawa (Bougainvillea + Deigo; Gold tees — only hole-level set published)
-- Each course: 18 holes + one tee set with per-hole yardages. Course/slope ratings left NULL when unpublished.
-- Handicap indexes left NULL on Atta Terrace (published values contain duplicates — likely transcription artifact upstream).
-- =============================================================

DO $$
DECLARE
    v_user_id UUID;
    v_course_id INT;
    v_tee_id INT;
BEGIN
    SELECT id INTO v_user_id FROM auth.users LIMIT 1;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No user found in auth.users';
    END IF;

    -- =========================================================
    -- 1. Ginoza Country Club — par 72, 5,990 yds (Back)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Ginoza Country Club', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4, 15),
        (v_course_id,  2, 4,  3),
        (v_course_id,  3, 4,  9),
        (v_course_id,  4, 5,  1),
        (v_course_id,  5, 4, 13),
        (v_course_id,  6, 3,  7),
        (v_course_id,  7, 5, 17),
        (v_course_id,  8, 3,  5),
        (v_course_id,  9, 4, 11),
        (v_course_id, 10, 4, 16),
        (v_course_id, 11, 3,  4),
        (v_course_id, 12, 4, 10),
        (v_course_id, 13, 4,  2),
        (v_course_id, 14, 3, 14),
        (v_course_id, 15, 4,  8),
        (v_course_id, 16, 5, 18),
        (v_course_id, 17, 4,  6),
        (v_course_id, 18, 5, 12);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'Back', 5990)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 330),
        (v_tee_id,  2, 291),
        (v_tee_id,  3, 319),
        (v_tee_id,  4, 469),
        (v_tee_id,  5, 294),
        (v_tee_id,  6, 148),
        (v_tee_id,  7, 486),
        (v_tee_id,  8, 179),
        (v_tee_id,  9, 380),
        (v_tee_id, 10, 313),
        (v_tee_id, 11, 214),
        (v_tee_id, 12, 352),
        (v_tee_id, 13, 353),
        (v_tee_id, 14, 168),
        (v_tee_id, 15, 334),
        (v_tee_id, 16, 470),
        (v_tee_id, 17, 388),
        (v_tee_id, 18, 502);

    -- =========================================================
    -- 2. Atta Terrace Golf Resort — par 72, 6,056 yds (Regular)
    -- Handicap indexes not set (source had duplicate values).
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Atta Terrace Golf Resort', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par) VALUES
        (v_course_id,  1, 4),
        (v_course_id,  2, 4),
        (v_course_id,  3, 5),
        (v_course_id,  4, 3),
        (v_course_id,  5, 4),
        (v_course_id,  6, 4),
        (v_course_id,  7, 3),
        (v_course_id,  8, 4),
        (v_course_id,  9, 5),
        (v_course_id, 10, 5),
        (v_course_id, 11, 4),
        (v_course_id, 12, 4),
        (v_course_id, 13, 3),
        (v_course_id, 14, 4),
        (v_course_id, 15, 4),
        (v_course_id, 16, 3),
        (v_course_id, 17, 4),
        (v_course_id, 18, 5);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'Regular', 6056)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 306),
        (v_tee_id,  2, 440),
        (v_tee_id,  3, 472),
        (v_tee_id,  4, 134),
        (v_tee_id,  5, 343),
        (v_tee_id,  6, 280),
        (v_tee_id,  7, 156),
        (v_tee_id,  8, 383),
        (v_tee_id,  9, 529),
        (v_tee_id, 10, 443),
        (v_tee_id, 11, 273),
        (v_tee_id, 12, 353),
        (v_tee_id, 13, 142),
        (v_tee_id, 14, 382),
        (v_tee_id, 15, 346),
        (v_tee_id, 16, 167),
        (v_tee_id, 17, 407),
        (v_tee_id, 18, 500);

    -- =========================================================
    -- 3. Southern Links Golf Resort — par 72, 6,311 yds (White)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Southern Links Golf Resort', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4, 15),
        (v_course_id,  2, 4,  9),
        (v_course_id,  3, 5,  3),
        (v_course_id,  4, 3, 13),
        (v_course_id,  5, 4,  7),
        (v_course_id,  6, 4,  1),
        (v_course_id,  7, 4,  5),
        (v_course_id,  8, 3, 11),
        (v_course_id,  9, 5, 17),
        (v_course_id, 10, 5, 16),
        (v_course_id, 11, 4, 10),
        (v_course_id, 12, 4,  4),
        (v_course_id, 13, 3,  8),
        (v_course_id, 14, 5,  2),
        (v_course_id, 15, 4, 14),
        (v_course_id, 16, 4, 12),
        (v_course_id, 17, 3, 18),
        (v_course_id, 18, 4,  6);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'White', 6311)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 345),
        (v_tee_id,  2, 365),
        (v_tee_id,  3, 515),
        (v_tee_id,  4, 142),
        (v_tee_id,  5, 328),
        (v_tee_id,  6, 392),
        (v_tee_id,  7, 400),
        (v_tee_id,  8, 146),
        (v_tee_id,  9, 540),
        (v_tee_id, 10, 522),
        (v_tee_id, 11, 375),
        (v_tee_id, 12, 375),
        (v_tee_id, 13, 150),
        (v_tee_id, 14, 510),
        (v_tee_id, 15, 330),
        (v_tee_id, 16, 375),
        (v_tee_id, 17, 146),
        (v_tee_id, 18, 355);

    -- =========================================================
    -- 4. Chura Orchard Golf Club — par 72, 5,612 yds (Back)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Chura Orchard Golf Club', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4,  7),
        (v_course_id,  2, 5, 11),
        (v_course_id,  3, 3,  5),
        (v_course_id,  4, 5,  1),
        (v_course_id,  5, 4, 17),
        (v_course_id,  6, 4,  3),
        (v_course_id,  7, 4, 13),
        (v_course_id,  8, 3,  9),
        (v_course_id,  9, 4, 15),
        (v_course_id, 10, 4, 10),
        (v_course_id, 11, 5,  6),
        (v_course_id, 12, 3, 16),
        (v_course_id, 13, 4,  2),
        (v_course_id, 14, 3, 14),
        (v_course_id, 15, 4,  4),
        (v_course_id, 16, 4, 18),
        (v_course_id, 17, 5,  8),
        (v_course_id, 18, 4, 12);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'Back', 5612)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 338),
        (v_tee_id,  2, 471),
        (v_tee_id,  3, 178),
        (v_tee_id,  4, 505),
        (v_tee_id,  5, 343),
        (v_tee_id,  6, 279),
        (v_tee_id,  7, 284),
        (v_tee_id,  8, 178),
        (v_tee_id,  9, 302),
        (v_tee_id, 10, 279),
        (v_tee_id, 11, 466),
        (v_tee_id, 12, 114),
        (v_tee_id, 13, 325),
        (v_tee_id, 14, 133),
        (v_tee_id, 15, 370),
        (v_tee_id, 16, 302),
        (v_tee_id, 17, 439),
        (v_tee_id, 18, 306);

    -- =========================================================
    -- 5. Okinawa Country Club Golf — par 70, 5,394 yds (White)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Okinawa Country Club Golf', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4, 13),
        (v_course_id,  2, 4, 15),
        (v_course_id,  3, 4,  7),
        (v_course_id,  4, 4,  5),
        (v_course_id,  5, 4, 17),
        (v_course_id,  6, 3,  3),
        (v_course_id,  7, 5,  1),
        (v_course_id,  8, 3,  9),
        (v_course_id,  9, 4, 11),
        (v_course_id, 10, 4, 18),
        (v_course_id, 11, 4, 10),
        (v_course_id, 12, 3,  6),
        (v_course_id, 13, 4,  4),
        (v_course_id, 14, 5,  2),
        (v_course_id, 15, 4,  8),
        (v_course_id, 16, 4, 12),
        (v_course_id, 17, 3, 14),
        (v_course_id, 18, 4, 16);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'White', 5394)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 310),
        (v_tee_id,  2, 363),
        (v_tee_id,  3, 325),
        (v_tee_id,  4, 290),
        (v_tee_id,  5, 295),
        (v_tee_id,  6, 153),
        (v_tee_id,  7, 487),
        (v_tee_id,  8, 131),
        (v_tee_id,  9, 335),
        (v_tee_id, 10, 346),
        (v_tee_id, 11, 292),
        (v_tee_id, 12, 153),
        (v_tee_id, 13, 307),
        (v_tee_id, 14, 488),
        (v_tee_id, 15, 310),
        (v_tee_id, 16, 327),
        (v_tee_id, 17, 147),
        (v_tee_id, 18, 335);

    -- =========================================================
    -- 6. Palm Hills Golf Resort Club — par 72, 6,387 yds (White)
    -- Palm nine (1-9) + Hills nine (10-18)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Palm Hills Golf Resort Club', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4,  3),
        (v_course_id,  2, 4,  9),
        (v_course_id,  3, 3, 15),
        (v_course_id,  4, 4,  7),
        (v_course_id,  5, 5,  1),
        (v_course_id,  6, 3, 13),
        (v_course_id,  7, 5, 11),
        (v_course_id,  8, 4, 17),
        (v_course_id,  9, 4,  5),
        (v_course_id, 10, 4,  4),
        (v_course_id, 11, 3, 18),
        (v_course_id, 12, 5,  2),
        (v_course_id, 13, 3,  8),
        (v_course_id, 14, 4, 14),
        (v_course_id, 15, 5, 10),
        (v_course_id, 16, 4, 12),
        (v_course_id, 17, 4, 16),
        (v_course_id, 18, 4,  6);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'White', 6387)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 386),
        (v_tee_id,  2, 369),
        (v_tee_id,  3, 158),
        (v_tee_id,  4, 334),
        (v_tee_id,  5, 558),
        (v_tee_id,  6, 168),
        (v_tee_id,  7, 448),
        (v_tee_id,  8, 352),
        (v_tee_id,  9, 402),
        (v_tee_id, 10, 405),
        (v_tee_id, 11, 145),
        (v_tee_id, 12, 553),
        (v_tee_id, 13, 151),
        (v_tee_id, 14, 357),
        (v_tee_id, 15, 478),
        (v_tee_id, 16, 394),
        (v_tee_id, 17, 342),
        (v_tee_id, 18, 387);

    -- =========================================================
    -- 7. PGM Golf Resort — par 72, 5,115 yds (Gold)
    -- Bougainvillea nine (1-9) + Deigo nine (10-18)
    -- =========================================================
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'PGM Golf Resort', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 5,  9),
        (v_course_id,  2, 4, 15),
        (v_course_id,  3, 4,  3),
        (v_course_id,  4, 3, 13),
        (v_course_id,  5, 4,  7),
        (v_course_id,  6, 5,  1),
        (v_course_id,  7, 4, 11),
        (v_course_id,  8, 3, 17),
        (v_course_id,  9, 4,  5),
        (v_course_id, 10, 5, 16),
        (v_course_id, 11, 4,  4),
        (v_course_id, 12, 4, 10),
        (v_course_id, 13, 3, 14),
        (v_course_id, 14, 4,  8),
        (v_course_id, 15, 4,  2),
        (v_course_id, 16, 3, 12),
        (v_course_id, 17, 4, 18),
        (v_course_id, 18, 5,  6);

    INSERT INTO tees (course_id, tee_name, yardage)
    VALUES (v_course_id, 'Gold', 5115)
    RETURNING tee_id INTO v_tee_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_tee_id,  1, 480),
        (v_tee_id,  2, 257),
        (v_tee_id,  3, 341),
        (v_tee_id,  4, 115),
        (v_tee_id,  5, 248),
        (v_tee_id,  6, 458),
        (v_tee_id,  7, 323),
        (v_tee_id,  8, 131),
        (v_tee_id,  9, 256),
        (v_tee_id, 10, 396),
        (v_tee_id, 11, 249),
        (v_tee_id, 12, 319),
        (v_tee_id, 13, 141),
        (v_tee_id, 14, 283),
        (v_tee_id, 15, 304),
        (v_tee_id, 16, 136),
        (v_tee_id, 17, 277),
        (v_tee_id, 18, 401);

END $$;
