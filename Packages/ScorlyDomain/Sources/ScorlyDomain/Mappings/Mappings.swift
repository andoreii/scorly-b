import Foundation

/// Single source of truth for cross-translation between v2 domain types
/// and external string forms:
///
/// - **Stored/UI aliases** that don't match the current domain raw values
///   (e.g. `"Stroke Play"` for `RoundFormat.stroke`).
/// - **Conditions ↔ CSV** for `rounds.conditions`.
/// - **v1 shot-location → v2 `Lie`**: collapses v1's 14-value free-form
///   enum into v2's 12-case `Lie`, dropping the unused `Out *` /
///   non-`Out *` distinction (the v2 design treats both as Recovery).
///
/// Plain enums whose UI labels match their DB rawValue (`HolesPlayed`,
/// `WalkingVsRiding`, `PinPosition`, `RoundType`) don't need entries here
/// — use `init(rawValue:)` directly.
public enum Mappings {
    // MARK: - RoundType

    /// Default UI label for a round type. v2 UIs may override at the call
    /// site; this is the canonical display string.
    public static func uiLabel(for roundType: RoundType) -> String {
        roundType.rawValue
    }

    /// Parses a UI label (or DB-canonical value) into a `RoundType`.
    /// Recognizes the v1 alias `"Competitive"` for `.tournament`.
    public static func roundType(fromUILabel label: String) -> RoundType? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoundType(rawValue: trimmed)
    }

    // MARK: - RoundFormat

    public static func uiLabel(for roundFormat: RoundFormat) -> String {
        roundFormat.rawValue
    }

    /// Parses a UI label or stored database value into a `RoundFormat`.
    public static func roundFormat(fromUILabel label: String) -> RoundFormat? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "Stroke Play":
            return .stroke
        case "Match Play":
            return .match
        default:
            return RoundFormat(rawValue: trimmed)
        }
    }

    // MARK: - Conditions ↔ CSV

    /// Encodes a `Conditions` set as the v1 wire format: a comma-separated
    /// list in `Conditions.labeledFlags` order, e.g. `"Sunny,Windy"`. Empty
    /// sets serialize to an empty string.
    public static func csv(for conditions: Conditions) -> String {
        Conditions.labeledFlags
            .filter { conditions.contains($0.flag) }
            .map(\.label)
            .joined(separator: ",")
    }

    /// Parses a comma-separated conditions string. Whitespace around each
    /// token is trimmed; unknown tokens are silently ignored (forward-
    /// compatible with future flag additions).
    public static func conditions(fromCSV csv: String) -> Conditions {
        var result = Conditions()
        for token in csv.split(separator: ",", omittingEmptySubsequences: false) {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if let flag = conditionLabelToFlag[trimmed] {
                result.insert(flag)
            }
        }
        return result
    }

    private static let conditionLabelToFlag: [String: Conditions] = Dictionary(
        uniqueKeysWithValues: Conditions.labeledFlags.map { ($0.label, $0.flag) }
    )

    // MARK: - Lie (v1 shot-location → v2 Lie)

    /// Translates v1's free-form shot-location string into v2's `Lie`.
    ///
    /// Returns `nil` for v1's `"N/A"` sentinel (used on `approach` for
    /// par-3 holes where there is no separate approach shot) and for any
    /// unrecognized value.
    ///
    /// Lossy: v1 distinguished `"Left"` from `"Out Left"` (and similarly
    /// for Right/Short/Long); v2 collapses both into `.recoveryLeft` etc.
    /// for missed-green positions, and uses `.roughLeft` / `.roughRight`
    /// only for the explicit Left/Right cases (which v1 used to mean a
    /// near-miss into rough).
    public static func lie(fromV1ShotLocation raw: String) -> Lie? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return v1ShotLocationToLie[trimmed]
    }

    /// Inverse of `lie(fromV1ShotLocation:)`. Returns the canonical v1
    /// shot-location string for a `Lie`, or `nil` for "no shot recorded".
    /// Used by the data layer when writing `hole_stats.tee_shot` /
    /// `hole_stats.approach` to keep wire-format compatibility with v1
    /// rounds. The mapping prefers the `Out *` variants for recovery lies
    /// (which is what v1 wrote for tee/approach misses).
    public static func v1ShotLocation(for lie: Lie?) -> String? {
        guard let lie else { return nil }
        return lieToV1ShotLocation[lie]
    }

    private static let lieToV1ShotLocation: [Lie: String] = [
        .fairway: "Fairway",
        .roughLeft: "Left",
        .roughRight: "Right",
        .recoveryLeft: "Out Left",
        .recoveryRight: "Out Right",
        .recoveryShort: "Out Short",
        .recoveryLong: "Out Long",
        .bunkerLeft: "Bunker Left",
        .bunkerRight: "Bunker Right",
        .bunkerShort: "Bunker Short",
        .bunkerLong: "Bunker Long",
        .green: "Green",
    ]

    /// Lookup table — see `lie(fromV1ShotLocation:)` for the rationale
    /// behind the lossy collapsing of `Out *` and bare directional values.
    /// `"N/A"` and the empty string are deliberately absent: `nil` falls
    /// out of the dictionary lookup naturally for "no shot recorded".
    private static let v1ShotLocationToLie: [String: Lie] = [
        "Fairway": .fairway,
        "Left": .roughLeft,
        "Right": .roughRight,
        "Short": .recoveryShort,
        "Long": .recoveryLong,
        "Out Left": .recoveryLeft,
        "Out Right": .recoveryRight,
        "Out Short": .recoveryShort,
        "Out Long": .recoveryLong,
        "Bunker Left": .bunkerLeft,
        "Bunker Right": .bunkerRight,
        "Bunker Short": .bunkerShort,
        "Bunker Long": .bunkerLong,
        "Green": .green,
    ]
}
