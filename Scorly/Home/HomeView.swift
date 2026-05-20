import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Brutalist home screen. Wordmark, handicap + rounds twin cards,
/// last-round inverse stamp, "Start new round" CTA, ghost buttons for
/// History, Trends, and Settings.
///
/// Data flows in via `rounds` + `handicap` — owned by `RootView` so it
/// survives navigation. Without parent-owned state the "Last Round"
/// stamp would pop in mid-slide whenever an async refetch resolved
/// after a remount, instead of sliding in as part of the screen.
struct HomeView: View {
    let flow: AppFlow
    let rounds: [CompletedRound]
    let handicap: Decimal?
    let onSignOut: () -> Void

    @State private var now = Date()

    private var lastRound: CompletedRound? { rounds.first }
    private var roundCount: Int { rounds.count }

    private var averageScore: Double? {
        guard !rounds.isEmpty else { return nil }
        let total = rounds.reduce(0) { $0 + $1.totalScore }
        return Double(total) / Double(rounds.count)
    }

    var body: some View {
        ScreenShell(scrollable: false) {
            TopBar(left: dayTimeLabel(), right: "SCORLY/B  ®")
            HairlineProgress(isLoading: false)
                .padding(.top, BrutalistSpacing.s)

            wordmark
                .padding(.top, BrutalistSpacing.xl)

            HBar(vMargin: BrutalistSpacing.xl)

            HStack(spacing: 10) {
                handicapCard
                roundsCard
            }

            if let lastRound {
                lastRoundStamp(lastRound)
                    .padding(.top, BrutalistSpacing.md)
            }

            primaryCta
                .padding(.top, BrutalistSpacing.md)

            HStack(spacing: 8) {
                navTile(label: "↗  HISTORY") { flow.go(.history) }
                navTile(label: "↗  TRENDS") { flow.go(.stats) }
                navTile(label: "↗  COURSES") { flow.go(.courses) }
            }
            .padding(.top, BrutalistSpacing.s)

            Spacer(minLength: BrutalistSpacing.l)

            footer
        }
    }

    private var wordmark: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL /B · SCORECARD OS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.4)
                    .foregroundStyle(BrutalistColor.muted)
                // Explicit two-line composition. Text concatenation with
                // an embedded "\n" plus negative kerning miscalculates
                // its intrinsic width and triggers single-line
                // truncation on tighter device widths.
                VStack(alignment: .leading, spacing: -12) {
                    Text("SCOR")
                        .font(BrutalistType.wordmark)
                        .kerning(-3)
                        .foregroundStyle(BrutalistColor.fg)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("LY")
                            .font(BrutalistType.wordmark)
                            .kerning(-3)
                        Text("/B")
                            .font(BrutalistType.sans(.regular, size: 76))
                    }
                    .foregroundStyle(BrutalistColor.fg)
                }
                .fixedSize(horizontal: true, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text("NO.").font(BrutalistType.monoMicro).foregroundStyle(BrutalistColor.muted)
                Text("001")
                    .font(BrutalistType.mono(.semibold, size: 22))
                    .monospacedDigit()
            }
            .padding(.bottom, 6)
        }
    }

    private var handicapCard: some View {
        StampCard(
            label: "Handicap Idx",
            value: handicap.map { Self.handicapFormatter.string(from: $0 as NSDecimalNumber) ?? "—" } ?? "—",
            sub: handicap == nil ? "AWAITING ROUNDS" : "LAST 20 ROUNDS"
        )
    }

    private var roundsCard: some View {
        let avg = averageScore.map { String(format: "AVG %.1f", $0) } ?? "AVG —"
        return StampCard(
            label: "Rounds · \(yearLabel())",
            value: "\(roundCount)",
            sub: avg
        )
    }

    private func lastRoundStamp(_ round: CompletedRound) -> some View {
        let diff = round.scoreVsPar
        return ZStack {
            CornerMarks(inset: 6, color: BrutalistColor.invFg)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("LAST ROUND · \(Self.shortDate(round.datePlayed))")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                    Spacer()
                    Text("REF \(referenceCode(for: round))")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                }
                Rectangle().fill(BrutalistColor.invFg).frame(height: 1).opacity(0.4).padding(.vertical, 12)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.courseName ?? "—")
                            .font(BrutalistType.body)
                        Text(courseSubtitle(for: round))
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.invMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(round.totalScore)")
                            .font(BrutalistType.heroSecondary)
                            .kerning(-1.8)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("\(diff >= 0 ? "+" : "")\(diff) · PAR \(round.par)")
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                    }
                }
                Rectangle().fill(BrutalistColor.invFg).frame(height: 1).opacity(0.4).padding(.vertical, 12)
                HStack(spacing: 0) {
                    Stat(label: "Putts", value: "\(round.totalPutts)", mutedColor: BrutalistColor.invMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Stat(
                        label: "FIR",
                        value: round.firOpportunities > 0 ? "\(round.firCount)/\(round.firOpportunities)" : "—",
                        mutedColor: BrutalistColor.invMuted
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Stat(
                        label: "GIR",
                        value: "\(round.girCount)/\(round.holesPlayed.holeCount)",
                        mutedColor: BrutalistColor.invMuted
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(BrutalistColor.invBg)
        .foregroundStyle(BrutalistColor.invFg)
    }

    private var primaryCta: some View {
        BrutalistButton(
            kind: .fg,
            action: { flow.go(.setup) },
            padding: EdgeInsets(top: 22, leading: 18, bottom: 22, trailing: 18)
        ) {
            Text("Start new round")
                .font(BrutalistType.sans(.bold, size: 19))
                .kerning(-0.4)
        } caption: {
            Text("→ TEE OFF")
                .font(BrutalistType.monoCaption)
                .kerning(1.2)
        }
    }

    private func navTile(
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        BrutalistButton(
            kind: .ghost,
            action: action,
            padding: EdgeInsets(top: 14, leading: 10, bottom: 14, trailing: 10)
        ) {
            Text(label)
                .font(BrutalistType.monoCaption)
                .kerning(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } caption: {
            EmptyView()
        }
    }

    private var footer: some View {
        HStack(spacing: BrutalistSpacing.m) {
            Text("BUILT FOR THE LONG GAME")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
            Spacer()
            Text("↗ SETTINGS")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .brutalistTap { flow.go(.settings) }
            Text("·")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
            Text("↳ SIGN OUT")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .brutalistTap(action: onSignOut)
        }
        .foregroundStyle(BrutalistColor.dim)
    }

    // MARK: - Helpers

    private func courseSubtitle(for round: CompletedRound) -> String {
        var parts: [String] = []
        if let teeName = round.teeName?.uppercased() { parts.append("\(teeName) TEES") }
        parts.append("\(round.holesPlayed.holeCount) HOLES")
        return parts.joined(separator: " — ")
    }

    private func referenceCode(for round: CompletedRound) -> String {
        let initials = (round.courseName ?? "ROUND").split(separator: " ").prefix(3).compactMap { $0.first }
        let prefix = String(initials).uppercased().padding(toLength: 3, withPad: "X", startingAt: 0)
        let suffix = String(format: "%04d", abs(round.id.hashValue) % 10_000)
        return "\(prefix)-\(suffix)"
    }

    private func dayTimeLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE · HH:mm"
        return formatter.string(from: now).uppercased()
    }

    private func yearLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter.string(from: now)
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yy"
        return formatter.string(from: date).uppercased()
    }

    private static let handicapFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

/// Bone-cream panel with corner registration marks. Compact rectangle
/// shape — half the height of a square card. Used for the Handicap +
/// Rounds twin stamps on Home.
private struct StampCard: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        ZStack {
            CornerMarks(size: 6, inset: 4, color: BrutalistColor.rule)
            HStack(alignment: .center, spacing: BrutalistSpacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label.uppercased())
                        .font(BrutalistType.monoMicro)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.muted)
                        .lineLimit(1)
                    Text(sub.uppercased())
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(value)
                    .font(BrutalistType.bigStat)
                    .kerning(-0.8)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(BrutalistColor.panel)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}
