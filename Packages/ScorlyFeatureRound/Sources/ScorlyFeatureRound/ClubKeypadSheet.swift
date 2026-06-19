import ScorlyDesignSystem
import SwiftUI

/// Club picker popup raised from the shot sheet's club button. Reuses the
/// established `BrutalistClubs` vocabulary (Driver / 3-Wood / 50 / 54 /
/// 58 / Putter) via `ClubGrid`, in a bottom-anchored brutalist card.
struct ClubKeypadSheet: View {
    @Binding var club: String?
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 11) {
                HStack {
                    Text("CLUB USED")
                        .font(BrutalistType.mono(.semibold, size: 9.5))
                        .kerning(1.4)
                    Spacer()
                    Text("✕")
                        .font(BrutalistType.mono(.medium, size: 14))
                        .foregroundStyle(BrutalistColor.muted)
                        .brutalistTap(action: onClose)
                }
                ClubGrid(options: BrutalistClubs, selection: clubBinding)
            }
            .padding(13)
            .background(BrutalistColor.bg)
            .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 1.6))
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .transition(.opacity)
    }

    private var clubBinding: Binding<String?> {
        Binding(
            get: { club },
            set: { newValue in
                club = newValue
                if newValue != nil { onClose() }
            }
        )
    }
}
