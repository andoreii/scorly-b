import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// In-flight selection state for the Trends filter sheet. Trends extends
/// the History aggregate filter with a single-select sample window.
struct TrendsFilterEditState: Identifiable, Equatable {
    let id = UUID()
    var holes: Set<String>
    var formats: Set<String>
    var roundTypes: Set<String>
    var teeNames: Set<String>
    var window: String

    static let windowOptions: [String] = TrendsWindow.allCases.map(\.label)

    init(filter: AggregateRoundFilter, window: TrendsWindow) {
        holes = Set(filter.holesPlayed.map(HistoryFilterMappingProxy.holesLabel(for:)))
        formats = Set(filter.formats.map { $0.rawValue })
        roundTypes = Set(filter.roundTypes.map { $0.rawValue })
        teeNames = filter.teeNames
        self.window = Self.label(for: window)
    }

    func toFilter() -> AggregateRoundFilter {
        AggregateRoundFilter(
            holesPlayed: HistoryFilterMappingProxy.holesSet(from: holes),
            formats: Set(formats.compactMap(RoundFormat.init(rawValue:))),
            roundTypes: Set(roundTypes.compactMap(RoundType.init(rawValue:))),
            teeNames: teeNames
        )
    }

    static func label(for window: TrendsWindow) -> String {
        window.label
    }

    static func window(for label: String) -> TrendsWindow? {
        TrendsWindow.allCases.first(where: { $0.label == label })
    }
}

/// Local copy of the History filter-mapping rules so Trends doesn't
/// depend on the History feature. Kept in lockstep deliberately — both
/// surfaces present the same chip vocabulary.
enum HistoryFilterMappingProxy {
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
        state: Binding<TrendsFilterEditState?>,
        teeNames: [String]
    ) -> [AggregateFilterSheet.Group] {
        let holesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.holes ?? [] },
            set: { state.wrappedValue?.holes = $0 }
        )
        let formatsBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.formats ?? [] },
            set: { state.wrappedValue?.formats = $0 }
        )
        let roundTypesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.roundTypes ?? [] },
            set: { state.wrappedValue?.roundTypes = $0 }
        )
        let teeNamesBinding = Binding<Set<String>>(
            get: { state.wrappedValue?.teeNames ?? [] },
            set: { state.wrappedValue?.teeNames = $0 }
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
