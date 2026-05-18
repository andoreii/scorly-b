import SwiftUI

/// Standard section wrapper. Mono uppercase label, then arbitrary
/// content slot. 18pt top margin.
public struct Section<Content: View>: View {
    private let label: String
    private let content: () -> Content

    public init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, BrutalistSpacing.l)
    }
}

/// Sub-label inside a collapsible block.
public struct SubLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(BrutalistType.monoMicro)
            .kerning(0.8)
            .foregroundStyle(BrutalistColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }
}

/// Top-bar mono ticker. Two slots, justified between.
public struct TopBar: View {
    private let left: String
    private let right: String

    public init(left: String, right: String) {
        self.left = left
        self.right = right
    }

    public var body: some View {
        HStack {
            Text(left.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Spacer()
            Text(right.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }
}
