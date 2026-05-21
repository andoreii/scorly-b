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
    let inProgress: InProgressSummary?
    let onResumeRound: () -> Void
    let onDiscardDraft: () -> Void
    let onStartNewRound: () -> Void

    @State private var now = Date()
    @State private var showDiscardConfirm = false
    @State private var showStartNewConfirm = false
    @State private var livePulseOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            if let inProgress {
                inProgressStamp(inProgress)
                    .padding(.top, BrutalistSpacing.md)
            } else if let lastRound {
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

    private func inProgressStamp(_ summary: InProgressSummary) -> some View {
        ZStack {
            CornerMarks(inset: 6, color: BrutalistColor.invFg)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("IN PROGRESS · STARTED \(Self.shortDate(summary.startedAt))")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                    Spacer()
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(BrutalistColor.invFg)
                            .frame(width: 6, height: 6)
                            .opacity(reduceMotion ? 1 : (livePulseOn ? 1 : 0.2))
                        Text("LIVE")
                            .font(BrutalistType.monoLabel)
                            .kerning(1.0)
                    }
                }
                Rectangle().fill(BrutalistColor.invFg).frame(height: 1).opacity(0.4).padding(.vertical, 12)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.courseName)
                            .font(BrutalistType.body)
                        Text(summary.subtitle)
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.invMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(summary.totalStrokes)")
                            .font(BrutalistType.heroSecondary)
                            .kerning(-1.8)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(String(format: "HOLE %02d / %02d", summary.holeIdx + 1, summary.totalHoles))
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                    }
                }
                Rectangle().fill(BrutalistColor.invFg).frame(height: 1).opacity(0.4).padding(.vertical, 12)
                HStack(spacing: 0) {
                    Stat(label: "Putts", value: "\(summary.totalPutts)", mutedColor: BrutalistColor.invMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Stat(
                        label: "Logged",
                        value: "\(summary.filledCount)/\(summary.totalHoles)",
                        mutedColor: BrutalistColor.invMuted
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Stat(
                        label: "vs Par",
                        value: formattedDiff(summary.vsPar),
                        mutedColor: BrutalistColor.invMuted
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(BrutalistColor.invBg)
        .foregroundStyle(BrutalistColor.invFg)
        .contentShape(Rectangle())
        .brutalistTap(action: onResumeRound)
        .onLongPressGesture(minimumDuration: 0.5) {
            Haptics.medium()
            showDiscardConfirm = true
        }
        .sheet(isPresented: $showDiscardConfirm) {
            DiscardDraftSheet(
                eyebrow: "ROUND IN PROGRESS",
                title: "Discard this round?",
                message: "Your strokes and shot data for this round will be erased. This can't be undone.",
                destructiveLabel: "DISCARD",
                destructiveCaption: "→ ERASE",
                onConfirm: { onDiscardDraft() }
            )
        }
        .task(id: livePulseOn) {
            guard !reduceMotion else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.6)) {
                livePulseOn.toggle()
            }
        }
    }

    private func formattedDiff(_ value: Int) -> String {
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "\(value)"
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
            action: {
                if inProgress != nil {
                    showStartNewConfirm = true
                } else {
                    onStartNewRound()
                }
            },
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
        .sheet(isPresented: $showStartNewConfirm) {
            DiscardDraftSheet(
                eyebrow: "ROUND IN PROGRESS",
                title: "Start a new round?",
                message: "The round you're playing will be discarded. This can't be undone.",
                destructiveLabel: "DISCARD & START NEW",
                destructiveCaption: "→ TEE OFF",
                onConfirm: {
                    onDiscardDraft()
                    onStartNewRound()
                }
            )
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

/// Brutalist confirmation bottom sheet. Matches the chrome of the in-
/// round sheets (grab handle, mono eyebrow, sans title, HBar, stacked
/// buttons) so the discard prompt feels native to the rest of the app
/// instead of using SwiftUI's system confirmation dialog.
private struct DiscardDraftSheet: View {
    let eyebrow: String
    let title: String
    let message: String
    let destructiveLabel: String
    let destructiveCaption: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabHandle
            header
            HBar(vMargin: BrutalistSpacing.m)
            Text(message)
                .font(BrutalistType.body)
                .foregroundStyle(BrutalistColor.fg)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrutalistSpacing.xs)
            Spacer(minLength: BrutalistSpacing.l)
            buttons
        }
        .padding(.horizontal, BrutalistSpacing.pageHorizontal)
        .padding(.top, BrutalistSpacing.s)
        .padding(.bottom, BrutalistSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BrutalistColor.bg)
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.hidden)
    }

    private var grabHandle: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 44, height: 3)
            Spacer()
        }
        .padding(.bottom, BrutalistSpacing.s)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(title)
                    .font(BrutalistType.sheetTitle)
                    .kerning(-0.6)
            }
            Spacer()
            Text("CLOSE ✕")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap { dismiss() }
        }
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            BrutalistButton(
                kind: .fg,
                action: {
                    onConfirm()
                    dismiss()
                },
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text(destructiveLabel)
                    .font(BrutalistType.sans(.bold, size: 16))
                    .kerning(-0.2)
            } caption: {
                Text(destructiveCaption)
                    .font(BrutalistType.monoCaption)
                    .kerning(1.2)
            }
            BrutalistButton(
                kind: .ghost,
                action: { dismiss() },
                padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
            ) {
                Text("KEEP PLAYING")
                    .font(BrutalistType.mono(.medium, size: 11))
                    .kerning(1.2)
            }
        }
    }
}

/// View-layer snapshot of an in-progress round. RootView builds this
/// from the persisted `InProgressRoundDraft` + the `Course` lookup,
/// keeping HomeView ignorant of the Domain types and the raw entries
/// payload.
struct InProgressSummary: Equatable {
    let courseName: String
    let subtitle: String
    let startedAt: Date
    let holeIdx: Int
    let totalHoles: Int
    let totalStrokes: Int
    let totalPutts: Int
    let filledCount: Int
    let vsPar: Int
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
