import SwiftUI

/// The little ball-flight glyph that sits beside a logged shot on the
/// Thread. A short dashed arc that bows toward where the ball finished
/// (driven by a lateral offset, -1 = hard left … +1 = hard right) and
/// ends in a filled dot. Accent-tinted when the shot was good. Mirrors
/// the inline tracer SVG in the React `RPIThreadRow`.
public struct ThreadTracer: View {
    private let offset: CGFloat
    private let good: Bool

    /// - Parameters:
    ///   - offset: lateral finish, clamped to -1…1.
    ///   - good: whether the shot found its target (accent tint).
    public init(offset: CGFloat, good: Bool) {
        self.offset = max(-1, min(1, offset))
        self.good = good
    }

    public var body: some View {
        Canvas { ctx, _ in
            let muted = BrutalistColor.muted
            let hair = BrutalistColor.hair
            let col = good ? BrutalistColor.acc : BrutalistColor.fg
            let x1 = 20 + offset * 13
            let cxp = 20 + offset * 18

            // Stub from the previous lie.
            var stub = Path()
            stub.move(to: CGPoint(x: 20, y: 50))
            stub.addLine(to: CGPoint(x: 20, y: 56))
            ctx.stroke(stub, with: .color(hair), style: StrokeStyle(lineWidth: 0.7, dash: [1, 3]))

            // Origin ring.
            ctx.stroke(
                Path(ellipseIn: CGRect(x: 17.8, y: 47.8, width: 4.4, height: 4.4)),
                with: .color(muted),
                lineWidth: 1
            )

            // Flight arc.
            var arc = Path()
            arc.move(to: CGPoint(x: 20, y: 50))
            arc.addQuadCurve(to: CGPoint(x: x1, y: 10), control: CGPoint(x: cxp, y: 27))
            ctx.stroke(arc, with: .color(col.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, dash: [1.6, 3]))

            // Landing ball.
            ctx.fill(Path(ellipseIn: CGRect(x: x1 - 3.4, y: 6.6, width: 6.8, height: 6.8)), with: .color(col))
        }
        .frame(width: 40, height: 58)
    }
}
