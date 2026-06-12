import ScorlyDesignSystem
import SwiftUI

/// Bottom sheet hosting the tee-shot or approach editor. Mirrors `PenaltySheetView`'s
/// chrome so all live-round sheets feel like one component.
struct ShotSheetView: View {
    enum Kind {
        case tee
        case layup
        case approach
        case arg
    }

    @Bindable var state: RoundPlayState
    let kind: Kind

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabHandle
                    header
                    HBar(vMargin: BrutalistSpacing.m)
                    editor
                }
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.s)
                .padding(.bottom, BrutalistSpacing.m)
            }
            doneButton
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.m)
                .padding(.bottom, BrutalistSpacing.m)
                .background(BrutalistColor.bg)
        }
        .background(BrutalistColor.bg)
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.large])
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
                Text(kindLabel)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text("Hole \(state.currentHole.number)")
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

    @ViewBuilder
    private var editor: some View {
        switch kind {
        case .tee:
            VStack(alignment: .leading, spacing: 0) {
                ShotEditor(
                    target: "Fairway",
                    clubs: BrutalistClubs,
                    clubDistanceDefaults: BrutalistClubDistances,
                    clearsDistanceWhenOB: true,
                    extraTopRight: drivenGreen,
                    lie: obAwareTeeBinding,
                    lieModifier: lieBinding(\.teeShotModifier),
                    club: clubBinding(\.teeClub),
                    distance: distanceBinding(\.teeShotDistance)
                )
                // Par 3: tee shot is the approach, so capture LANDED AT for a missed green.
                if state.currentHole.par == 3 {
                    landedAtSection
                }
            }
        case .layup:
            layupSection
        case .approach:
            VStack(alignment: .leading, spacing: 0) {
                pinPositionSection
                ShotEditor(
                    target: "Green",
                    clubs: BrutalistClubs,
                    clubDistanceDefaults: BrutalistClubDistances,
                    distanceLabel: "Distance to Pin",
                    fieldOrder: .distanceFirst,
                    extraTopLeft: approachIn,
                    extraTopRight: par5OnInTwo,
                    lie: approachResultBinding,
                    lieModifier: lieBinding(\.approachModifier),
                    club: clubBinding(\.approachClub),
                    distance: distanceBinding(\.approachDistance)
                )
                landedAtSection
            }
        case .arg:
            ARGEditorSection(state: state, holeIndex: state.holeIdx)
        }
    }

    // MARK: - PIN POSITION

    private var pinPositionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Pin Position")
            PinSelect(value: Binding(
                get: { state.entries[state.holeIdx].pinPosition },
                set: { state.entries[state.holeIdx].pinPosition = $0 }
            ))
        }
        .padding(.bottom, 14)
    }

    // MARK: - LANDED AT (approach landing distance)

    /// Shown only when the result lie implies a chip phase (non-green, non-OB, non-nil).
    @ViewBuilder
    private var landedAtSection: some View {
        let approachLie = approachLieForLandingPrompt
        if shouldShowLandedAt(approachLie: approachLie) {
            VStack(alignment: .leading, spacing: 6) {
                SubLabel("Landed at (from pin)")
                DistanceWheel(
                    value: landingDistanceBinding,
                    range: 1...150,
                    step: 1,
                    majorEvery: 10,
                    unit: "YDS"
                )
            }
            .padding(.top, 14)
        }
    }

    private var approachLieForLandingPrompt: String? {
        switch kind {
        case .tee:
            // Par-3 tee editor uses the same binding ShotEditor writes for the keypad.
            state.entries[state.holeIdx].teeShot
        case .approach:
            state.entries[state.holeIdx].approach
        case .layup, .arg:
            nil
        }
    }

    private func shouldShowLandedAt(approachLie: String?) -> Bool {
        guard let raw = approachLie else { return false }
        if raw == "Green" || raw == "On In 2" || raw == "In" { return false }
        if raw.hasPrefix("OB ") { return false }
        return true
    }

    private var landingDistanceBinding: Binding<Int?> {
        Binding(
            get: { state.entries[state.holeIdx].approachLandingDistance },
            set: { state.entries[state.holeIdx].approachLandingDistance = $0 }
        )
    }

    // MARK: - 2ND SHOT (par-5 layup capture)

    private var layupSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Result")
            LieKeypad(
                value: layupLieBinding,
                modifier: layupModifierBinding,
                target: "Fairway"
            )
        }
    }

    private var layupLieBinding: Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx].layupLie },
            set: { state.entries[state.holeIdx].layupLie = $0 }
        )
    }

    private var layupModifierBinding: Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx].layupLieModifier },
            set: { state.entries[state.holeIdx].layupLieModifier = $0 }
        )
    }

    /// Tee-shot binding enforces dependent state changes in `RoundPlayState`.
    private var obAwareTeeBinding: Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx].teeShot },
            set: { state.setTeeShotResult($0, at: state.holeIdx) }
        )
    }

    private var approachResultBinding: Binding<String?> {
        Binding(
            get: { state.entries[state.holeIdx].approach },
            set: { state.setApproachResult($0, at: state.holeIdx) }
        )
    }

    /// Par-4/5 tee-shot shortcut for a green reached directly from the tee.
    private var drivenGreen: LieKeypad.AuxButton? {
        guard kind == .tee, state.currentHole.par >= 4 else { return nil }
        let active = state.hasDrivenGreen(at: state.holeIdx)
        return LieKeypad.AuxButton(
            label: "GRN",
            isActive: active,
            action: { state.setTeeShotResult(active ? nil : "Green", at: state.holeIdx) }
        )
    }

    /// Par-5-only "ON IN 2" aux button, stored as sentinel `"On In 2"` so it toggles
    /// independently from the GRN cell; both decode to `Lie.green` for stats.
    private var par5OnInTwo: LieKeypad.AuxButton? {
        guard kind == .approach, state.currentHole.par == 5 else { return nil }
        let active = state.entries[state.holeIdx].approach == "On In 2"
        return LieKeypad.AuxButton(
            label: "ON IN 2",
            isActive: active,
            action: {
                state.setApproachResult(active ? nil : "On In 2", at: state.holeIdx)
            }
        )
    }

    private var approachIn: LieKeypad.AuxButton? {
        guard kind == .approach else { return nil }
        return LieKeypad.AuxButton(
            label: "IN",
            isActive: state.isApproachIn(at: state.holeIdx),
            action: { state.markApproachIn(at: state.holeIdx) }
        )
    }

    private var kindLabel: String {
        switch kind {
        case .tee: "TEE SHOT"
        case .layup: "2ND SHOT"
        case .approach: state.currentHole.par == 3 ? "TEE / APPROACH" : "APPROACH"
        case .arg: "AROUND THE GREEN"
        }
    }

    private var doneButton: some View {
        BrutalistButton(
            kind: .fg,
            action: { dismiss() },
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        ) {
            Text("DONE")
                .font(BrutalistType.sans(.bold, size: 15))
                .kerning(0.4)
        }
    }

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
}
