import SwiftUI

/// Brutalist-tight tap target. SwiftUI's `Button` applies an implicit
/// ~44pt minimum-touch-target expansion that `.contentShape` does not
/// override, so taps register noticeably outside the visible rect.
/// This modifier sidesteps `Button` entirely and uses an explicit
/// `.contentShape(Rectangle())` + `.onTapGesture` pair, which honors
/// the exact framed bounds. The `.isButton` accessibility trait keeps
/// VoiceOver behavior parity.
///
/// Use `content.brutalistTap { action }` instead of wrapping content
/// in a `Button` when pixel-tight hit areas matter (which is
/// everywhere in this brutalist UI).
public extension View {
    func brutalistTap(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture {
                guard !disabled else { return }
                action()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityRespondsToUserInteraction(!disabled)
    }
}
