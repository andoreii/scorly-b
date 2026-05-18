import SwiftUI

/// Bordered field container with a small mono uppercase label.
public struct FieldBox<Content: View>: View {
    private let label: String
    private let content: () -> Content

    public init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}
