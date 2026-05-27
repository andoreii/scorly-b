import ScorlyDesignSystem
import ScorlyDomain

/// Boundary mapping: Domain `SGTotals` → DesignSystem `SGCardValues`.
/// Lives here so both Round Detail and Sign & File feed
/// `StrokesGainedCard` from the same converter without DesignSystem
/// taking on a Domain dependency (`ArchitectureTests` invariant).
public enum SGCardMapping {
    public static func cardValues(_ totals: SGTotals) -> SGCardValues {
        SGCardValues(
            ott: totals.ott,
            app: totals.app,
            arg: totals.arg,
            putt: totals.putt,
            total: totals.total
        )
    }
}
