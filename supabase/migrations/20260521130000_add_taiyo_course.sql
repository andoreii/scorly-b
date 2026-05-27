-- ---------------------------------------------------------------
-- Seed: Taiyo Golf Course (Okinawa, Japan)
--
-- Par 72 (Out 36 / In 36). Four tees: Black, Blue, White, Red.
-- Course/slope ratings are men's values; women's pending a schema change.
-- ---------------------------------------------------------------

DO $$
DECLARE
    v_user_id   UUID := 'c33a2b8f-cf18-47cc-8987-f5fe84000183';
    v_course_id INT;
    v_black_id  INT;
    v_blue_id   INT;
    v_white_id  INT;
    v_red_id    INT;
BEGIN
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Taiyo Golf Course', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index)
    VALUES
        (v_course_id,  1, 5,  5),
        (v_course_id,  2, 4, 11),
        (v_course_id,  3, 4, 13),
        (v_course_id,  4, 5,  1),
        (v_course_id,  5, 4,  9),
        (v_course_id,  6, 3, 17),
        (v_course_id,  7, 4,  7),
        (v_course_id,  8, 3, 15),
        (v_course_id,  9, 4,  3),
        (v_course_id, 10, 5,  6),
        (v_course_id, 11, 4, 16),
        (v_course_id, 12, 3, 12),
        (v_course_id, 13, 4,  4),
        (v_course_id, 14, 4, 14),
        (v_course_id, 15, 3, 18),
        (v_course_id, 16, 4,  8),
        (v_course_id, 17, 5,  2),
        (v_course_id, 18, 4, 10);

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Black', 72.8, 129, 6653)
    RETURNING tee_id INTO v_black_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Blue', 70.7, 124, 6320)
    RETURNING tee_id INTO v_blue_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'White', 68.2, 122, 5950)
    RETURNING tee_id INTO v_white_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Red', 65.0, 109, 5356)
    RETURNING tee_id INTO v_red_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage)
    VALUES
        (v_black_id,  1, 530), (v_black_id,  2, 359), (v_black_id,  3, 370),
        (v_black_id,  4, 517), (v_black_id,  5, 384), (v_black_id,  6, 174),
        (v_black_id,  7, 388), (v_black_id,  8, 180), (v_black_id,  9, 437),
        (v_black_id, 10, 524), (v_black_id, 11, 360), (v_black_id, 12, 182),
        (v_black_id, 13, 449), (v_black_id, 14, 347), (v_black_id, 15, 160),
        (v_black_id, 16, 341), (v_black_id, 17, 538), (v_black_id, 18, 413),

        (v_blue_id,   1, 501), (v_blue_id,   2, 349), (v_blue_id,   3, 366),
        (v_blue_id,   4, 487), (v_blue_id,   5, 376), (v_blue_id,   6, 164),
        (v_blue_id,   7, 380), (v_blue_id,   8, 158), (v_blue_id,   9, 394),
        (v_blue_id,  10, 499), (v_blue_id,  11, 328), (v_blue_id,  12, 177),
        (v_blue_id,  13, 426), (v_blue_id,  14, 337), (v_blue_id,  15, 144),
        (v_blue_id,  16, 331), (v_blue_id,  17, 519), (v_blue_id,  18, 384),

        (v_white_id,  1, 483), (v_white_id,  2, 324), (v_white_id,  3, 328),
        (v_white_id,  4, 471), (v_white_id,  5, 334), (v_white_id,  6, 138),
        (v_white_id,  7, 350), (v_white_id,  8, 150), (v_white_id,  9, 372),
        (v_white_id, 10, 487), (v_white_id, 11, 314), (v_white_id, 12, 169),
        (v_white_id, 13, 410), (v_white_id, 14, 315), (v_white_id, 15, 139),
        (v_white_id, 16, 286), (v_white_id, 17, 507), (v_white_id, 18, 373),

        (v_red_id,    1, 462), (v_red_id,    2, 298), (v_red_id,    3, 297),
        (v_red_id,    4, 438), (v_red_id,    5, 308), (v_red_id,    6, 116),
        (v_red_id,    7, 327), (v_red_id,    8, 129), (v_red_id,    9, 323),
        (v_red_id,   10, 459), (v_red_id,   11, 282), (v_red_id,   12, 104),
        (v_red_id,   13, 335), (v_red_id,   14, 291), (v_red_id,   15, 122),
        (v_red_id,   16, 244), (v_red_id,   17, 489), (v_red_id,   18, 332);
END $$;
