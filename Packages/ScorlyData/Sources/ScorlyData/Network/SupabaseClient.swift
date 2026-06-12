import Foundation
import Supabase

/// Configuration + JSON coders for the Supabase client.
public enum SupabaseConfig {
    /// Read from `Info.plist` key `SCORLY_SUPABASE_URL` (set via `Local.xcconfig`).
    /// Falls back to a placeholder host for `swift test` outside the app bundle.
    public static let url: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SCORLY_SUPABASE_URL") as? String) ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "https://placeholder.supabase.co"
        if value.isEmpty {
            return URL(string: fallback) ?? URL(fileURLWithPath: "/")
        }
        return URL(string: value) ?? URL(string: fallback) ?? URL(fileURLWithPath: "/")
    }()

    /// Anon key, safe to embed since RLS handles authorization. Falls back to a placeholder for SPM test runs.
    public static let publishableKey: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SCORLY_SUPABASE_ANON_KEY") as? String) ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "sb_publishable_placeholder" : value
    }()

    /// Bridges camelCase Codables to snake-case columns; ISO8601 with fractional seconds for timestamps.
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601WithFractionalSeconds
        return encoder
    }

    /// Mirrors `encoder`; tolerates ISO8601 with or without fractional seconds since Supabase emits both.
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601Tolerant
        return decoder
    }
}

public enum SupabaseClientFactory {
    public static func make() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey,
            options: .init(
                db: .init(
                    encoder: SupabaseConfig.encoder,
                    decoder: SupabaseConfig.decoder
                ),
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}

// MARK: - Date strategy helpers

private extension JSONEncoder.DateEncodingStrategy {
    /// Matches Postgres `TIMESTAMPTZ` as serialized by Supabase's PostgREST layer.
    static var iso8601WithFractionalSeconds: Self {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SupabaseConfig.fractionalISOFormatter.string(from: date))
        }
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    /// Accepts ISO8601 with or without fractional seconds; some Supabase responses lack them.
    static var iso8601Tolerant: Self {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = SupabaseConfig.fractionalISOFormatter.date(from: raw) {
                return date
            }
            if let date = SupabaseConfig.plainISOFormatter.date(from: raw) {
                return date
            }
            // Date-only `yyyy-MM-dd` (used for `date_played`).
            if let date = SupabaseConfig.dateOnlyFormatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
    }
}

extension SupabaseConfig {
    nonisolated(unsafe) static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let plainISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
