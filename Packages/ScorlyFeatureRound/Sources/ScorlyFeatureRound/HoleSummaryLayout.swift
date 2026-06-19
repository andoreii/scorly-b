import CoreGraphics

enum HoleSummaryLayout {
    static let headerHeight: CGFloat = 30
    static let bodyHeight: CGFloat = 78

    static func scoreWidth(availableWidth: CGFloat) -> CGFloat {
        availableWidth / 3
    }
}
