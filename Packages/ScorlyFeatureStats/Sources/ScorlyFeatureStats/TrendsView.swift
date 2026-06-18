import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Trends dashboard and section drill-ins. Loads completed rounds,
/// applies the current hidden filter/window state, and renders a
/// fixed-height dashboard before letting the player drill into detail.
public struct TrendsView: View {
    let roundsRepository: any RoundsRepository
    let comparisonReference: SGComparisonReference
    let onBack: () -> Void

    @State private var allRounds: [CompletedRound] = []
    @State private var window: TrendsWindow = .twenty
    @State private var filter: AggregateRoundFilter = .default
    @State private var sheetState: TrendsFilterEditState?
    @State private var selectedSection: TrendsSection?
    @State private var didLoad = false
    @State private var isRefreshing = false
    @State private var hasEntered = false
    @State private var dashboardAnimationToken = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let graphDrawDelay = 0.18

    public init(
        roundsRepository: any RoundsRepository,
        comparisonReference: SGComparisonReference = .scratch,
        onBack: @escaping () -> Void
    ) {
        self.roundsRepository = roundsRepository
        self.comparisonReference = comparisonReference
        self.onBack = onBack
    }

    public var body: some View {
        let eligible = allRounds.eligible(for: filter)
        let model = TrendsModel.build(rounds: eligible, window: window)
        let carousel = TrendCarouselAggregates.build(
            eligible: eligible,
            allRounds: allRounds
        )

        Group {
            if let selectedSection {
                sectionScreen(
                    selectedSection,
                    model: model,
                    carousel: carousel,
                    eligible: eligible
                )
            } else {
                dashboard(model: model, eligible: eligible)
            }
        }
        .opacity(hasEntered ? 1 : 0)
        .offset(x: reduceMotion || hasEntered ? 0 : 32)
        .animation(
            Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion),
            value: window
        )
        .animation(
            Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion),
            value: filter
        )
        .animation(
            Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion),
            value: selectedSection
        )
        .task {
            guard !didLoad else { return }
            didLoad = true
            await load()
            playEntrance()
            triggerDashboardAnimation()
        }
        .refreshable { await load() }
        .sheet(item: $sheetState) { _ in
            AggregateFilterSheet(
                groups: HistoryFilterMappingProxy.groups(
                    state: $sheetState,
                    teeNames: availableTeeNames
                ),
                singleSelect: AggregateFilterSheet.SingleSelectGroup(
                    id: "window",
                    label: "Sample Window",
                    options: TrendsFilterEditState.windowOptions,
                    selection: Binding(
                        get: { sheetState?.window ?? TrendsFilterEditState.label(for: window) },
                        set: { newValue in sheetState?.window = newValue }
                    )
                ),
                recordCount: previewRecordCount,
                onApply: applyFromSheet,
                onReset: resetSheet
            )
        }
    }

    // MARK: - Dashboard

    private func dashboard(model: TrendsModel, eligible: [CompletedRound]) -> some View {
        ScreenShell(scrollable: false) {
            navigationRow(label: "← HOME", action: onBack)
            HairlineProgress(isLoading: isRefreshing)
                .padding(.top, BrutalistSpacing.xs)
            pageTitle("Trends")
                .padding(.top, BrutalistSpacing.xs)
            tagline
                .padding(.top, BrutalistSpacing.xs)
            filterRow
                .padding(.top, BrutalistSpacing.m)

            if eligible.isEmpty {
                emptyState
                    .padding(.top, BrutalistSpacing.l)
            } else {
                GeometryReader { proxy in
                    dashboardLayout(
                        width: proxy.size.width,
                        model: model,
                        metrics: TrendsDashboardMetric.sectionCards(from: model),
                        courseCount: distinctCourseCount(in: eligible)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.top, BrutalistSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func dashboardLayout(
        width: CGFloat,
        model: TrendsModel,
        metrics: [TrendsDashboardMetric],
        courseCount: Int
    ) -> some View {
        let scoreCard = ScoreTraceTrendsCard(
            points: scoreTracePoints(from: model),
            courseCount: courseCount,
            mode: .dashboard,
            graphDrawTrigger: dashboardAnimationToken,
            graphDrawDelay: Self.graphDrawDelay
        )

        if width >= 330 {
            VStack(alignment: .leading, spacing: BrutalistSpacing.md) {
                scoreCard
                HStack(spacing: BrutalistSpacing.sm) {
                    ForEach(metrics) { metric in
                        sectionMetricCard(metric)
                    }
                }
            }
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: BrutalistSpacing.sm),
                    GridItem(.flexible(), spacing: BrutalistSpacing.sm),
                ],
                alignment: .leading,
                spacing: BrutalistSpacing.sm
            ) {
                scoreCard
                    .gridCellColumns(2)
                ForEach(metrics) { metric in
                    sectionMetricCard(metric)
                }
            }
        }
    }

    private func sectionMetricCard(_ metric: TrendsDashboardMetric) -> some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 6, inset: 5)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric.title)
                        .font(BrutalistType.monoLabel)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 6)
                    Text("OPEN")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.dim)
                }
                Spacer(minLength: BrutalistSpacing.s)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    AnimatedNumericText(
                        value: metric.value,
                        trigger: dashboardAnimationToken,
                        delay: Self.graphDrawDelay
                    )
                    .font(BrutalistType.sans(.bold, size: 38))
                    .kerning(-1.4)
                    .foregroundStyle(BrutalistColor.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .font(BrutalistType.mono(.semibold, size: 15))
                            .foregroundStyle(BrutalistColor.muted)
                    }
                    if let trend = metric.trend {
                        TrendDirectionChevron(pointsUp: trend.pointsUp)
                            .stroke(
                                trend.isImproving ? BrutalistColor.sgPos : BrutalistColor.sgNeg,
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 19, height: 19)
                            .padding(.leading, 2)
                            .accessibilityHidden(true)
                    }
                }
                Text(metric.detail)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.7)
                    .foregroundStyle(BrutalistColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.top, BrutalistSpacing.xs)
            }
            .padding(BrutalistSpacing.md)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .brutalistTap {
            Haptics.light()
            selectedSection = TrendsSection(metric.kind)
        }
        .accessibilityLabel(metric.detail)
    }

    // MARK: - Section pages

    private func sectionScreen(
        _ section: TrendsSection,
        model: TrendsModel,
        carousel: TrendCarouselAggregates,
        eligible: [CompletedRound]
    ) -> some View {
        ScreenShell {
            navigationRow(label: "← TRENDS") {
                selectedSection = nil
            }
            HairlineProgress(isLoading: isRefreshing)
                .padding(.top, BrutalistSpacing.xs)
            pageTitle(section.title)
                .padding(.top, BrutalistSpacing.xs)

            if eligible.isEmpty {
                emptyState
                    .padding(.top, BrutalistSpacing.l)
            } else {
                sectionContent(
                    section,
                    model: model,
                    carousel: carousel,
                    eligible: eligible
                )
                .padding(.top, BrutalistSpacing.l)
            }
        }
    }

    @ViewBuilder
    private func sectionContent(
        _ section: TrendsSection,
        model: TrendsModel,
        carousel: TrendCarouselAggregates,
        eligible: [CompletedRound]
    ) -> some View {
        let courseCount = distinctCourseCount(in: eligible)
        switch section {
        case .fairways:
            AccuracyCard(
                kind: .fairway,
                data: carousel.fairwayRose,
                series: model.firSeries,
                dates: model.accuracyDates,
                courseCount: courseCount
            )
        case .greens:
            AccuracyCard(
                kind: .green,
                data: carousel.greenRose,
                series: model.girSeries,
                dates: model.accuracyDates,
                courseCount: courseCount
            )
        case .putting:
            PuttsTouchCard(
                avgPuttsPerRound: model.puttsPerRound,
                onePuttRate: model.onePuttRate,
                threePuttRate: model.threePuttRate,
                puttsSeries: model.puttsSeries,
                threePuttSeries: model.threePuttSeries
            )
            MakePctByDistanceCard(stats: carousel.makePctByDistance)
                .padding(.top, BrutalistSpacing.l)
        }
    }

    // MARK: - Filter wiring

    private var availableTeeNames: [String] {
        Array(Set(allRounds.compactMap(\.teeName))).sorted()
    }

    private var previewRecordCount: Int {
        guard let sheetState else { return allRounds.eligible(for: filter).count }
        return allRounds.eligible(for: sheetState.toFilter()).count
    }

    private func applyFromSheet() {
        guard let sheetState else { return }
        filter = sheetState.toFilter()
        if let chosen = TrendsFilterEditState.window(for: sheetState.window) {
            window = chosen
        }
        self.sheetState = nil
        triggerDashboardAnimation()
    }

    private func resetSheet() {
        sheetState = TrendsFilterEditState(filter: .default, window: .twenty)
    }

    // MARK: - Shared view pieces

    private var tagline: some View {
        Text("ROLLING WINDOWS · NO STORYTELLING")
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
    }

    private var filterRow: some View {
        HStack(spacing: BrutalistSpacing.xs) {
            Text(filterButtonLabel)
                .font(BrutalistType.monoCaption)
                .kerning(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistSpacing.sm)
                .background(filterIsDefault ? .clear : BrutalistColor.fg)
                .foregroundStyle(filterIsDefault ? BrutalistColor.fg : BrutalistColor.bg)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .brutalistTap {
                    Haptics.light()
                    sheetState = TrendsFilterEditState(filter: filter, window: window)
                }
        }
    }

    private var filterButtonLabel: String {
        let deviations = HistoryFilterMappingProxy.deviationCount(from: filter)
        return deviations == 0 ? "FILTER" : "FILTER · \(deviations)"
    }

    private var filterIsDefault: Bool {
        filter == .default
    }

    private func navigationRow(label: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: action)
            Spacer()
            Text("SCORLY/B  ®")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private func pageTitle(_ title: String) -> some View {
        Text(title)
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .foregroundStyle(BrutalistColor.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            Text("NO ROUNDS YET")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Text("File a few scorecards from the round flow. Trends activates after the first signed card.")
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    // MARK: - Helpers

    private func scoreTracePoints(from model: TrendsModel) -> [ScoreTracePoint] {
        model.timeline.map { point in
            ScoreTracePoint(
                date: point.date,
                score: point.totalScore,
                par: point.totalScore - point.scoreVsPar
            )
        }
    }

    private func distinctCourseCount(in rounds: [CompletedRound]) -> Int {
        let names = rounds.compactMap { $0.courseName }
        if !names.isEmpty {
            return Set(names).count
        }
        return rounds.count
    }

    @MainActor
    private func load() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let fetched = try? await roundsRepository.fetchAllCompleted() {
            if hasEntered {
                withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                    allRounds = fetched
                }
            } else {
                allRounds = fetched
            }
        }
    }

    private func playEntrance() {
        guard !hasEntered else { return }
        withAnimation(Motion.adaptive(Motion.easeOutQuart(0.32), reduceMotion: reduceMotion)) {
            hasEntered = true
        }
    }

    private func triggerDashboardAnimation() {
        dashboardAnimationToken += 1
    }
}

private enum TrendsSection: Hashable {
    case fairways
    case greens
    case putting

    init(_ kind: TrendsDashboardMetric.Kind) {
        switch kind {
        case .fairways:
            self = .fairways
        case .greens:
            self = .greens
        case .putting:
            self = .putting
        }
    }

    var title: String {
        switch self {
        case .fairways:
            "Fairways Accuracy"
        case .greens:
            "Greens Accuracy"
        case .putting:
            "Putting"
        }
    }
}
