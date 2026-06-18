import SwiftUI

struct TrendDirectionChevron: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let xOffset = rect.midX - 12 * scale
        let yOffset = rect.midY - 12 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: xOffset + x * scale, y: yOffset + y * scale)
        }

        var path = Path()
        if pointsUp {
            path.move(to: point(4.5, 19.5))
            path.addLine(to: point(19.5, 4.5))
            path.move(to: point(19.5, 4.5))
            path.addLine(to: point(8.25, 4.5))
            path.move(to: point(19.5, 4.5))
            path.addLine(to: point(19.5, 15.75))
        } else {
            path.move(to: point(4.5, 4.5))
            path.addLine(to: point(19.5, 19.5))
            path.move(to: point(19.5, 19.5))
            path.addLine(to: point(19.5, 8.25))
            path.move(to: point(19.5, 19.5))
            path.addLine(to: point(8.25, 19.5))
        }
        return path
    }
}
