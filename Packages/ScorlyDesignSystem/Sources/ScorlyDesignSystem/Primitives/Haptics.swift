import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tiny haptic facade. Centralizes the design system's vocabulary of
/// physical feedback so individual call sites stay declarative.
public enum Haptics {
    /// Default press feedback for any interactive primitive.
    public static func rigid() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Stepper increment/decrement, distance wheel major tick.
    public static func medium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Distance wheel tick, chip toggle, collapsible open.
    public static func soft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Light selection feedback.
    public static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Successful filing (file scorecard, etc).
    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Auth failure, validation error.
    public static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
