import Foundation
import ScorlyDomain

enum PenaltyEventJSONCodec {
    static func encode(_ events: [PenaltyEvent]) -> String? {
        guard !events.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(events) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [PenaltyEvent] {
        guard let json,
              let data = json.data(using: .utf8)
        else { return [] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([PenaltyEvent].self, from: data)) ?? []
    }
}
