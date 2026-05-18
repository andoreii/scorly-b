import Foundation
import Testing
@testable import ScorlyData

/// JSON round-trip tests pin the wire format of every Row type so any
/// accidental property rename or coding-key drift breaks loudly. Encoder
/// + decoder are `SupabaseConfig.encoder` / `decoder` so the tests double
/// as a check that snake-case bridging works for camelCase properties.
struct SupabaseRowsTests {
    private let encoder = SupabaseConfig.encoder
    private let decoder = SupabaseConfig.decoder

    @Test("CourseRow round-trips through snake-case JSON")
    func courseRowRoundTrip() throws {
        let row = CourseRow(
            courseId: 42,
            userId: UUID(),
            courseName: "Banyan Tree GC",
            location: "Phuket",
            notes: nil,
            colorTheme: "Forest",
            courseExternalId: UUID().uuidString,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tees: nil,
            holes: nil
        )
        let data = try encoder.encode(row)
        let json = try #require(String(data: data, encoding: .utf8))
        // Snake case bridging keys check.
        #expect(json.contains("\"course_id\""))
        #expect(json.contains("\"course_name\""))
        #expect(json.contains("\"course_external_id\""))
        let decoded = try decoder.decode(CourseRow.self, from: data)
        #expect(decoded == row)
    }

    @Test("CourseRow decodes v1 schema payloads without external IDs")
    func courseRowDecodesLegacyPayload() throws {
        let json = Data(
            """
            {
              "course_id": 42,
              "user_id": "00000000-0000-4000-8000-000000000001",
              "course_name": "Banyan Tree GC",
              "location": "Phuket",
              "notes": null,
              "color_theme": "Forest",
              "created_at": "2026-04-26T12:00:00Z",
              "tees": [
                {
                  "tee_id": 7,
                  "course_id": 42,
                  "tee_name": "White",
                  "course_rating": 70.1,
                  "slope_rating": 120,
                  "yardage": null,
                  "tee_holes": [
                    {
                      "tee_hole_id": 9,
                      "tee_id": 7,
                      "hole_number": 1,
                      "yardage": 350
                    }
                  ]
                }
              ],
              "holes": [
                {
                  "hole_id": 8,
                  "course_id": 42,
                  "hole_number": 1,
                  "par": 4,
                  "hole_handicap_index": null
                }
              ]
            }
            """.utf8
        )

        let decoded = try decoder.decode(CourseRow.self, from: json)

        #expect(decoded.courseExternalId == nil)
        #expect(decoded.tees?.first?.teeExternalId == nil)
        #expect(decoded.tees?.first?.teeHoles?.first?.teeHoleExternalId == nil)
        #expect(decoded.holes?.first?.holeExternalId == nil)
    }

    @Test("RoundInsert round-trips with date-only datePlayed string")
    func roundInsertRoundTrip() throws {
        let insert = RoundInsert(
            userId: UUID(),
            courseId: 7,
            teeId: 3,
            datePlayed: "2026-04-26",
            holesPlayed: "18",
            roundType: "Casual",
            roundFormat: "Stroke",
            conditions: "Sunny,Windy",
            temperature: 72,
            walkingVsRiding: "Walking",
            startedAt: nil,
            finishedAt: nil,
            mentalState: 8,
            roundExternalId: UUID().uuidString,
            notes: nil,
            whsDifferential: Decimal(string: "16.4"),
            totalScore: 82
        )
        let data = try encoder.encode(insert)
        let decoded = try decoder.decode(RoundInsert.self, from: data)
        #expect(decoded == insert)
    }

    @Test("GoalRow preserves payload Data and discriminator string verbatim")
    func goalRowRoundTrip() throws {
        let payload = Data("{\"target\":85}".utf8)
        let row = GoalRow(
            goalId: 1,
            userId: UUID(),
            goalExternalId: UUID().uuidString,
            kind: "scoreUnderOrEqual",
            payload: payload,
            title: "Break 85",
            notes: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            deadline: nil,
            archivedAt: nil
        )
        let data = try encoder.encode(row)
        let decoded = try decoder.decode(GoalRow.self, from: data)
        #expect(decoded == row)
        #expect(decoded.payload == payload)
    }

    @Test("HoleStatInsert nullable fields encode + decode symmetrically")
    func holeStatInsertNullableFields() throws {
        let insert = HoleStatInsert(
            roundId: 1,
            holeNumber: 4,
            strokes: 5,
            putts: 2,
            teeShot: "Fairway",
            approach: "Green",
            puttDistances: [12, 4],
            teeShotDistance: 280,
            approachDistance: 150,
            pinPosition: "Middle",
            holeStatExternalId: UUID().uuidString
        )
        let data = try encoder.encode(insert)
        let decoded = try decoder.decode(HoleStatInsert.self, from: data)
        #expect(decoded == insert)
    }

    @Test("Decoder accepts ISO8601 with and without fractional seconds")
    func dateDecoderTolerance() throws {
        struct Box: Decodable { let createdAt: Date }
        let withFractional = Data(#"{"created_at":"2026-04-26T12:00:00.123Z"}"#.utf8)
        let withoutFractional = Data(#"{"created_at":"2026-04-26T12:00:00Z"}"#.utf8)
        let dateOnly = Data(#"{"created_at":"2026-04-26"}"#.utf8)
        _ = try decoder.decode(Box.self, from: withFractional)
        _ = try decoder.decode(Box.self, from: withoutFractional)
        _ = try decoder.decode(Box.self, from: dateOnly)
    }
}
