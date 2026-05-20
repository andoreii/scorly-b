import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Live round play screen. Progress dots, hole hero, strokes
/// stepper, three collapsible shot blocks, pin / penalty, derived
/// stats, and bottom-row nav. Owns nothing — drives the
/// `RoundPlayState` it's handed.
public struct PlayView: View {
    @Bindable private var state: RoundPlayState
    private let onBack: () -> Void
    private let onFinish: () -> Void

    @State private var lastHoleIdx: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: RoundPlayState,
        onBack: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.state = state
        self.onBack = onBack
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Top-anchored content. Lives in the top half of the ZStack
            // regardless of intrinsic height. Removing one shot block on
            // par 3 only shrinks this column from the bottom — TopBar
            // through strokesPanel never move.
            VStack(alignment: .leading, spacing: 0) {
                TopBar(left: "LIVE · \(state.course.name.uppercased())", right: "SCORLY/B  ®")

                backRow
                progressDots
                progressLabels
                holeHero

                metricsRow
                HBar(vMargin: BrutalistSpacing.m)

                SubLabel("Strokes")
                strokesPanel

                shotBlocks
                puttingBlock
                pinSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrutalistSpacing.pageHorizontal)

            // Bottom-anchored nav. Independent of the top layer; pinned
            // to the bottom safe-area edge in every state.
            VStack(spacing: 0) {
                HBar(vMargin: BrutalistSpacing.xs)
                navRow
                    .padding(.top, BrutalistSpacing.xs)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, BrutalistSpacing.pageHorizontal)
            .padding(.bottom, BrutalistSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
        .onChange(of: state.holeIdx, initial: true) { _, newValue in
            lastHoleIdx = newValue
        }
        .sheet(isPresented: shotSheetBinding(.tee)) {
            ShotSheetView(state: state, kind: .tee)
        }
        .sheet(isPresented: shotSheetBinding(.approach)) {
            ShotSheetView(state: state, kind: .approach)
        }
        .sheet(isPresented: shotSheetBinding(.putts)) {
            PuttingSheetView(state: state)
        }
        .sheet(isPresented: $state.scorecardOpen) {
            ScorecardSheetView(state: state)
        }
        .sheet(isPresented: $state.penaltySheetOpen) {
            PenaltySheetView(state: state)
        }
    }

    private func shotSheetBinding(_ shot: RoundPlayState.OpenShot) -> Binding<Bool> {
        Binding(
            get: { state.openShot == shot },
            set: { newValue in
                if !newValue, state.openShot == shot { state.openShot = .none }
            }
        )
    }

    // MARK: - Back row

    private var backRow: some View {
        HStack {
            Text("← BACK TO SETUP")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onBack)
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

    private var progressLabels: some View {
        HStack {
            Text("HOLE \(String(format: "%02d", state.holeIdx + 1)) / \(state.holes.count)")
            Spacer()
            Text("\(state.filledCount)/\(state.holes.count) LOGGED")
            Spacer()
            Text("\(formattedDiff(state.vsPar)) · \(state.totalStrokes)")
        }
        .font(BrutalistType.mono(.medium, size: 9))
        .kerning(0.8)
        .foregroundStyle(BrutalistColor.muted)
        .monospacedDigit()
        .padding(.top, BrutalistSpacing.xs)
    }

    // MARK: - Hole hero

    private var holeHero: some View {
        let hole = state.currentHole
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HOLE №")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(String(format: "%02d", hole.number))
                    .font(BrutalistType.heroHole)
                    .kerning(-5)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 160, alignment: .top)
                    .contentTransition(.numericText(countsDown: state.holeIdx < lastHoleIdx))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                heroStat(label: "Par", value: "\(hole.par)", big: true)
                heroStat(label: "Yards", value: state.teeYardageForCurrentHole.map { "\($0)" } ?? "—", big: false)
                heroStat(label: "HCP", value: hole.handicapIndex.map { String(format: "%02d", $0) } ?? "—", big: false)
            }
        }
        .frame(height: 200, alignment: .topLeading)
        .padding(.top, BrutalistSpacing.l)
    }

    @ViewBuilder
    private func heroStat(label: String, value: String, big: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            if big {
                Text(value)
                    .font(BrutalistType.heroSecondary)
                    .kerning(-1.6)
                    .monospacedDigit()
            } else {
                Text(value)
                    .font(BrutalistType.mono(.semibold, size: 18))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Strokes panel

    private var strokesPanel: some View {
        let hole = state.currentHole
        let strokes = state.currentEntry.strokes ?? hole.par
        return HStack(alignment: .center) {
            HStack(spacing: 14) {
                strokeStepButton("−", enabled: strokes > 1) {
                    state.entries[state.holeIdx].strokes = max(1, strokes - 1)
                }
                Text("\(strokes)")
                    .font(BrutalistType.stepperValue)
                    .kerning(-2.4)
                    .monospacedDigit()
                    .frame(minWidth: 70)
                    .contentTransition(.numericText())
                strokeStepButton("+", enabled: strokes < 15) {
                    state.entries[state.holeIdx].strokes = min(15, strokes + 1)
                }
                penaltyButton
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(ScoreLabel.text(strokes: strokes, par: hole.par))
                    .font(BrutalistType.mono(.semibold, size: 11))
                    .kerning(1.2)
                Text("\(formattedDiff(strokes - hole.par)) VS PAR")
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                Pip(strokes: strokes, par: hole.par, size: 28, weight: 1.4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    @ViewBuilder
    private func strokeStepButton(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Text(glyph)
            .font(BrutalistType.mono(.medium, size: 20))
            .frame(width: 38, height: 38)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            .foregroundStyle(BrutalistColor.fg)
            .opacity(enabled ? 1 : 0.35)
            .brutalistTap(disabled: !enabled) {
                Haptics.medium()
                withAnimation(Motion.snap) { action() }
            }
    }

    private var penaltyButton: some View {
        // Surface the same number the FIR/GIR chip row uses, so OB and
        // hazard picks from the shot sheets light up the card without
        // double-counting a manual penalty stepper edit.
        let count = state.derivedStat(for: state.holeIdx).effectivePenaltyStrokes
        let active = count > 0
        return Text(active ? "+\(count)" : "PEN")
            .font(active
                ? BrutalistType.mono(.semibold, size: 12)
                : BrutalistType.mono(.medium, size: 9))
            .kerning(0.4)
            .frame(width: 38, height: 38)
            .background(active ? BrutalistColor.fg : .clear)
            .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.muted)
            .overlay(Rectangle().stroke(active ? BrutalistColor.fg : BrutalistColor.hair, lineWidth: 1))
            .brutalistTap {
                Haptics.light()
                state.penaltySheetOpen = true
            }
    }

    // MARK: - Shot blocks

    @ViewBuilder
    private var shotBlocks: some View {
        let isPar3 = state.currentHole.par == 3
        VStack(spacing: 8) {
            if !isPar3 {
                ShotBlock(
                    badge: "01",
                    title: "Tee Shot",
                    lie: lieBinding(\.teeShot),
                    lieModifier: lieBinding(\.teeShotModifier),
                    club: clubBinding(\.teeClub),
                    distance: distanceBinding(\.teeShotDistance),
                    onTap: { state.openShot = .tee }
                )
            }
            ShotBlock(
                badge: isPar3 ? "01" : "02",
                title: isPar3 ? "Tee / Approach" : "Approach",
                lie: lieBinding(\.approach),
                lieModifier: lieBinding(\.approachModifier),
                club: clubBinding(\.approachClub),
                distance: distanceBinding(\.approachDistance),
                onTap: { state.openShot = .approach }
            )
        }
        .padding(.top, BrutalistSpacing.m)
    }

    private var puttingBlock: some View {
        let isPar3 = state.currentHole.par == 3
        return PuttingBlock(
            badge: isPar3 ? "02" : "03",
            putts: state.currentEntry.putts,
            distances: state.currentEntry.puttDistances,
            onTap: { state.openShot = .putts }
        )
        .padding(.top, BrutalistSpacing.s)
    }

    // MARK: - Pin

    private var pinSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Pin Position")
            PinSelect(value: Binding(
                get: { state.currentEntry.pinPosition },
                set: { state.entries[state.holeIdx].pinPosition = $0 }
            ))
        }
        .padding(.top, BrutalistSpacing.m)
    }

    // MARK: - Metrics row (above STROKES divider)

    private var metricsRow: some View {
        let isPar3 = state.currentHole.par == 3
        let stat = state.derivedStat(for: state.holeIdx)
        return HStack(spacing: 6) {
            if !isPar3 {
                metricChip("FIR", active: stat.fairwayInRegulation)
            }
            metricChip("GIR", active: stat.greenInRegulation)
            if stat.threePutt {
                metricChip("3PUTT", active: true)
            }
            if stat.upAndDown {
                metricChip("UP&DN", active: true)
            }
            if stat.bunkerCount > 0 {
                metricChip("BUNK \(stat.bunkerCount)", active: true)
            }
            if stat.outOfBoundsCount > 0 {
                metricChip("OB \(stat.outOfBoundsCount)", active: true)
            }
            if stat.hazardCount > 0 {
                metricChip("HAZ \(stat.hazardCount)", active: true)
            }
            if stat.effectivePenaltyStrokes > 0 {
                metricChip("+PEN \(stat.effectivePenaltyStrokes)", active: true)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 22, alignment: .leading)
        .padding(.top, BrutalistSpacing.m)
    }

    private func metricChip(_ label: String, active: Bool) -> some View {
        Text(label.uppercased())
            .font(active
                ? BrutalistType.mono(.regular, size: 9)
                : BrutalistType.mono(.medium, size: 9))
            .kerning(0.8)
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(active ? BrutalistColor.fg : .clear)
            .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.muted)
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

    @ViewBuilder
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

    /// Compact, centered CARD button. The shared `navButton` helper
    /// uses an HStack with `title — Spacer — caption` so a `.fixedSize`
    /// version still left-aligns its text. This standalone button keeps
    /// the label centered in its frame.
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

    // MARK: - Bindings

    private func lieBinding(_ keyPath: WritableKeyPath<HoleEntry, String?>) -> Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx][keyPath: keyPath] },
            set: { state.entries[state.holeIdx][keyPath: keyPath] = $0 }
        )
    }

    private func clubBinding(_ keyPath: WritableKeyPath<HoleEntry, String?>) -> Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx][keyPath: keyPath] },
            set: { state.entries[state.holeIdx][keyPath: keyPath] = $0 }
        )
    }

    private func distanceBinding(_ keyPath: WritableKeyPath<HoleEntry, Int?>) -> Binding<Int?> {
        Binding(
            get: { state.entries[state.holeIdx][keyPath: keyPath] },
            set: { state.entries[state.holeIdx][keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Helpers

    private func formattedDiff(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
