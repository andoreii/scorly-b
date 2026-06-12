import SwiftUI

/// Motion curves + durations. Decisive ease-outs, no bounce, no
/// elastic. Brutalist motion is confident, not playful.
public enum Motion {
    // MARK: - Curves

    /// Tight ease-out for press states and instant feedback. ~160ms.
    public static let snap = Animation.timingCurve(0.20, 1.00, 0.30, 1.00, duration: 0.16)
    /// Standard ease-out-quart for page transitions and most UI.
    public static let easeOutQuart = Animation.timingCurve(0.22, 1.00, 0.36, 1.00, duration: 0.28)
    /// Longer ease-out-quint for sheets and dramatic transitions.
    public static let easeOutQuint = Animation.timingCurve(0.22, 1.00, 0.28, 1.00, duration: 0.42)

    /// Build a custom ease-out-quart at a specific duration.
    public static func easeOutQuart(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1.00, 0.36, 1.00, duration: duration)
    }

    /// Build a custom ease-out-quint at a specific duration.
    public static func easeOutQuint(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1.00, 0.28, 1.00, duration: duration)
    }

    // MARK: - Reduce Motion fallback

    /// Crossfade when Reduce Motion is on, otherwise the requested curve.
    public static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.18) : animation
    }
}
