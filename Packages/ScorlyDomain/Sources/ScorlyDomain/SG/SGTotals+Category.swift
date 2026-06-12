import Foundation

public extension SGTotals {
    /// Per-category accessor, for looping over `SGCategory.allCases`.
    func value(for category: SGCategory) -> Decimal {
        switch category {
        case .ott: ott
        case .app: app
        case .arg: arg
        case .putt: putt
        }
    }
}
