import SwiftUI

/// 1px indeterminate progress bar with a mono `SYNCING…` caption.
/// Brutalist alternative to `UIActivityIndicator` / `ProgressView` —
/// the bar lives at the top of a screen, slides in when async work
/// starts, slides out when it finishes. Width animates a 25%-wide
/// sweep from left to right and loops.
public struct HairlineProgress: View {
    private let isLoading: Bool
    private let caption: String

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isLoading: Bool, caption: String = "SYNCING…") {
        self.isLoading = isLoading
        self.caption = caption
    }

    public var body: some View {
        VStack(spacing: 4) {
            if isLoading {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(BrutalistColor.hair)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(BrutalistColor.fg)
                            .frame(width: geo.size.width * 0.25, height: 1)
                            .offset(x: phase * (geo.size.width * 1.25) - geo.size.width * 0.25)
                    }
                }
                .frame(height: 1)
                Text(caption)
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isLoading)
        .onChange(of: isLoading, initial: true) { _, loading in
            guard loading, !reduceMotion else {
                phase = 0
                return
            }
            phase = 0
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
