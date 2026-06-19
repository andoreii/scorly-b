import CoreGraphics

enum ShotInputLayout {
    private static let horizontalPadding: CGFloat = 8

    static func radarSide(availableWidth: CGFloat) -> CGFloat {
        max(0, availableWidth - horizontalPadding * 2)
    }
}
