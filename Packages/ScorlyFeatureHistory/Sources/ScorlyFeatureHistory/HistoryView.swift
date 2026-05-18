import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Round archive. Loads `[CompletedRound]` from the repository,
/// renders top stats strip + filter chips + ticket-style row list,
/// with an inverse `LATEST` stamp pinned to the newest entry.
public struct HistoryView: View {
    let roundsRepository: any RoundsRepository
    let onBack: () -> Void

    @State private var rounds: [CompletedRound] = []
    @State private var filter: Filter = .all
    @State private var didLoad = false
    @State private var isRefreshing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum Filter: String, CaseIterable, Identifiable {
        case all = "ALL ROUNDS"
        case eighteen = "18 HOLES"
        case nine = "9 HOLES"
        public var id: String { rawValue }
    }

    public init(roundsRepository: any RoundsRepository, onBack: @escaping () -> Void) {
        self.roundsRepository = roundsRepository
        self.onBack = onBack
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "ROUND ARCHIVE", right: "SCORLY/B  ®")
            backRow
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            mono("INDEXED · SEARCHABLE · YOURS", color: BrutalistColor.muted)
            statsStrip
                .padding(.top, BrutalistSpacing.l)
            filterChips
                .padding(.top, BrutalistSpacing.m)
            roundList
                .padding(.top, BrutalistSpacing.m)
            footerLine
                .padding(.top, BrutalistSpacing.xl)
                .padding(.bottom, BrutalistSpacing.xl)
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await load()
        }
        .refreshable { await load() }
    }

    // MARK: - Sub-views

    private var backRow: some View {
        HStack {
            Button(action: onBack) {
                Text("← HOME")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(filtered.count) RECORDS")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var hero: some View {
        Text("Every\nscorecard.")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .lineSpacing(-4)
            .foregroundStyle(BrutalistColor.fg)
            .padding(.bottom, BrutalistSpacing.xs)
    }

    private var statsStrip: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.panel
            CornerMarks(size: 6, inset: 4)
            HStack(spacing: 0) {
                BigStat(label: "Rounds", value: "\(rounds.count)")
                BigStat(label: "Best v Par", value: bestVsPar, drawBorder: true)
                BigStat(label: "Avg Score", value: avgScore, drawBorder: true)
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var filterChips: some View {
        HStack(spacing: 6) {
            ForEach(Filter.allCases) { f in
                let active = filter == f
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        filter = f
                    }
                } label: {
                    Text(f.rawValue)
                        .font(BrutalistType.monoCaption)
                        .kerning(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active ? BrutalistColor.fg : .clear)
                        .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var roundList: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, round in
                    ticketRow(round: round, isLatest: idx == 0)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            Text("NO ROUNDS YET")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Text("File your first scorecard from the round flow. It'll appear here.")
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func ticketRow(round: CompletedRound, isLatest: Bool) -> some View {
        let diff = round.scoreVsPar
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(dateString(round.datePlayed))
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                    Spacer()
                    Text("REF \(refString(round.id))")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.muted)
                }
                HBar(vMargin: 10)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.courseName ?? "—")
                            .font(BrutalistType.sans(.bold, size: 18))
                            .kerning(-0.4)
                        Text(subline(round))
                            .font(BrutalistType.monoMicro)
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(round.totalScore)")
                            .font(BrutalistType.sans(.bold, size: 40))
                            .kerning(-1.4)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("\(diff >= 0 ? "+" : "")\(diff) · PAR \(round.par)")
                            .font(BrutalistType.monoMicro)
                            .kerning(0.6)
                    }
                }
                HBar(vMargin: 10)
                HStack(spacing: 4) {
                    MiniStat(label: "Putts", value: "\(round.totalPutts)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MiniStat(label: "FIR", value: firString(round))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MiniStat(label: "GIR", value: girString(round))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MiniStat(label: "ID", value: idTail(round.id), useMono: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(isLatest ? BrutalistColor.panel : Color.clear)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))

            if isLatest {
                Text("LATEST")
                    .font(BrutalistType.mono(.semibold, size: 9))
                    .kerning(1.0)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(BrutalistColor.fg)
                    .foregroundStyle(BrutalistColor.bg)
            }
        }
    }

    private var footerLine: some View {
        HStack {
            Text("END OF RECORD")
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

    private func mono(_ text: String, color: Color) -> some View {
        Text(text)
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(color)
    }

    // MARK: - Derived

    private var filtered: [CompletedRound] {
        switch filter {
        case .all: return rounds
        case .eighteen: return rounds.filter { $0.holesPlayed == .eighteen }
        case .nine: return rounds.filter { $0.holesPlayed == .front9 || $0.holesPlayed == .back9 }
        }
    }

    private var bestVsPar: String {
        guard !rounds.isEmpty else { return "—" }
        let best = rounds.map(\.scoreVsPar).min() ?? 0
        return best >= 0 ? "+\(best)" : "\(best)"
    }

    private var avgScore: String {
        guard !rounds.isEmpty else { return "—" }
        let avg = Double(rounds.reduce(0) { $0 + $1.totalScore }) / Double(rounds.count)
        return String(format: "%.1f", avg)
    }

    // MARK: - Formatters

    private func dateString(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yy"
        return fmt.string(from: d).uppercased()
    }

    private func refString(_ id: UUID) -> String {
        "PRG-\(idTail(id))"
    }

    private func idTail(_ id: UUID) -> String {
        let raw = id.uuidString.replacingOccurrences(of: "-", with: "")
        return String(raw.suffix(4)).uppercased()
    }

    private func subline(_ round: CompletedRound) -> String {
        var parts: [String] = []
        if let tee = round.teeName { parts.append("\(tee.uppercased()) TEES") }
        parts.append("\(holesCount(round)) HOLES")
        if let weather = weatherLabel(round.conditions) { parts.append(weather.uppercased()) }
        return parts.joined(separator: " — ")
    }

    private func holesCount(_ round: CompletedRound) -> Int {
        switch round.holesPlayed {
        case .eighteen: return 18
        case .front9, .back9: return 9
        }
    }

    private func weatherLabel(_ conditions: Conditions) -> String? {
        Conditions.labeledFlags
            .first(where: { conditions.contains($0.flag) })?
            .label
    }

    private func firString(_ round: CompletedRound) -> String {
        round.firOpportunities > 0 ? "\(round.firCount)/\(round.firOpportunities)" : "—"
    }

    private func girString(_ round: CompletedRound) -> String {
        "\(round.girCount)/\(holesCount(round))"
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let fetched = try? await roundsRepository.fetchAllCompleted() {
            withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                rounds = fetched.sorted { $0.datePlayed > $1.datePlayed }
            }
        }
    }
}
