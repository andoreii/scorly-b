import ScorlyDesignSystem
import ScorlyDomain

/// Maps Domain `SGTotals` → DesignSystem `SGCardValues` without giving
/// DesignSystem a Domain dependency (`ArchitectureTests` invariant).
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
