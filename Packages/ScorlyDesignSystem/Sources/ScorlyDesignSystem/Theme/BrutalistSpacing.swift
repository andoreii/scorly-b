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

    /// iOS top safe-area inset used by `ScreenShell`. Matches the
    /// design's `SAFE_TOP = 58` constant.
    public static let safeTop: CGFloat = 58
    /// iOS bottom safe-area inset used by `ScreenShell`. Matches
    /// `SAFE_BOTTOM = 36`.
    public static let safeBottom: CGFloat = 36
    /// Standard page horizontal padding.
    public static let pageHorizontal: CGFloat = 18
}
