import SwiftUI

/// Full-width brutalist button. Title on the left, optional mono
/// caption on the right. Inverts on press for tactile feedback.
///
/// Uses a raw `DragGesture` instead of `Button` so the hit shape matches the framed rect exactly.
public struct BrutalistButton<Title: View, Caption: View>: View {
    public enum Kind {
        case fg
        case inv
        case ghost
        case mono
    }

    private let kind: Kind
    private let action: () -> Void
    private let isDisabled: Bool
    private let padding: EdgeInsets
    private let title: () -> Title
    private let caption: () -> Caption

    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        kind: Kind = .fg,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder caption: @escaping () -> Caption
    ) {
        self.kind = kind
        self.action = action
        self.isDisabled = isDisabled
        self.padding = padding
        self.title = title
        self.caption = caption
    }

    public var body: some View {
        HStack {
            title()
            Spacer(minLength: 8)
            caption()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(background)
        .overlay(Rectangle().stroke(border, lineWidth: 1))
        .foregroundStyle(foreground)
        .scaleEffect(pressed ? 0.997 : 1)
        .opacity(isDisabled ? 0.4 : 1)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityRespondsToUserInteraction(!isDisabled)
        .gesture(pressGesture)
    }

    /// Drag-magnitude check distinguishes a tap from a drag, so swiping off cancels the action.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isDisabled, !pressed else { return }
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    pressed = true
                }
            }
            .onEnded { value in
                guard !isDisabled else { return }
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    pressed = false
                }
                let dx = value.translation.width
                let dy = value.translation.height
                let magnitude = (dx * dx + dy * dy).squareRoot()
                guard magnitude < 16 else { return }
                Haptics.rigid()
                action()
            }
    }

    private var background: Color {
        let normal: Color
        switch kind {
        case .fg: normal = BrutalistColor.fg
        case .inv: normal = BrutalistColor.bg
        case .ghost, .mono: normal = .clear
        }
        let inverted: Color
        switch kind {
        case .fg: inverted = BrutalistColor.bg
        case .inv: inverted = BrutalistColor.fg
        case .ghost, .mono: inverted = BrutalistColor.fg
        }
        return pressed ? inverted : normal
    }

    private var foreground: Color {
        let normal: Color
        switch kind {
        case .fg: normal = BrutalistColor.bg
        case .inv, .ghost, .mono: normal = BrutalistColor.fg
        }
        let inverted: Color
        switch kind {
        case .fg: inverted = BrutalistColor.fg
        case .inv: inverted = BrutalistColor.bg
        case .ghost, .mono: inverted = BrutalistColor.bg
        }
        return pressed ? inverted : normal
    }

    private var border: Color {
        BrutalistColor.fg
    }
}

// MARK: - Convenience initializers

public extension BrutalistButton where Caption == EmptyView {
    init(
        kind: Kind = .fg,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        @ViewBuilder title: @escaping () -> Title
    ) {
        self.init(
            kind: kind,
            action: action,
            isDisabled: isDisabled,
            padding: padding,
            title: title,
            caption: { EmptyView() }
        )
    }
}
