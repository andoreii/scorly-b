import Foundation

/// Translation between domain types and their stored/UI string forms, for
/// cases where the rawValue isn't a direct match.
public enum Mappings {
    // MARK: - RoundType

    public static func uiLabel(for roundType: RoundType) -> String {
        roundType.rawValue
    }

    public static func roundType(fromUILabel label: String) -> RoundType? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoundType(rawValue: trimmed)
    }

    // MARK: - RoundFormat

    public static func uiLabel(for roundFormat: RoundFormat) -> String {
        roundFormat.rawValue
    }

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

    /// Comma-separated list in `Conditions.labeledFlags` order, e.g. "Sunny,Windy".
    public static func csv(for conditions: Conditions) -> String {
        Conditions.labeledFlags
            .filter { conditions.contains($0.flag) }
            .map(\.label)
            .joined(separator: ",")
    }

    /// Unknown tokens are silently ignored.
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

    // MARK: - Lie (legacy shot-location string)

    /// Translates the legacy free-form shot-location string into `Lie`.
    /// Lossy: "Left"/"Out Left" etc. collapse into a single Lie case.
    public static func lie(fromV1ShotLocation raw: String) -> Lie? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return v1ShotLocationToLie[trimmed]
    }

    /// Inverse mapping for writing hole_stats in the legacy format.
    public static func v1ShotLocation(for lie: Lie?) -> String? {
        guard let lie else { return nil }
        return lieToV1ShotLocation[lie]
    }

    private static let lieToV1ShotLocation: [Lie: String] = [
        .fairway: "Fairway",
        .roughLeft: "Left",
        .roughRight: "Right",
        .recoveryLeft: "Left",
        .recoveryRight: "Right",
        .recoveryShort: "Short",
        .recoveryLong: "Long",
        .bunkerLeft: "Bunker Left",
        .bunkerRight: "Bunker Right",
        .bunkerShort: "Bunker Short",
        .bunkerLong: "Bunker Long",
        .green: "Green",
    ]

    /// "N/A" and the empty string are deliberately absent so lookup returns nil.
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
