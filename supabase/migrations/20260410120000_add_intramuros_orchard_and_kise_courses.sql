-- Sources used:
-- Intramuros / Orchard scorecards: Golfify course pages
-- Kanehide Kise scorecard: GolfPass course page

DO $$
DECLARE
    v_user_id UUID;
    v_course_id INT;
    v_tee_id INT;
    v_course JSONB;
    v_tee JSONB;
BEGIN
    SELECT id INTO v_user_id
    FROM auth.users
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No users found in auth.users. Seed a user before running course migrations.';
    END IF;

    FOR v_course IN
        SELECT *
        FROM jsonb_array_elements(
            '[
              {
                "course_name": "Intramuros Golf Club",
                "location": "Intramuros, Metro Manila, Philippines",
                "holes": [
                  {"par": 3, "handicap": 17},
                  {"par": 4, "handicap": 7},
                  {"par": 3, "handicap": 13},
                  {"par": 4, "handicap": 3},
                  {"par": 4, "handicap": 5},
                  {"par": 3, "handicap": 15},
                  {"par": 5, "handicap": 1},
                  {"par": 4, "handicap": 9},
                  {"par": 4, "handicap": 11},
                  {"par": 3, "handicap": 12},
                  {"par": 4, "handicap": 4},
                  {"par": 3, "handicap": 18},
                  {"par": 4, "handicap": 6},
                  {"par": 4, "handicap": 10},
                  {"par": 4, "handicap": 2},
                  {"par": 3, "handicap": 16},
                  {"par": 4, "handicap": 8},
                  {"par": 3, "handicap": 14}
                ],
                "tees": [
                  {
                    "name": "Blue",
                    "course_rating": 62.7,
                    "slope_rating": 104,
                    "yardage": 4151,
                    "holes": [141, 259, 108, 337, 327, 152, 427, 241, 237, 164, 279, 120, 280, 269, 276, 120, 256, 158]
                  },
                  {
                    "name": "White",
                    "course_rating": 61.2,
                    "slope_rating": 101,
                    "yardage": 3751,
                    "holes": [124, 237, 90, 315, 319, 109, 386, 227, 217, 148, 261, 106, 268, 246, 223, 93, 239, 143]
                  },
                  {
                    "name": "Red",
                    "course_rating": 60.8,
                    "slope_rating": 97,
                    "yardage": 3280,
                    "holes": [98, 215, 68, 300, 261, 91, 328, 204, 187, 115, 240, 86, 239, 222, 189, 85, 227, 125]
                  }
                ]
              },
              {
                "course_name": "The Orchard Golf & Country Club - Arnold Palmer Course",
                "location": "Dasmarinas, Cavite, Philippines",
                "holes": [
                  {"par": 4, "handicap": 11},
                  {"par": 5, "handicap": 9},
                  {"par": 3, "handicap": 13},
                  {"par": 4, "handicap": 5},
                  {"par": 3, "handicap": 17},
                  {"par": 5, "handicap": 1},
                  {"par": 3, "handicap": 15},
                  {"par": 4, "handicap": 3},
                  {"par": 4, "handicap": 7},
                  {"par": 4, "handicap": 2},
                  {"par": 4, "handicap": 14},
                  {"par": 3, "handicap": 18},
                  {"par": 4, "handicap": 12},
                  {"par": 5, "handicap": 8},
                  {"par": 4, "handicap": 4},
                  {"par": 3, "handicap": 16},
                  {"par": 4, "handicap": 10},
                  {"par": 5, "handicap": 6}
                ],
                "tees": [
                  {
                    "name": "Gold",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 7061,
                    "holes": [444, 521, 455, 487, 191, 583, 194, 404, 418, 403, 341, 151, 384, 514, 422, 207, 405, 537]
                  },
                  {
                    "name": "Blue",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 6527,
                    "holes": [413, 496, 359, 456, 174, 536, 176, 383, 400, 374, 320, 132, 361, 480, 391, 187, 383, 506]
                  },
                  {
                    "name": "White - A",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 5945,
                    "holes": [387, 456, 349, 414, 150, 488, 154, 337, 362, 334, 297, 114, 332, 465, 337, 170, 347, 452]
                  },
                  {
                    "name": "White - B",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 5579,
                    "holes": [363, 412, 327, 391, 133, 445, 154, 301, 330, 294, 272, 114, 332, 436, 337, 170, 316, 452]
                  },
                  {
                    "name": "Red",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 5062,
                    "holes": [341, 385, 303, 363, 118, 412, 136, 271, 300, 227, 263, 100, 281, 427, 304, 142, 275, 414]
                  }
                ]
              },
              {
                "course_name": "The Orchard Golf & Country Club - Gary Player Course",
                "location": "Dasmarinas, Cavite, Philippines",
                "holes": [
                  {"par": 4, "handicap": 9},
                  {"par": 4, "handicap": 3},
                  {"par": 3, "handicap": 17},
                  {"par": 5, "handicap": 1},
                  {"par": 3, "handicap": 15},
                  {"par": 4, "handicap": 7},
                  {"par": 4, "handicap": 13},
                  {"par": 4, "handicap": 11},
                  {"par": 5, "handicap": 5},
                  {"par": 4, "handicap": 10},
                  {"par": 3, "handicap": 16},
                  {"par": 5, "handicap": 2},
                  {"par": 4, "handicap": 4},
                  {"par": 3, "handicap": 18},
                  {"par": 4, "handicap": 8},
                  {"par": 4, "handicap": 14},
                  {"par": 4, "handicap": 12},
                  {"par": 5, "handicap": 6}
                ],
                "tees": [
                  {
                    "name": "Gold",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 6925,
                    "holes": [365, 393, 191, 509, 215, 372, 388, 343, 561, 436, 175, 615, 372, 186, 462, 352, 484, 506]
                  },
                  {
                    "name": "Blue",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 6499,
                    "holes": [331, 371, 176, 485, 199, 346, 363, 317, 534, 421, 160, 567, 354, 165, 432, 335, 459, 484]
                  },
                  {
                    "name": "White - A",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 6138,
                    "holes": [316, 336, 171, 469, 189, 325, 334, 286, 508, 410, 154, 532, 329, 157, 405, 316, 439, 462]
                  },
                  {
                    "name": "White - B",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 5826,
                    "holes": [311, 321, 158, 459, 181, 313, 316, 257, 475, 395, 143, 507, 312, 150, 381, 294, 414, 439]
                  },
                  {
                    "name": "Red",
                    "course_rating": null,
                    "slope_rating": null,
                    "yardage": 5485,
                    "holes": [292, 291, 149, 441, 173, 291, 303, 230, 455, 371, 135, 482, 290, 144, 359, 277, 397, 405]
                  }
                ]
              },
              {
                "course_name": "Kanehide Kise Country Club",
                "location": "Kise, Nago, Okinawa, Japan",
                "holes": [
                  {"par": 4, "handicap": 15},
                  {"par": 4, "handicap": 3},
                  {"par": 3, "handicap": 7},
                  {"par": 4, "handicap": 13},
                  {"par": 5, "handicap": 5},
                  {"par": 4, "handicap": 1},
                  {"par": 4, "handicap": 9},
                  {"par": 3, "handicap": 17},
                  {"par": 5, "handicap": 11},
                  {"par": 4, "handicap": 14},
                  {"par": 4, "handicap": 18},
                  {"par": 5, "handicap": 8},
                  {"par": 4, "handicap": 2},
                  {"par": 3, "handicap": 10},
                  {"par": 4, "handicap": 6},
                  {"par": 4, "handicap": 12},
                  {"par": 3, "handicap": 16},
                  {"par": 5, "handicap": 4}
                ],
                "tees": [
                  {
                    "name": "Champion",
                    "course_rating": 74.9,
                    "slope_rating": 131.0,
                    "yardage": 7204,
                    "holes": [395, 452, 236, 376, 546, 454, 393, 185, 605, 444, 356, 526, 464, 186, 444, 397, 201, 544]
                  },
                  {
                    "name": "Back",
                    "course_rating": 73.1,
                    "slope_rating": 123.0,
                    "yardage": 6836,
                    "holes": [372, 421, 217, 356, 532, 424, 378, 165, 583, 434, 327, 507, 444, 161, 428, 388, 182, 517]
                  },
                  {
                    "name": "Regular",
                    "course_rating": 70.7,
                    "slope_rating": 121.0,
                    "yardage": 6255,
                    "holes": [347, 388, 177, 333, 501, 384, 346, 152, 524, 404, 296, 472, 378, 140, 396, 373, 162, 482]
                  },
                  {
                    "name": "Front",
                    "course_rating": 69.2,
                    "slope_rating": 117.0,
                    "yardage": 5516,
                    "holes": [317, 346, 121, 288, 476, 346, 307, 119, 496, 348, 260, 397, 339, 126, 333, 310, 136, 451]
                  },
                  {
                    "name": "Ladies",
                    "course_rating": 66.9,
                    "slope_rating": 109.0,
                    "yardage": 4603,
                    "holes": [260, 317, 121, 222, 399, 307, 237, 119, 386, 295, 224, 397, 236, 103, 289, 241, 97, 353]
                  }
                ]
              }
            ]'::jsonb
        )
    LOOP
        INSERT INTO courses (user_id, course_name, location)
        VALUES (
            v_user_id,
            v_course->>'course_name',
            v_course->>'location'
        )
        RETURNING course_id INTO v_course_id;

        INSERT INTO holes (course_id, hole_number, par, hole_handicap_index)
        SELECT
            v_course_id,
            hole.ordinality::INT,
            (hole.value->>'par')::INT,
            (hole.value->>'handicap')::INT
        FROM jsonb_array_elements(v_course->'holes') WITH ORDINALITY AS hole(value, ordinality);

        FOR v_tee IN
            SELECT *
            FROM jsonb_array_elements(v_course->'tees')
        LOOP
            INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
            VALUES (
                v_course_id,
                v_tee->>'name',
                CASE
                    WHEN v_tee->>'course_rating' IS NULL THEN NULL
                    ELSE (v_tee->>'course_rating')::NUMERIC(4,1)
                END,
                CASE
                    WHEN v_tee->>'slope_rating' IS NULL THEN NULL
                    ELSE (v_tee->>'slope_rating')::NUMERIC(4,1)
                END,
                (v_tee->>'yardage')::INT
            )
            RETURNING tee_id INTO v_tee_id;

            INSERT INTO tee_holes (tee_id, hole_number, yardage)
            SELECT
                v_tee_id,
                tee_hole.ordinality::INT,
                tee_hole.value::INT
            FROM jsonb_array_elements_text(v_tee->'holes') WITH ORDINALITY AS tee_hole(value, ordinality);
        END LOOP;
    END LOOP;
END $$;
