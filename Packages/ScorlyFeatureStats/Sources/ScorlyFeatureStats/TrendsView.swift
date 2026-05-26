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
                content(model: model)
                    .padding(.top, BrutalistSpacing.l)
            }

            footerLine
                .padding(.top, BrutalistSpacing.xl)
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
    private func content(model: TrendsModel) -> some View {
        timelineStamp(model: model)
        figuresStrip(model: model)
            .padding(.top, BrutalistSpacing.md)
        distributionSection(model: model)
            .padding(.top, BrutalistSpacing.xl)
        if let sg = model.sg {
            sgSection(rows: sg)
                .padding(.top, BrutalistSpacing.xl)
        }
        accuracyGrid(model: model)
            .padding(.top, BrutalistSpacing.xl)
        penaltySection(model: model)
            .padding(.top, BrutalistSpacing.xl)
        streakSection(model: model)
            .padding(.top, BrutalistSpacing.xl)
    }

    // MARK: - Sections

    /// Inverse "stamp" that owns the headline: AVG vs PAR figure +
    /// delta vs prior window + score-vs-par sparkbar timeline.
    private func timelineStamp(model: TrendsModel) -> some View {
        ZStack {
            CornerMarks(inset: 6, color: BrutalistColor.invFg)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("SCORE vs PAR · \(model.window.label)")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                    Spacer()
                    Text("N=\(model.sampleCount)")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .monospacedDigit()
                }
                Rectangle()
                    .fill(BrutalistColor.invFg)
                    .frame(height: 1)
                    .opacity(0.4)
                    .padding(.vertical, 12)

                HStack(alignment: .firstTextBaseline) {
                    Text(headlineAvgString(model: model))
                        .font(BrutalistType.sans(.bold, size: 64))
                        .kerning(-2.4)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    deltaBadge(model: model)
                }

                ScoreTimelineChart(
                    values: model.timeline.map(\.scoreVsPar),
                    inverse: true
                )
                .padding(.top, BrutalistSpacing.m)

                HStack {
                    Text("OVER ↓")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.invMuted)
                    Spacer()
                    Text("· PAR ·")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.invMuted)
                    Spacer()
                    Text("↑ UNDER")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.invMuted)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(BrutalistColor.invBg)
        .foregroundStyle(BrutalistColor.invFg)
    }

    private func deltaBadge(model: TrendsModel) -> some View {
        // Delta = (current avg vsPar) − (prior window avg vsPar).
        // Negative is *good* (you shot under prior), positive bad.
        let delta: Double? = {
            guard let now = model.avgVsPar, let prev = model.avgVsParPrev else { return nil }
            return now - prev
        }()
        return Group {
            if let delta {
                let sign = delta >= 0 ? "+" : "−"
                let arrow = delta < 0 ? "↓" : (delta > 0 ? "↑" : "·")
                VStack(alignment: .trailing, spacing: 2) {
                    Text("vs PRIOR \(model.window.rawValue)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.invMuted)
                    Text("\(arrow)  \(sign)\(String(format: "%.1f", abs(delta)))")
                        .font(BrutalistType.mono(.semibold, size: 16))
                        .kerning(0.4)
                        .monospacedDigit()
                }
            } else {
                Text("NO PRIOR SAMPLE")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.invMuted)
            }
        }
    }

    private func figuresStrip(model: TrendsModel) -> some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.panel
            CornerMarks(size: 6, inset: 4)
            HStack(spacing: 0) {
                BigStat(
                    label: "Avg Score",
                    value: model.avgScore.map { String(format: "%.1f", $0) } ?? "—"
                )
                BigStat(
                    label: "Best v Par",
                    value: model.bestVsPar.map { vsParString($0) } ?? "—",
                    drawBorder: true
                )
                BigStat(
                    label: "Worst v Par",
                    value: model.worstVsPar.map { vsParString($0) } ?? "—",
                    drawBorder: true
                )
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func distributionSection(model: TrendsModel) -> some View {
        sectioned(
            label: "Score Distribution",
            sub: "\(model.distributionHoles) HOLES COUNTED · BY SCORE v PAR"
        ) {
            if model.distributionHoles == 0 {
                noteRow("Hole-by-hole stats unavailable for this sample.")
            } else {
                DistributionBar(total: model.distributionHoles, counts: model.distribution)
            }
        }
    }

    private func sgSection(rows: [SGBreakdownRow]) -> some View {
        let extremum = max(0.25, rows.map { abs($0.average) }.max() ?? 0.25)
        return sectioned(
            label: "Strokes Gained",
            sub: "PER ROUND AVERAGE · NEGATIVE = LOST, POSITIVE = GAINED"
        ) {
            VStack(alignment: .leading, spacing: BrutalistSpacing.m) {
                ForEach(rows) { row in
                    DivergentBar(
                        label: row.label,
                        value: row.average,
                        extremum: extremum
                    )
                }
            }
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    private func accuracyGrid(model: TrendsModel) -> some View {
        sectioned(
            label: "Accuracy & Touch",
            sub: "ROLLING WINDOW · LINE = MOST RECENT TO PRIOR"
        ) {
            VStack(spacing: -1) {
                HStack(spacing: -1) {
                    accuracyCell(
                        label: "FIR",
                        value: percentString(model.firRate),
                        sub: "FAIRWAYS HIT",
                        series: model.firSeries,
                        showRule: false
                    )
                    accuracyCell(
                        label: "GIR",
                        value: percentString(model.girRate),
                        sub: "GREENS IN REG",
                        series: model.girSeries,
                        showRule: true
                    )
                }
                HStack(spacing: -1) {
                    accuracyCell(
                        label: "Putts / 18",
                        value: model.puttsPerRound
                            .map { String(format: "%.1f", $0) } ?? "—",
                        sub: "AVERAGE",
                        series: model.puttsSeries,
                        showRule: false
                    )
                    accuracyCell(
                        label: "3-Putt %",
                        value: percentString(model.threePuttRate),
                        sub: "PER HOLE",
                        series: model.threePuttSeries,
                        showRule: true
                    )
                }
            }
        }
    }

    private func accuracyCell(
        label: String,
        value: String,
        sub: String,
        series: [Double],
        showRule: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.sans(.bold, size: 30))
                .kerning(-1.0)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Sparkline(series: series)
                .padding(.top, 2)
            Text(sub.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func penaltySection(model: TrendsModel) -> some View {
        let total = model.penalties.reduce(0, +)
        return sectioned(
            label: "Penalty Ledger",
            sub: "ONE CELL PER ROUND · INK DEPTH = STROKES LOST"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(total)")
                        .font(BrutalistType.sans(.bold, size: 30))
                        .kerning(-1.0)
                        .monospacedDigit()
                    Text("STROKES")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    Text("WORST \(model.penaltyMax)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                }
                PenaltyGrid(values: model.penalties, cap: model.penaltyMax)
            }
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    private func streakSection(model: TrendsModel) -> some View {
        sectioned(
            label: "Recent Form",
            sub: "OLDEST  →  LATEST · SQUARE = OVER PAR · RING = UNDER"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                StreakStrip(values: model.streak)
                HStack {
                    Text("\(streakOverCount(model.streak)) OVER")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    Text("\(streakEvenCount(model.streak)) EVEN")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    Text("\(streakUnderCount(model.streak)) UNDER")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    // MARK: - Generic section frame

    private func sectioned<Content: View>(
        label: String,
        sub: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                Spacer()
                Text(sub.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
            }
            HBar(vMargin: 2)
            content()
        }
    }

    private func noteRow(_ text: String) -> some View {
        Text(text)
            .font(BrutalistType.inputBody)
            .foregroundStyle(BrutalistColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
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

    private func headlineAvgString(model: TrendsModel) -> String {
        guard let avg = model.avgVsPar else { return "—" }
        let sign = avg >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(avg)))"
    }

    private func vsParString(_ v: Int) -> String {
        v >= 0 ? "+\(v)" : "\(v)"
    }

    private func percentString(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }

    private func streakOverCount(_ s: [Int]) -> Int {
        s.filter { $0 > 0 }.count
    }

    private func streakEvenCount(_ s: [Int]) -> Int {
        s.filter { $0 == 0 }.count
    }

    private func streakUnderCount(_ s: [Int]) -> Int {
        s.filter { $0 < 0 }.count
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
