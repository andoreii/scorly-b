import SwiftUI

/// Bordered collapsible block. Header has a small mono badge, mono
/// title, and a right-aligned summary string + chevron. Inverts when
/// open so the active block is unambiguous.
public struct CollapsibleBlock<Content: View>: View {
    private let badge: String
    private let title: String
    private let summary: String
    @Binding private var isOpen: Bool
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        badge: String,
        title: String,
        summary: String,
        isOpen: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.badge = badge
        self.title = title
        self.summary = summary
        _isOpen = isOpen
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.soft()
                withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                    isOpen.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        Text(badge.uppercased())
                            .font(BrutalistType.monoMicro)
                            .kerning(1.0)
                            .opacity(0.7)
                        Text(title.uppercased())
                            .font(BrutalistType.blockTitle)
                            .kerning(0.6)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Text(summary.uppercased())
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                            .opacity(0.85)
                        Text(isOpen ? "▲" : "▼")
                            .font(BrutalistType.monoCaption)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(isOpen ? BrutalistColor.fg : .clear)
                .foregroundStyle(isOpen ? BrutalistColor.bg : BrutalistColor.fg)
            }
            .buttonStyle(.plain)
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(BrutalistColor.rule).frame(height: 1)
                    content()
                        .padding(12)
                }
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}
