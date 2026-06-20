import SwiftUI

/// Collapsible shell for single-round review metrics. Closed cards keep
/// only the identifying header and the metric that matters at a glance.
public struct ReviewDisclosureCard<Content: View>: View {
    private let meta: String
    private let title: String
    private let metric: String
    private let content: () -> Content

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    public init(
        meta: String,
        title: String,
        metric: String,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.meta = meta
        self.title = title
        self.metric = metric
        _isExpanded = State(initialValue: initiallyExpanded)
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 6, inset: 4)
            VStack(alignment: .leading, spacing: 0) {
                header
                if isExpanded {
                    Rectangle()
                        .fill(BrutalistColor.rule)
                        .frame(height: 1)
                    content()
                        .padding(14)
                        .transition(.opacity)
                }
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: BrutalistSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meta)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(title)
                    .font(BrutalistType.sans(.bold, size: 22))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer(minLength: BrutalistSpacing.s)
            HStack(alignment: .firstTextBaseline, spacing: BrutalistSpacing.s) {
                Text(metric)
                    .font(BrutalistType.mono(.semibold, size: 16))
                    .kerning(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                    .lineLimit(1)
                Text(isExpanded ? "▲" : "▼")
                    .font(BrutalistType.monoMicro)
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
        .padding(14)
        .brutalistTap {
            Haptics.soft()
            withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(isExpanded ? "Collapse" : "Expand")")
        .accessibilityValue(metric)
    }
}
