import SwiftUI

/// Typography tokens: Geist Sans for body + hero numerals, JetBrains Mono for
/// labels/metadata/figures. Number displays should call `.monospacedDigit()`.
public enum BrutalistType {
    // MARK: - Family names (Postscript)

    public enum Sans: String {
        case light = "Geist-Light"
        case regular = "Geist-Regular"
        case medium = "Geist-Medium"
        case semibold = "Geist-SemiBold"
        case bold = "Geist-Bold"
    }

    public enum Mono: String {
        case regular = "JetBrainsMono-Regular"
        case medium = "JetBrainsMono-Medium"
        case semibold = "JetBrainsMono-SemiBold"
    }

    // MARK: - Font builders

    public static func sans(_ weight: Sans, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }

    public static func mono(_ weight: Mono, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }

    // MARK: - Named scale (from DESIGN.md)

    /// 144pt — hero hole number on Round Play.
    public static let heroHole = sans(.bold, size: 144)
    /// 96pt — hero final score on Confirm.
    public static let heroFinalScore = sans(.bold, size: 96)
    /// 76pt — SCORLY/B wordmark on Home.
    public static let wordmark = sans(.bold, size: 76)
    /// 64pt — strokes stepper numeric.
    public static let stepperValue = sans(.bold, size: 64)
    /// 48pt — par on Round Play, score on history detail.
    public static let heroSecondary = sans(.bold, size: 48)
    /// 44pt — page hero (Setup / History titles).
    public static let pageHero = sans(.bold, size: 44)
    /// 38pt — StatCard value.
    public static let statCardValue = sans(.bold, size: 38)
    /// 28pt — temperature / mental state numeric.
    public static let mediumValue = sans(.bold, size: 28)
    /// 26pt — BigStat value, distance wheel readout.
    public static let bigStat = sans(.bold, size: 26)
    /// 22pt — sheet section title (course name on scorecard sheet).
    public static let sheetTitle = sans(.bold, size: 22)
    /// 18pt — list-row title.
    public static let rowTitle = sans(.bold, size: 18)
    /// 17pt — picker card title.
    public static let pickerTitle = sans(.bold, size: 17)
    /// 16pt — confirm-card course title.
    public static let confirmCardTitle = sans(.bold, size: 16)
    /// 15pt — Stat value (history stat blocks).
    public static let statValue = sans(.semibold, size: 15)
    /// 14pt — body sans / button title.
    public static let body = sans(.semibold, size: 14)
    /// 13pt — input field / MiniStat value.
    public static let inputBody = sans(.semibold, size: 13)
    /// 12pt — collapsible block title.
    public static let blockTitle = mono(.semibold, size: 12)
    /// 11pt — primary mono caption.
    public static let monoCaption = mono(.medium, size: 11)
    /// 10pt — section / chip label.
    public static let monoLabel = mono(.medium, size: 10)
    /// 9pt — micro label (mini stat label, footer line).
    public static let monoMicro = mono(.medium, size: 9)
    /// 8pt — axis label / hole-number tick.
    public static let monoTick = mono(.medium, size: 8)
}

// MARK: - Convenience modifiers

public extension View {
    /// Standard letter-spacing modifier. Negative for hero displays (-7 to -0.8),
    /// positive for mono labels (0.4 to 1.4).
    func brutalistTracking(_ tracking: CGFloat) -> some View {
        kerning(tracking)
    }
}
