import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Live round play screen — the "Thread" redesign. Keeps the header
/// (LIVE · course + progress strip) and the PREV / CARD / NEXT nav, and
/// swaps the old strokes-stepper + per-phase shot blocks for a compact
/// hole identity row, a live Hole Summary, and "The Thread": a tee→cup
/// list of shot nodes that each raise the `ShotInputSheet`. Owns nothing
/// but the `RoundPlayState` it drives; all stat derivation stays in that
/// state's existing `HoleEntry → derivedStat` pipeline.
public struct PlayView: View {
    @Bindable private var state: RoundPlayState
    private let onGoHome: () -> Void
    private let onEditSetup: () -> Void
    private let onFinish: () -> Void
    private let onAutosave: () -> Void

    @State private var lastHoleIdx = 0
    @State private var openSlot: RoundPlayState.ShotSlot?
    @State private var quickScoreOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: RoundPlayState,
        onGoHome: @escaping () -> Void,
        onEditSetup: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onAutosave: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onGoHome = onGoHome
        self.onEditSetup = onEditSetup
        self.onFinish = onFinish
        self.onAutosave = onAutosave
    }

    private var nodes: [RoundPlayState.ThreadNode] {
        state.threadNodes(at: state.holeIdx)
    }

    private var holeComplete: Bool {
        state.isHoleComplete(at: state.holeIdx)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
            shotSheetOverlay
        }
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
        .onChange(of: state.holeIdx, initial: true) { _, newValue in
            lastHoleIdx = newValue
            openSlot = nil
            onAutosave()
        }
        .sheet(isPresented: $state.scorecardOpen) {
            ScorecardSheetView(state: state)
        }
        .sheet(isPresented: $state.penaltySheetOpen) {
            PenaltySheetView(state: state)
        }
        .sheet(isPresented: $quickScoreOpen) {
            QuickScoreSheet(state: state, onClose: { quickScoreOpen = false })
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            TopBar(left: "LIVE · \(state.course.name.uppercased())", right: "SCORLY/B  ®")
            backRow
            progressDots
            identityRow
                .padding(.top, BrutalistSpacing.m)
            HoleSummaryCard(
                hole: state.currentHole,
                stats: state.summaryStats(at: state.holeIdx),
                done: holeComplete
            )
            .padding(.top, BrutalistSpacing.m)
            ThreadView(
                nodes: nodes,
                editingSlot: openSlot,
                done: holeComplete,
                onOpen: open
            )
            .padding(.top, BrutalistSpacing.s)
            utilityRow
            HBar(vMargin: BrutalistSpacing.s)
            navRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, BrutalistSpacing.pageHorizontal)
        .padding(.bottom, BrutalistSpacing.xs)
    }

    private func open(_ slot: RoundPlayState.ShotSlot) {
        Haptics.light()
        withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
            openSlot = slot
        }
    }

    // MARK: - Shot sheet overlay

    @ViewBuilder
    private var shotSheetOverlay: some View {
        if let slot = openSlot,
           let i = nodes.firstIndex(where: { $0.slot == slot }) {
            ShotInputSheet(
                state: state,
                node: nodes[i],
                total: nodes.count,
                prevSlot: i > 0 ? nodes[i - 1].slot : nil,
                nextSlot: i < nodes.count - 1 ? nodes[i + 1].slot : nil,
                onSelect: { openSlot = $0 },
                onClose: { withAnimation(Motion.snap) { openSlot = nil } }
            )
            .zIndex(1)
            .transition(.opacity)
        }
    }

    // MARK: - Back row

    private var backRow: some View {
        HStack {
            Text("← HOME")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onGoHome)
            Spacer()
            Text("↻ SETUP")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onEditSetup)
            Spacer()
            Text("LIVE ROUND")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
        .padding(.top, BrutalistSpacing.l)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 3) {
            ForEach(state.holes.indices, id: \.self) { index in
                let here = index == state.holeIdx
                let done = state.entries[index].strokes != nil
                Rectangle()
                    .fill(here ? BrutalistColor.fg : done ? BrutalistColor.muted : BrutalistColor.hair)
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
                    .brutalistTap {
                        Haptics.light()
                        withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                            state.jump(to: index)
                        }
                    }
            }
        }
        .padding(.top, BrutalistSpacing.m)
    }

    // MARK: - Hole identity row

    private var identityRow: some View {
        let hole = state.currentHole
        return HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 13) {
                Text(String(format: "%02d", hole.number))
                    .font(BrutalistType.sans(.bold, size: 64))
                    .kerning(-3.5)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText(countsDown: state.holeIdx < lastHoleIdx))
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOLE")
                        .font(BrutalistType.mono(.medium, size: 9))
                        .kerning(2.0)
                        .foregroundStyle(BrutalistColor.muted)
                    Text("PAR \(hole.par)")
                        .font(BrutalistType.mono(.semibold, size: 15))
                        .monospacedDigit()
                }
            }
            Spacer()
            HStack(alignment: .top, spacing: 22) {
                identityStat("YDS", state.teeYardageForCurrentHole.map { "\($0)" } ?? "—")
                identityStat("HCP", hole.handicapIndex.map { String(format: "%02d", $0) } ?? "—")
            }
        }
    }

    private func identityStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(BrutalistType.mono(.medium, size: 9))
                .kerning(1.8)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.mono(.semibold, size: 19))
                .monospacedDigit()
        }
    }

    // MARK: - Utility row (escape hatches)

    private var utilityRow: some View {
        HStack {
            Text("QUICK SCORE")
                .brutalistTap {
                    Haptics.light()
                    quickScoreOpen = true
                }
            Spacer()
            Text("PENALTIES / OVERRIDES")
                .brutalistTap {
                    Haptics.light()
                    state.penaltySheetOpen = true
                }
        }
        .font(BrutalistType.mono(.medium, size: 9))
        .kerning(0.8)
        .foregroundStyle(BrutalistColor.muted)
        .padding(.top, BrutalistSpacing.s)
    }

    // MARK: - Nav row

    private var navRow: some View {
        let isLast = state.holeIdx >= state.holes.count - 1
        let prevHoleNumber: String = {
            guard state.holeIdx > 0 else { return "—" }
            return "H\(String(format: "%02d", state.holes[state.holeIdx - 1].number))"
        }()
        let nextHoleNumber: String = {
            guard state.holeIdx < state.holes.count - 1 else { return "SIGN" }
            return "H\(String(format: "%02d", state.holes[state.holeIdx + 1].number))"
        }()
        return HStack(spacing: 6) {
            navButton(
                title: "←  PREV",
                caption: prevHoleNumber,
                kind: .ghost,
                isDisabled: state.holeIdx == 0,
                action: {
                    withAnimation(Motion.adaptive(Motion.easeOutQuart(0.32), reduceMotion: reduceMotion)) {
                        state.move(delta: -1)
                    }
                }
            )
            .frame(maxWidth: .infinity)

            cardButton

            navButton(
                title: isLast ? "FINISH  →" : "NEXT  →",
                caption: nextHoleNumber,
                kind: .fg,
                isDisabled: false,
                action: {
                    if isLast {
                        state.commitParIfNil(at: state.holeIdx)
                        onFinish()
                    } else {
                        withAnimation(Motion.adaptive(Motion.easeOutQuart(0.32), reduceMotion: reduceMotion)) {
                            state.move(delta: 1)
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func navButton(
        title: String,
        caption: String,
        kind: BrutalistButton<Text, Text>.Kind,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        BrutalistButton(
            kind: kind,
            action: action,
            isDisabled: isDisabled,
            padding: EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
        ) {
            Text(title)
                .font(BrutalistType.mono(.semibold, size: 11))
                .kerning(1.0)
        } caption: {
            Text(caption)
                .font(BrutalistType.mono(.medium, size: 10))
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.dim)
        }
    }

    /// Compact, centered CARD button — opens the full round scorecard.
    private var cardButton: some View {
        Text("CARD")
            .font(BrutalistType.mono(.semibold, size: 11))
            .kerning(1.0)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 1))
            .contentShape(Rectangle())
            .brutalistTap {
                Haptics.light()
                state.scorecardOpen = true
            }
    }
}
