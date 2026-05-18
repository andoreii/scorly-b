import SwiftUI

/// 4-wide grid of clubs. Single-select with deselect-on-retap.
public struct ClubGrid: View {
    private let options: [String]
    @Binding private var selection: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(options: [String], selection: Binding<String?>) {
        self.options = options
        _selection = selection
    }

    public var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
        LazyVGrid(columns: cols, spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let active = selection == option
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        selection = active ? nil : option
                    }
                } label: {
                    Text(option)
                        .font(BrutalistType.monoCaption)
                        .kerning(0.4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(active ? BrutalistColor.fg : .clear)
                        .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                        .overlay(
                            Rectangle()
                                .stroke(BrutalistColor.hair, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .id(index)
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.hair, lineWidth: 1))
    }
}
