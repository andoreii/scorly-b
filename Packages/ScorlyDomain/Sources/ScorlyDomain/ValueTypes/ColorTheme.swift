import Foundation

/// Course color theme, persisted as a single string in `courses.color_theme`.
/// Encoded as either a preset name, `CustomSolid:RRGGBB`, or
/// `CustomGradient:RRGGBB-RRGGBB`. Hex codes normalize to uppercase RRGGBB.
public enum ColorTheme: Hashable, Sendable {
    case preset(name: String)
    case customSolid(hex: String)
    case customGradient(start: String, end: String)

    /// Parses the v1 wire format. Returns `nil` for empty or malformed input.
    public init?(encoded: String) {
        let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let payload = Self.stripPrefix(Self.gradientPrefix, from: trimmed) {
            let parts = payload.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let start = Self.normalizedHex(String(parts[0])),
                  let end = Self.normalizedHex(String(parts[1]))
            else { return nil }
            self = .customGradient(start: start, end: end)
            return
        }

        if let payload = Self.stripPrefix(Self.solidPrefix, from: trimmed) {
            guard let hex = Self.normalizedHex(payload) else { return nil }
            self = .customSolid(hex: hex)
            return
        }

        self = .preset(name: trimmed)
    }

    /// Wire-format string written to the DB.
    public var encoded: String {
        switch self {
        case let .preset(name): name
        case let .customSolid(hex): "\(Self.solidPrefix)\(hex)"
        case let .customGradient(start, end): "\(Self.gradientPrefix)\(start)-\(end)"
        }
    }

    // MARK: - Internals

    private static let solidPrefix = "CustomSolid:"
    private static let gradientPrefix = "CustomGradient:"

    private static func stripPrefix(_ prefix: String, from string: String) -> String? {
        guard string.hasPrefix(prefix) else { return nil }
        return String(string.dropFirst(prefix.count))
    }

    /// Validates a hex code string and normalizes to uppercase 6-char RRGGBB.
    /// Accepts an optional leading `#`.
    private static func normalizedHex(_ raw: String) -> String? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6 else { return nil }
        let hexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard trimmed.unicodeScalars.allSatisfy(hexChars.contains) else { return nil }
        return trimmed.uppercased()
    }
}

// MARK: - Codable

extension ColorTheme: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = ColorTheme(encoded: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid color theme encoding: \"\(raw)\""
            )
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encoded)
    }
}
