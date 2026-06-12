import SwiftUI

/// Tap target that honors exact framed bounds, unlike `Button`'s implicit ~44pt expansion.
/// Use `content.brutalistTap { action }` wherever pixel-tight hit areas matter.
public extension View {
    func brutalistTap(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                guard !disabled else { return }
                action()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityRespondsToUserInteraction(!disabled)
    }
}
