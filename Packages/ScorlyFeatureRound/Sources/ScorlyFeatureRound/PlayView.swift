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
        ScreenShell {
            TopBar(left: "LIVE · \(state.course.name.uppercased())", right: "SCORLY/B  ®")

            backRow
            progressDots
            progressLabels
            holeHero

            HBar(vMargin: BrutalistSpacing.m)

            SubLabel("Strokes")
            strokesPanel

            shotBlocks
            puttingBlock
            pinSection
            penaltyStepper
            manualOverrides
            derivedStrip

            HBar(vMargin: BrutalistSpacing.l)

            navRow
        }
        .sheet(isPresented: $state.scorecardOpen) {
            ScorecardSheetView(state: state)
        }
    }

    // MARK: - Back row

    private var backRow: some View {
        HStack {
            Button(action: onBack) {
                Text("← BACK TO SETUP")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
            }
            .buttonStyle(.plain)
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
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        state.jump(to: index)
                    }
                } label: {
                    Rectangle()
                        .fill(here ? BrutalistColor.fg : done ? BrutalistColor.muted : BrutalistColor.hair)
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
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
                    .kerning(-7)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                heroStat(label: "Par", value: "\(hole.par)", big: true)
                heroStat(label: "Yards", value: state.teeYardageForCurrentHole.map { "\($0)" } ?? "—", big: false)
                heroStat(label: "HCP", value: hole.handicapIndex.map { String(format: "%02d", $0) } ?? "—", big: false)
            }
        }
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
            BrutalistStepper(
                value: Binding(
                    get: { strokes },
                    set: { newValue in state.entries[state.holeIdx].strokes = newValue }
                ),
                range: 1...15
            )
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

    // MARK: - Shot blocks

    @ViewBuilder
    private var shotBlocks: some View {
        let isPar3 = state.currentHole.par == 3
        VStack(spacing: 8) {
            if !isPar3 {
                ShotBlock(
                    badge: "01",
                    title: "Tee Shot",
                    target: "Fairway",
                    clubs: BrutalistClubs,
                    lie: lieBinding(\.teeShot),
                    club: clubBinding(\.teeClub),
                    distance: distanceBinding(\.teeShotDistance),
                    isOpen: shotOpenBinding(.tee)
                )
            }
            ShotBlock(
                badge: isPar3 ? "01" : "02",
                title: isPar3 ? "Tee / Approach" : "Approach",
                target: "Green",
                clubs: BrutalistClubs,
                lie: lieBinding(\.approach),
                club: clubBinding(\.approachClub),
                distance: distanceBinding(\.approachDistance),
                isOpen: shotOpenBinding(.approach)
            )
        }
        .padding(.top, BrutalistSpacing.m)
    }

    private var puttingBlock: some View {
        let isPar3 = state.currentHole.par == 3
        return PuttingBlock(
            badge: isPar3 ? "02" : "03",
            putts: Binding(
                get: { state.currentEntry.putts },
                set: { newValue in
                    var entry = state.entries[state.holeIdx]
                    entry.putts = newValue
                    if entry.puttDistances.count > newValue {
                        entry.puttDistances = Array(entry.puttDistances.prefix(newValue))
                    }
                    state.entries[state.holeIdx] = entry
                }
            ),
            distances: Binding(
                get: { state.currentEntry.puttDistances },
                set: { state.entries[state.holeIdx].puttDistances = $0 }
            ),
            isOpen: shotOpenBinding(.putts)
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

    // MARK: - Penalty

    private var penaltyStepper: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Penalty Strokes  /  Manual")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNPLAYABLES · LATERAL DROPS · ETC.")
                        .font(BrutalistType.mono(.medium, size: 9))
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                    Text("\(state.currentEntry.penaltyStrokes)")
                        .font(BrutalistType.mediumValue)
                        .kerning(-0.8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                HStack(spacing: 6) {
                    SmallStep("−") {
                        withAnimation(Motion.snap) {
                            state.entries[state.holeIdx].penaltyStrokes = max(0, state.currentEntry.penaltyStrokes - 1)
                        }
                    }
                    SmallStep("+") {
                        withAnimation(Motion.snap) {
                            state.entries[state.holeIdx].penaltyStrokes = min(9, state.currentEntry.penaltyStrokes + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
        .padding(.top, BrutalistSpacing.m)
    }

    // MARK: - Manual overrides

    @ViewBuilder
    private var manualOverrides: some View {
        if let stat = state.derivedStat(for: state.holeIdx) {
            let showUpDown = !stat.greenInRegulation
            let showSandSave = stat.bunkerCount > 0 && !stat.greenInRegulation
            if showUpDown || showSandSave {
                VStack(alignment: .leading, spacing: 6) {
                    SubLabel("Manual Overrides")
                    let columns = (showUpDown && showSandSave) ? 2 : 1
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                        spacing: 10
                    ) {
                        if showUpDown {
                            OverrideTile(
                                label: "Up & Down",
                                auto: stat.upAndDown,
                                value: Binding(
                                    get: { state.currentEntry.upAndDownOverride },
                                    set: { state.entries[state.holeIdx].upAndDownOverride = $0 }
                                )
                            )
                        }
                        if showSandSave {
                            OverrideTile(
                                label: "Sand Save",
                                auto: stat.sandSave,
                                value: Binding(
                                    get: { state.currentEntry.sandSaveOverride },
                                    set: { state.entries[state.holeIdx].sandSaveOverride = $0 }
                                )
                            )
                        }
                    }
                }
                .padding(.top, BrutalistSpacing.m)
            }
        }
    }

    // MARK: - Auto-derived strip

    @ViewBuilder
    private var derivedStrip: some View {
        if let stat = state.derivedStat(for: state.holeIdx) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AUTO-DERIVED")
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    DerivedBadge(label: "GIR", hit: stat.greenInRegulation)
                    DerivedBadge(label: "FIR", hit: stat.fairwayInRegulation, isDisabled: state.currentHole.par == 3)
                    DerivedBadge(label: "3PUTT", hit: stat.threePutt, flip: true)
                    DerivedBadge(label: "UP&DN", hit: stat.upAndDown)
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                    spacing: 6
                ) {
                    derivedCount(label: "BUNK", value: stat.bunkerCount)
                    derivedCount(label: "OB", value: stat.outOfBoundsCount)
                    derivedCount(label: "HAZ", value: stat.hazardCount)
                    derivedCount(label: "+PEN", value: stat.effectivePenaltyStrokes)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BrutalistColor.panel)
            .overlay(Rectangle().stroke(BrutalistColor.hair, lineWidth: 1))
            .padding(.top, BrutalistSpacing.m)
        }
    }

    private func derivedCount(label: String, value: Int) -> some View {
        Text("\(label) \(value)")
            .font(BrutalistType.mono(.medium, size: 9))
            .kerning(0.6)
            .foregroundStyle(BrutalistColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .monospacedDigit()
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

            navButton(
                title: "CARD",
                caption: "",
                kind: .ghost,
                isDisabled: false,
                action: {
                    Haptics.light()
                    state.scorecardOpen = true
                }
            )
            .frame(maxWidth: .infinity)

            navButton(
                title: isLast ? "FINISH  →" : "NEXT  →",
                caption: nextHoleNumber,
                kind: .fg,
                isDisabled: false,
                action: {
                    if isLast {
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

    private func shotOpenBinding(_ shot: RoundPlayState.OpenShot) -> Binding<Bool> {
        Binding(
            get: { state.openShot == shot },
            set: { newValue in
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    state.openShot = newValue ? shot : .none
                }
            }
        )
    }

    // MARK: - Helpers

    private func formattedDiff(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
