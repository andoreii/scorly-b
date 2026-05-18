import Foundation
import Supabase

/// Configuration + JSON coders for the Supabase client.
///
/// Plan C1 calls for porting v1's `SupabaseClient.swift` verbatim. v1's
/// implementation is a one-line global `let supabase = SupabaseClient(...)`
/// configured with snake-case JSON coders + an ISO8601 fractional-seconds
/// date strategy. v2 keeps the configuration here as portable values so the
/// SDK boundary itself can be wired in Phase D (where `AuthService` first
/// needs the live client) without dragging the SPM dep into Phase C's CI.
///
/// **Live wiring** (planned for Phase D):
/// ```swift
/// import Supabase
/// public let supabase = SupabaseClient(
///     supabaseURL: SupabaseConfig.url,
///     supabaseKey: SupabaseConfig.publishableKey,
///     options: .init(db: .init(
///         encoder: SupabaseConfig.encoder,
///         decoder: SupabaseConfig.decoder
///     ))
/// )
/// ```
public enum SupabaseConfig {
    /// Read from `Info.plist` key `SCORLY_SUPABASE_URL`, populated at build
    /// time from `Local.xcconfig` via `project.yml`. Falls back to a
    /// placeholder host that satisfies sanity-check tests when running
    /// `swift test` outside the app bundle.
    public static let url: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SCORLY_SUPABASE_URL") as? String) ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "https://placeholder.supabase.co"
        if value.isEmpty {
            return URL(string: fallback) ?? URL(fileURLWithPath: "/")
        }
        return URL(string: value) ?? URL(string: fallback) ?? URL(fileURLWithPath: "/")
    }()

    /// Publishable (anon) key. Safe to embed in the binary; RLS does the
    /// real authorization work. Read from `Info.plist` key
    /// `SCORLY_SUPABASE_ANON_KEY`. Falls back to a placeholder with the
    /// expected `sb_publishable_` prefix for SPM test runs.
    public static let publishableKey: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SCORLY_SUPABASE_ANON_KEY") as? String) ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "sb_publishable_placeholder" : value
    }()

    /// Snake-case JSON encoder. v1's wire format uses `course_id`,
    /// `date_played`, etc.; v2 Codables keep camelCase property names and
    /// rely on `.convertToSnakeCase` to bridge. ISO8601 with fractional
    /// seconds for timestamps so `created_at` and friends round-trip
    /// exactly.
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601WithFractionalSeconds
        return encoder
    }

    /// Snake-case JSON decoder. Mirrors `encoder` so the same Codable
    /// types serialize and parse symmetrically. Tolerates ISO8601 with or
    /// without fractional seconds because Supabase emits both depending
    /// on the column type.
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
    /// ISO8601 with fractional seconds, matching what Postgres `TIMESTAMPTZ`
    /// emits when serialised by Supabase's PostgREST layer.
    static var iso8601WithFractionalSeconds: Self {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SupabaseConfig.fractionalISOFormatter.string(from: date))
        }
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    /// Accepts ISO8601 with or without fractional seconds. v1 wrote
    /// fractional, but historical rows + some Supabase responses lack them.
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
