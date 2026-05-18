import SwiftUI

/// Three-segment Front / Middle / Back picker.
public struct PinSelect: View {
    @Binding private var value: String?
    private let options: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Binding<String?>, options: [String] = ["Front", "Middle", "Back"]) {
        _value = value
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let active = value == option
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        value = active ? nil : option
                    }
                } label: {
                    Text(option.uppercased())
                        .font(BrutalistType.monoCaption)
                        .kerning(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active ? BrutalistColor.fg : .clear)
                        .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                        .overlay(alignment: .trailing) {
                            if index < options.count - 1 {
                                Rectangle()
                                    .fill(BrutalistColor.hair)
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}
