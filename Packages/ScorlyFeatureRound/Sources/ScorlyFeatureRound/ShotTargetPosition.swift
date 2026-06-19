import CoreGraphics
import Foundation

public struct ShotTargetPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(point: CGPoint) {
        x = min(1, max(0, point.x))
        y = min(1, max(0, point.y))
    }

    public var point: CGPoint {
        CGPoint(x: x, y: y)
    }
}
