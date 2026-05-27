-- ---------------------------------------------------------------
-- Seed: Banyan Tree Golf Course (Okinawa, Japan)
--
-- First real course for user c33a2b8f-cf18-47cc-8987-f5fe84000183.
-- Par 72 (Out 35 / In 37). Four tees: Black, Gold, Silver, Bronze.
-- Course/slope ratings are men's values; women's pending a schema change.
-- ---------------------------------------------------------------

DO $$
DECLARE
    v_user_id   UUID := 'c33a2b8f-cf18-47cc-8987-f5fe84000183';
    v_course_id INT;
    v_black_id  INT;
    v_gold_id   INT;
    v_silver_id INT;
    v_bronze_id INT;
BEGIN
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Banyan Tree Golf Course', 'Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index)
    VALUES
        (v_course_id,  1, 4, 17),
        (v_course_id,  2, 5, 15),
        (v_course_id,  3, 4,  5),
        (v_course_id,  4, 3, 11),
        (v_course_id,  5, 4,  7),
        (v_course_id,  6, 3,  1),
        (v_course_id,  7, 4,  3),
        (v_course_id,  8, 4, 13),
        (v_course_id,  9, 4,  9),
        (v_course_id, 10, 5, 10),
        (v_course_id, 11, 4,  8),
        (v_course_id, 12, 3,  2),
        (v_course_id, 13, 4,  6),
        (v_course_id, 14, 3, 16),
        (v_course_id, 15, 4, 12),
        (v_course_id, 16, 5, 18),
        (v_course_id, 17, 5,  4),
        (v_course_id, 18, 4, 14);

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Black', 72.6, 130, 6681)
    RETURNING tee_id INTO v_black_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Gold', 70.9, 126, 6279)
    RETURNING tee_id INTO v_gold_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Silver', 67.6, 120, 5607)
    RETURNING tee_id INTO v_silver_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Bronze', 63.7, 104, 4752)
    RETURNING tee_id INTO v_bronze_id;

    INSERT INTO tee_holes (tee_id, hole_number, yardage)
    VALUES
        (v_black_id,   1, 345), (v_black_id,   2, 526), (v_black_id,   3, 372),
        (v_black_id,   4, 149), (v_black_id,   5, 385), (v_black_id,   6, 206),
        (v_black_id,   7, 414), (v_black_id,   8, 404), (v_black_id,   9, 396),
        (v_black_id,  10, 592), (v_black_id,  11, 456), (v_black_id,  12, 192),
        (v_black_id,  13, 368), (v_black_id,  14, 156), (v_black_id,  15, 345),
        (v_black_id,  16, 530), (v_black_id,  17, 476), (v_black_id,  18, 369),

        (v_gold_id,    1, 312), (v_gold_id,    2, 476), (v_gold_id,    3, 353),
        (v_gold_id,    4, 141), (v_gold_id,    5, 373), (v_gold_id,    6, 184),
        (v_gold_id,    7, 401), (v_gold_id,    8, 384), (v_gold_id,    9, 363),
        (v_gold_id,   10, 581), (v_gold_id,   11, 415), (v_gold_id,   12, 180),
        (v_gold_id,   13, 349), (v_gold_id,   14, 146), (v_gold_id,   15, 338),
        (v_gold_id,   16, 500), (v_gold_id,   17, 440), (v_gold_id,   18, 343),

        (v_silver_id,  1, 293), (v_silver_id,  2, 426), (v_silver_id,  3, 304),
        (v_silver_id,  4, 118), (v_silver_id,  5, 309), (v_silver_id,  6, 155),
        (v_silver_id,  7, 358), (v_silver_id,  8, 357), (v_silver_id,  9, 333),
        (v_silver_id, 10, 503), (v_silver_id, 11, 362), (v_silver_id, 12, 164),
        (v_silver_id, 13, 320), (v_silver_id, 14, 121), (v_silver_id, 15, 292),
        (v_silver_id, 16, 455), (v_silver_id, 17, 410), (v_silver_id, 18, 327),

        (v_bronze_id,  1, 210), (v_bronze_id,  2, 405), (v_bronze_id,  3, 231),
        (v_bronze_id,  4, 100), (v_bronze_id,  5, 246), (v_bronze_id,  6, 113),
        (v_bronze_id,  7, 318), (v_bronze_id,  8, 323), (v_bronze_id,  9, 277),
        (v_bronze_id, 10, 452), (v_bronze_id, 11, 317), (v_bronze_id, 12, 130),
        (v_bronze_id, 13, 274), (v_bronze_id, 14,  93), (v_bronze_id, 15, 258),
        (v_bronze_id, 16, 363), (v_bronze_id, 17, 350), (v_bronze_id, 18, 292);
END $$;
