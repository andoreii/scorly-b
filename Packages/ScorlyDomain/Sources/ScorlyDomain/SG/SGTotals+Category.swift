import Foundation

public extension SGTotals {
    /// Per-category accessor. Lets `GoalEvaluator` and `InsightEngine`
    /// loop over `SGCategory.allCases` and pull the matching value without
    /// hard-coding a switch at every call site.
    func value(for category: SGCategory) -> Decimal {
        switch category {
        case .ott: ott
        case .app: app
        case .arg: arg
        case .putt: putt
        }
    }
}
