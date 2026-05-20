import ScorlyDesignSystem
import SwiftUI

/// Bottom sheet that hosts the tee-shot or approach editor. Mirrors
/// the chrome of `PenaltySheetView` (grab handle, header, hairline,
/// content, DONE) so all live-round sheets feel like one component.
struct ShotSheetView: View {
    enum Kind {
        case tee
        case approach
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
            ShotEditor(
                target: "Fairway",
                clubs: BrutalistClubs,
                clubDistanceDefaults: BrutalistClubDistances,
                lie: lieBinding(\.teeShot),
                lieModifier: lieBinding(\.teeShotModifier),
                club: clubBinding(\.teeClub),
                distance: distanceBinding(\.teeShotDistance)
            )
        case .approach:
            ShotEditor(
                target: "Green",
                clubs: BrutalistClubs,
                clubDistanceDefaults: BrutalistClubDistances,
                distanceLabel: "Distance to Pin",
                fieldOrder: .distanceFirst,
                lie: lieBinding(\.approach),
                lieModifier: lieBinding(\.approachModifier),
                club: clubBinding(\.approachClub),
                distance: distanceBinding(\.approachDistance)
            )
        }
    }

    private var kindLabel: String {
        switch kind {
        case .tee: "TEE SHOT"
        case .approach: state.currentHole.par == 3 ? "TEE / APPROACH" : "APPROACH"
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
