import SwiftUI

/// Brutalist palette. Bone-cream paper, ink type, no accent. Token
/// names mirror the React design source 1:1 so spotting a misuse in
/// review is trivial.
///
/// Values are intentionally tinted away from absolute black / white —
/// `bg` carries warmth, `fg` carries a hint of warm ink, so the page
/// reads like aged paper instead of an LCD.
public enum BrutalistColor {
    /// Page ground — bone-cream paper. `#EFEBE2`.
    public static let bg = Color(red: 0xEF / 255, green: 0xEB / 255, blue: 0xE2 / 255)
    /// Ink — type, rules, primary buttons. `#0A0A0A`.
    public static let fg = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    /// Soft-elevated panel ground (stat cards, picker faces). `#F4F1E9`.
    public static let panel = Color(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xE9 / 255)
    /// Deeper panel (OB cells in the lie keypad). `#E6E1D7`.
    public static let panel2 = Color(red: 0xE6 / 255, green: 0xE1 / 255, blue: 0xD7 / 255)
    /// Hairline rule color, matches `fg`.
    public static let rule = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    /// Soft 1px hairline (interior cell dividers). `#C9C3B6`.
    public static let hair = Color(red: 0xC9 / 255, green: 0xC3 / 255, blue: 0xB6 / 255)
    /// Mono captions, secondary text. `#5C5C58`.
    public static let muted = Color(red: 0x5C / 255, green: 0x5C / 255, blue: 0x58 / 255)
    /// Tertiary text, axis labels. `#8A8780`.
    public static let dim = Color(red: 0x8A / 255, green: 0x87 / 255, blue: 0x80 / 255)
    /// Inverse panel ground (Last Round stamp, Final Score). `#0A0A0A`.
    public static let invBg = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    /// Type on inverse panel. `#EFEBE2`.
    public static let invFg = Color(red: 0xEF / 255, green: 0xEB / 255, blue: 0xE2 / 255)
    /// Captions on inverse panel. `#9A9A95`.
    public static let invMuted = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x95 / 255)

    // MARK: - Strokes Gained accents

    //
    // **Documented exception.** DESIGN.md states the accent budget is
    // zero and "no accent color ever." Strokes Gained is the single,
    // deliberate carve-out: green/red here are *notation* — same role
    // as the circle-under-par / box-over-par convention in `Pip` —
    // encoding the direction of a signed number. They are only used in
    // `StrokesGainedCard` (`SGDivergingBars`, `SGHoleTimeline`, and the
    // summary cells). Never use these tokens for buttons, highlights,
    // or "important" things. The rest of the app remains accent-free.

    /// Muted green for strokes gained. `#2F6B3A`.
    public static let sgPos = Color(red: 0x2F / 255, green: 0x6B / 255, blue: 0x3A / 255)
    /// Muted red for strokes lost. `#9A2A1F`.
    public static let sgNeg = Color(red: 0x9A / 255, green: 0x2A / 255, blue: 0x1F / 255)
    /// Low-opacity green fill for bar interiors. ~`rgba(47,107,58,0.16)`.
    public static let sgPosFill = sgPos.opacity(0.16)
    /// Low-opacity red fill for bar interiors. ~`rgba(154,42,31,0.14)`.
    public static let sgNegFill = sgNeg.opacity(0.14)

    // MARK: - Score grid

    //
    // Score-distribution + hole-heatmap palette. Same notation rationale
    // as the SG accents above — green/red/bogey here encode the
    // direction of a score relative to par, not decoration. Used only by
    // the Trend page's distribution bars and hole-by-hole heat grid.

    /// Warm ochre for bogey cells. `#B5862A`, OKLCH ~ L 0.66 / C 0.10 /
    /// H 78 — sits between sand and ink on bone paper.
    public static let bogey = Color(red: 0xB5 / 255, green: 0x86 / 255, blue: 0x2A / 255)
    /// Low-opacity ochre fill for bogey grid cells.
    public static let bogeyFill = bogey.opacity(0.22)

    // MARK: - Review spectrum

    /// Charcoal ink for the par segment in scoring distributions.
    public static let parInk = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x2F / 255)
    /// Warm stone for the bogey segment.
    public static let stone = Color(red: 0xB8 / 255, green: 0xB2 / 255, blue: 0xA6 / 255)
    /// Bunker sand used in accuracy windroses.
    public static let bunker = Color(red: 0xC9 / 255, green: 0xA8 / 255, blue: 0x6B / 255)
    /// Out-of-bounds ink used in accuracy windroses.
    public static let ob = sgNeg

    // MARK: - Round Play accent

    //
    // **Documented exception.** DESIGN.md sets the accent budget to zero
    // ("no accent color ever"). The Round Play "Thread" redesign is a
    // deliberate, user-approved carve-out: a single muted fairway green
    // marks *good / active* shot outcomes (fairway found, green hit,
    // putt holed, the live tracer) so the eye can read a hole's success
    // at a glance on a dense, fast-input screen. Same notation rationale
    // as `sgPos` / `bogey` above — it encodes outcome, not decoration.
    // Used only inside ScorlyFeatureRound's live-play surfaces
    // (TargetField, ThreadView, HoleSummaryCard, ShotInputSheet). Do not
    // reach for it elsewhere; the rest of the app stays accent-free.

    /// Muted fairway green for good / active shot outcomes. `#3F7A52`.
    public static let acc = Color(red: 0x3F / 255, green: 0x7A / 255, blue: 0x52 / 255)
    /// Low-opacity green wash for good-state fills. ~`rgba(63,122,82,0.10)`.
    public static let accFill = acc.opacity(0.10)
}
