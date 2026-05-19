import CoreGraphics
import Foundation

/// Discrete spacing scale. Stick to these. No in-between values.
public enum BrutalistSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 6
    public static let s: CGFloat = 8
    public static let sm: CGFloat = 10
    public static let m: CGFloat = 12
    public static let md: CGFloat = 14
    public static let l: CGFloat = 18
    public static let xl: CGFloat = 22
    public static let xxl: CGFloat = 28
    public static let xxxl: CGFloat = 36

    /// Extra top inset applied by `ScreenShell` on top of the iOS
    /// system safe area. The system already clears the status bar /
    /// Dynamic Island, so this is 0 — kept as a token for future
    /// surfaces (e.g. modal sheets) that may want a small buffer.
    public static let safeTop: CGFloat = 0
    /// Extra bottom inset applied by `ScreenShell`. The system clears
    /// the home indicator automatically, so this is 0.
    public static let safeBottom: CGFloat = 0
    /// Standard page horizontal padding.
    public static let pageHorizontal: CGFloat = 18
}
