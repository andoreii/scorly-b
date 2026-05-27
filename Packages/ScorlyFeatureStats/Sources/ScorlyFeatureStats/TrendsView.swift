import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Trends — the brutalist statistical instrument. Loads completed
/// rounds from the repository, lets the player pick a sample window
/// (10 or 20), composes a ledger of charts on top of the resulting
/// `TrendsModel`. Read-only.
public struct TrendsView: View {
    let roundsRepository: any RoundsRepository
    let onBack: () -> Void

    @State private var allRounds: [CompletedRound] = []
    @State private var window: TrendsWindow = .twenty
    @State private var filter: AggregateRoundFilter = .default
    @State private var sheetState: TrendsFilterEditState?
    @State private var didLoad = false
    @State private var isRefreshing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        roundsRepository: any RoundsRepository,
        onBack: @escaping () -> Void
    ) {
        self.roundsRepository = roundsRepository
        self.onBack = onBack
    }

    public var body: some View {
        // Eligibility runs before the window so LAST 10 / LAST 20 always
        // samples from the filtered subset, not the raw archive.
        let eligible = allRounds.eligible(for: filter)
        let model = TrendsModel.build(rounds: eligible, window: window)
        // Last-20 heat grid always samples the raw archive — staying
        // filter-stable is the whole point of the grid.
        let carouselAggregates = TrendCarouselAggregates.build(
            eligible: eligible,
            allRounds: allRounds
        )
        ScreenShell {
            TopBar(left: "TREND ANALYSIS", right: "SCORLY/B  ®")
            HairlineProgress(isLoading: isRefreshing)
                .padding(.top, BrutalistSpacing.s)
            backRow(model: model, eligibleCount: eligible.count)
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            tagline
            filterRow
                .padding(.top, BrutalistSpacing.l)

            if eligible.isEmpty {
                emptyState
                    .padding(.top, BrutalistSpacing.l)
            } else {
                content(model: model, carousel: carouselAggregates, eligible: eligible)
                    .padding(.top, BrutalistSpacing.l)
            }

            footerLine
                .padding(.top, BrutalistSpacing.l)
                .padding(.bottom, BrutalistSpacing.xl)
        }
        .animation(
            Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion),
            value: window
        )
        .animation(
            Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion),
            value: filter
        )
        .task {
            guard !didLoad else { return }
            didLoad = true
            await load()
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

    // MARK: - Composition

    private func backRow(model: TrendsModel, eligibleCount: Int) -> some View {
        HStack {
            Text("← HOME")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onBack)
            Spacer()
            Text(sampleSubtitle(model: model, eligibleCount: eligibleCount))
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var hero: some View {
        Text("Read\nthe game.")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .lineSpacing(-4)
            .foregroundStyle(BrutalistColor.fg)
            .padding(.bottom, BrutalistSpacing.xs)
    }

    private var tagline: some View {
        Text("ROLLING WINDOWS · NO STORYTELLING")
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
    }

    private var filterRow: some View {
        HStack(spacing: 6) {
            Text(filterButtonLabel)
                .font(BrutalistType.monoCaption)
                .kerning(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(filterIsDefault ? .clear : BrutalistColor.fg)
                .foregroundStyle(filterIsDefault ? BrutalistColor.fg : BrutalistColor.bg)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .brutalistTap {
                    Haptics.light()
                    sheetState = TrendsFilterEditState(filter: filter, window: window)
                }
            Text(window.label)
                .font(BrutalistType.monoCaption)
                .kerning(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(BrutalistColor.panel)
                .foregroundStyle(BrutalistColor.muted)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    private var filterButtonLabel: String {
        let deviations = HistoryFilterMappingProxy.deviationCount(from: filter)
        return deviations == 0 ? "FILTER" : "FILTER · \(deviations)"
    }

    private var filterIsDefault: Bool {
        filter == .default
    }

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
    }

    private func resetSheet() {
        sheetState = TrendsFilterEditState(filter: .default, window: .twenty)
    }

    @ViewBuilder
    private func content(
        model: TrendsModel,
        carousel: TrendCarouselAggregates,
        eligible: [CompletedRound]
    ) -> some View {
        ScoreSummaryHeader(
            avgScore: model.avgScore,
            bestVsPar: model.bestVsPar,
            worstVsPar: model.worstVsPar,
            scorePoints: model.timeline.map { ScoreLinePoint(date: $0.date, score: $0.totalScore) }
        )

        // Each carousel sets its own minHeight so the page lays out
        // sensibly before the slide measurement preference arrives.
        // Heights are *minimums* — the PreferenceKey in TrendCarousel
        // grows the frame to fit a taller slide if needed.
        TrendCarousel(
            title: "OVERALL GAME",
            slides: overallGameSlides(model: model, eligible: eligible),
            minHeight: 570
        ) { slide in
            slide.view
        }
        .padding(.top, BrutalistSpacing.l)

        TrendCarousel(
            title: "ACCURACY",
            slides: accuracySlides(model: model, carousel: carousel),
            minHeight: 460
        ) { slide in
            slide.view
        }
        .padding(.top, BrutalistSpacing.l)

        TrendCarousel(
            title: "TOUCH",
            slides: touchSlides(model: model, carousel: carousel),
            minHeight: 440
        ) { slide in
            slide.view
        }
        .padding(.top, BrutalistSpacing.l)

        TrendCarousel(
            title: "SCORING",
            slides: scoringSlides(carousel: carousel),
            minHeight: 420
        ) { slide in
            slide.view
        }
        .padding(.top, BrutalistSpacing.l)
    }

    // MARK: - Carousel slide assembly

    /// Lightweight identifiable wrapper. Each carousel slide is built
    /// once per render; the stable integer id keeps the diff identity
    /// even though the AnyView inside changes between renders. Equatable
    /// + Hashable conformance compares ids only — the AnyView payload
    /// is intentionally excluded so SwiftUI's scroll-position binding
    /// has a stable identity across rerenders.
    struct CarouselSlide: Identifiable, Hashable {
        let id: Int
        let view: AnyView

        static func == (lhs: CarouselSlide, rhs: CarouselSlide) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private func overallGameSlides(
        model: TrendsModel,
        eligible: [CompletedRound]
    ) -> [CarouselSlide] {
        [
            .init(id: 0, view: AnyView(SkillsRadarCard(axes: model.radarAxes))),
            .init(id: 1, view: AnyView(MultiRoundSGCard(rounds: eligible))),
        ]
    }

    private func accuracySlides(
        model: TrendsModel,
        carousel: TrendCarouselAggregates
    ) -> [CarouselSlide] {
        [
            .init(
                id: 0,
                view: AnyView(
                    AccuracyCard(
                        kind: .fairway,
                        data: carousel.fairwayRose,
                        series: model.firSeries
                    )
                )
            ),
            .init(
                id: 1,
                view: AnyView(
                    AccuracyCard(
                        kind: .green,
                        data: carousel.greenRose,
                        series: model.girSeries
                    )
                )
            ),
        ]
    }

    private func touchSlides(
        model: TrendsModel,
        carousel: TrendCarouselAggregates
    ) -> [CarouselSlide] {
        [
            .init(
                id: 0,
                view: AnyView(
                    PuttsTouchCard(
                        avgPuttsPerRound: model.puttsPerRound,
                        onePuttRate: model.onePuttRate,
                        threePuttRate: model.threePuttRate,
                        puttsSeries: model.puttsSeries,
                        threePuttSeries: model.threePuttSeries
                    )
                )
            ),
            .init(
                id: 1,
                view: AnyView(
                    MakePctByDistanceCard(stats: carousel.makePctByDistance)
                )
            ),
        ]
    }

    private func scoringSlides(carousel: TrendCarouselAggregates) -> [CarouselSlide] {
        [
            .init(
                id: 0,
                view: AnyView(
                    HoleOutcomeDistribution(
                        counts: carousel.outcomes,
                        total: carousel.outcomesTotal
                    )
                )
            ),
            .init(
                id: 1,
                view: AnyView(
                    HoleHeatGrid(rows: carousel.holeHeatLast20)
                )
            ),
        ]
    }

    // MARK: - Empty + footer

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

    private var footerLine: some View {
        HStack {
            Text("END OF ANALYSIS")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
            Spacer()
            Text("SCORLY/B · 2026")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
        }
    }

    // MARK: - Helpers

    private func sampleSubtitle(model: TrendsModel, eligibleCount: Int) -> String {
        guard let span = model.dateSpan, model.sampleCount > 0 else {
            return "\(eligibleCount) ROUNDS ELIGIBLE"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yy"
        let start = formatter.string(from: span.lowerBound).uppercased()
        let end = formatter.string(from: span.upperBound).uppercased()
        return "N=\(model.sampleCount) · \(start) → \(end)"
    }

    @MainActor
    private func load() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let fetched = try? await roundsRepository.fetchAllCompleted() {
            withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                allRounds = fetched
            }
        }
    }
}
