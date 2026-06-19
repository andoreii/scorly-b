import CoreGraphics

enum TargetFieldClassifier {
    static let viewBox: CGFloat = 300
    static let center = CGPoint(x: 150, y: 148)
    static let maxRadius: CGFloat = 122
    static let fairwayHalfWidth = maxRadius * 0.27
    static let fairwayHalfHeight = maxRadius * 0.55

    static var fairwayRect: CGRect {
        CGRect(
            x: center.x - fairwayHalfWidth,
            y: center.y - fairwayHalfHeight,
            width: fairwayHalfWidth * 2,
            height: fairwayHalfHeight * 2
        )
    }

    static func classify(mode: TargetField.Mode, x: CGFloat, y: CGFloat) -> TargetField.Pick {
        let dx = x - center.x
        let dy = y - center.y
        let ratio = min(1, hypot(dx, dy) / maxRadius)
        let position = CGPoint(x: x / viewBox, y: y / viewBox)
        let horizontal = dx >= 0 ? "Right" : "Left"
        let vertical = dy <= 0 ? "Long" : "Short"
        let dominant = abs(dy) > abs(dx) ? vertical : horizontal

        switch mode {
        case .fairway:
            return classifyFairway(position: position, dx: dx, dy: dy, dominant: dominant)
        case .green:
            return classifyGreen(position: position, ratio: ratio, dominant: dominant)
        case .putt:
            return classifyPutt(position: position, ratio: ratio, dominant: dominant)
        }
    }

    private static func classifyFairway(
        position: CGPoint,
        dx: CGFloat,
        dy: CGFloat,
        dominant: String
    ) -> TargetField.Pick {
        if abs(dx) <= fairwayHalfWidth, abs(dy) <= fairwayHalfHeight {
            return TargetField.Pick(value: "Fairway", pos: position, good: true, label: "FAIRWAY")
        }
        let label = if dominant == "Left" || dominant == "Right" {
            "ROUGH \(dominant.uppercased())"
        } else {
            "MISS \(dominant.uppercased())"
        }
        return TargetField.Pick(value: "Miss \(dominant)", pos: position, good: false, label: label)
    }

    private static func classifyGreen(position: CGPoint, ratio: CGFloat, dominant: String) -> TargetField.Pick {
        if ratio <= 0.10 {
            return TargetField.Pick(
                value: "Green",
                pos: position,
                good: true,
                label: "HOLED",
                proximityFeet: 0,
                holed: true
            )
        }
        let edge: CGFloat = 0.46
        let feet = max(0, Int((ratio / edge * 32).rounded()))
        if ratio <= edge {
            return TargetField.Pick(
                value: "Green",
                pos: position,
                good: true,
                label: feet <= 4 ? "STIFF" : "ON GREEN",
                proximityFeet: max(2, feet)
            )
        }
        return TargetField.Pick(
            value: "Miss \(dominant)",
            pos: position,
            good: false,
            label: "MISS \(dominant.uppercased())"
        )
    }

    private static func classifyPutt(position: CGPoint, ratio: CGFloat, dominant: String) -> TargetField.Pick {
        if ratio <= 0.10 {
            return TargetField.Pick(
                value: nil,
                pos: position,
                good: true,
                label: "HOLED",
                proximityFeet: 0,
                holed: true
            )
        }
        let feet = max(1, Int((ratio * 15).rounded()))
        return TargetField.Pick(
            value: nil,
            pos: position,
            good: false,
            label: "\(feet) FT \(dominant.uppercased())",
            proximityFeet: feet
        )
    }
}
