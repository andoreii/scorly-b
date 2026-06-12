import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Converts between the sheet's raw `Set<String>` chips and the typed `AggregateRoundFilter`.
struct AggregateFilterEditState: Identifiable, Equatable {
    let id = UUID()
    var holes: Set<String>
    var formats: Set<String>
    var roundTypes: Set<String>
    var teeNames: Set<String>
    var sampleWindow: String?

    init(from filter: AggregateRoundFilter, sampleWindow: String? = nil) {
        holes = Set(filter.holesPlayed.map(HistoryFilterMapping.holesLabel(for:)))
        formats = Set(filter.formats.map { $0.rawValue })
        roundTypes = Set(filter.roundTypes.map { $0.rawValue })
        teeNames = filter.teeNames
        self.sampleWindow = sampleWindow
    }

    func toFilter() -> AggregateRoundFilter {
        AggregateRoundFilter(
            holesPlayed: HistoryFilterMapping.holesSet(from: holes),
            formats: Set(formats.compactMap(RoundFormat.init(rawValue:))),
            roundTypes: Set(roundTypes.compactMap(RoundType.init(rawValue:))),
            teeNames: teeNames
        )
    }
}

/// Static helpers to translate between sheet chip labels and the typed
/// domain enums. Centralised so History and Trends agree on the label set.
enum HistoryFilterMapping {
    static let holeOptions: [String] = ["9", "18"]
    static let formatOptions: [String] = RoundFormat.allCases.map(\.rawValue)
    static let roundTypeOptions: [String] = RoundType.allCases.map(\.rawValue)

    static func holesLabel(for value: HolesPlayed) -> String {
        switch value {
        case .eighteen: "18"
        case .front9, .back9: "9"
        }
    }

    static func holesSet(from labels: Set<String>) -> Set<HolesPlayed> {
        var result: Set<HolesPlayed> = []
        if labels.contains("18") { result.insert(.eighteen) }
        if labels.contains("9") {
            result.insert(.front9)
            result.insert(.back9)
        }
        return result
    }

    /// Count of selections that diverge from `.default`. Used to badge the
    /// FILTER button (e.g. `FILTER · 2`) so the user sees at a glance that
    /// they're looking at a customised view.
    static func deviationCount(from filter: AggregateRoundFilter) -> Int {
        let d = AggregateRoundFilter.default
        var n = 0
        if filter.holesPlayed != d.holesPlayed { n += 1 }
        if filter.formats != d.formats { n += 1 }
        if filter.roundTypes != d.roundTypes { n += 1 }
        if filter.teeNames != d.teeNames { n += 1 }
        return n
    }

    static func groups(
        state: Binding<AggregateFilterEditState?>,
        teeNames: [String]
    ) -> [AggregateFilterSheet.Group] {
        let holesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.holes ?? [] },
            set: { newValue in state.wrappedValue?.holes = newValue }
        )
        let formatsBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.formats ?? [] },
            set: { newValue in state.wrappedValue?.formats = newValue }
        )
        let roundTypesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.roundTypes ?? [] },
            set: { newValue in state.wrappedValue?.roundTypes = newValue }
        )
        let teeNamesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.teeNames ?? [] },
            set: { newValue in state.wrappedValue?.teeNames = newValue }
        )
        var groups: [AggregateFilterSheet.Group] = [
            AggregateFilterSheet.Group(
                id: "holes",
                label: "Holes Played",
                options: holeOptions,
                selection: holesBinding
            ),
            AggregateFilterSheet.Group(
                id: "formats",
                label: "Format",
                options: formatOptions,
                selection: formatsBinding
            ),
            AggregateFilterSheet.Group(
                id: "roundTypes",
                label: "Round Type",
                options: roundTypeOptions,
                selection: roundTypesBinding
            ),
        ]
        if !teeNames.isEmpty {
            groups.append(
                AggregateFilterSheet.Group(
                    id: "tees",
                    label: "Tees",
                    options: teeNames,
                    selection: teeNamesBinding
                )
            )
        }
        return groups
    }
}
