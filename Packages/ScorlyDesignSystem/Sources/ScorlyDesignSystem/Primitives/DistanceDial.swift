import SwiftUI

/// Compact horizontal distance ruler. A ticked strip that scrubs under
/// a fixed centre needle — drag left/right to change the value. Ticks
/// every unit, with unit-specific major marks and labels. Yards for full
/// shots, feet for putts. Mirrors the React `RPIDial`: a low-profile dial that sits
/// under the shot sheet's big numeric readout (which shows the value),
/// so the dial itself stays quiet.
public struct DistanceDial: View {
    @Binding private var value: Int
    private let unit: Unit

    @State private var dragStart: Int?

    public enum Unit: Equatable, Sendable {
        case yards, feet

        /// Points of travel per unit of value.
        var pointsPerUnit: CGFloat {
            self == .feet ? 11 : 8
        }

        var range: ClosedRange<Int> {
            self == .feet ? 0...60 : 0...340
        }

        func isMajorMark(_ mark: Int) -> Bool {
            mark > 0 && mark.isMultiple(of: self == .feet ? 3 : 10)
        }

        func isMidMark(_ mark: Int) -> Bool {
            self == .yards && mark > 0 && mark.isMultiple(of: 5) && !isMajorMark(mark)
        }

        func labels(for mark: Int) -> (top: String?, bottom: String?) {
            guard isMajorMark(mark) else { return (nil, nil) }
            if self == .feet {
                return ("\(mark)", "\(mark / 3)")
            }
            return ("\(mark)", nil)
        }
    }

    public init(value: Binding<Int>, unit: Unit) {
        _value = value
        self.unit = unit
    }

    private let height: CGFloat = 56

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Canvas { ctx, size in
                draw(into: &ctx, size: size)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        let delta = gesture.translation.width / unit.pointsPerUnit
                        let next = clamp(start - Int(delta.rounded()))
                        if next != value {
                            value = next
                            Haptics.soft()
                        }
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .frame(height: height)
        .background(BrutalistColor.panel)
        .overlay(Rectangle().stroke(BrutalistColor.hair, lineWidth: 1.3))
    }

    private func clamp(_ raw: Int) -> Int {
        min(unit.range.upperBound, max(unit.range.lowerBound, raw))
    }

    private func draw(into ctx: inout GraphicsContext, size: CGSize) {
        let ppu = unit.pointsPerUnit
        let cx = size.width / 2
        let base = size.height - 12
        let hair = BrutalistColor.hair
        let muted = BrutalistColor.muted
        let acc = BrutalistColor.acc

        // Baseline.
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: base))
        baseline.addLine(to: CGPoint(x: size.width, y: base))
        ctx.stroke(baseline, with: .color(hair), lineWidth: 0.8)

        // Ticks within reach of the centre.
        let reach = Int((size.width / 2 / ppu).rounded(.up)) + 1
        let lo = max(unit.range.lowerBound, value - reach)
        let hi = min(unit.range.upperBound, value + reach)
        for mark in lo...hi {
            let x = cx + CGFloat(mark - value) * ppu
            let major = unit.isMajorMark(mark)
            let mid = unit.isMidMark(mark)
            let tickHeight: CGFloat = major ? 22 : mid ? 13 : 7
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: base))
            tick.addLine(to: CGPoint(x: x, y: base - tickHeight))
            ctx.stroke(tick, with: .color(major ? muted : hair), lineWidth: major ? 1.1 : 0.8)
            drawLabels(for: mark, at: x, base: base, color: muted, into: &ctx)
        }

        // Edge fades.
        let fadeW: CGFloat = 34
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: fadeW, height: size.height)),
            with: .linearGradient(
                Gradient(colors: [BrutalistColor.panel, BrutalistColor.panel.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: fadeW, y: 0)
            )
        )
        ctx.fill(
            Path(CGRect(x: size.width - fadeW, y: 0, width: fadeW, height: size.height)),
            with: .linearGradient(
                Gradient(colors: [BrutalistColor.panel.opacity(0), BrutalistColor.panel]),
                startPoint: CGPoint(x: size.width - fadeW, y: 0),
                endPoint: CGPoint(x: size.width, y: 0)
            )
        )

        // Centre needle.
        var needle = Path()
        needle.move(to: CGPoint(x: cx, y: 6))
        needle.addLine(to: CGPoint(x: cx, y: base))
        ctx.stroke(needle, with: .color(acc), lineWidth: 2)
        var cap = Path()
        cap.move(to: CGPoint(x: cx - 5, y: 5))
        cap.addLine(to: CGPoint(x: cx + 5, y: 5))
        cap.addLine(to: CGPoint(x: cx, y: 12))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(acc))
    }

    private func drawLabels(
        for mark: Int,
        at x: CGFloat,
        base: CGFloat,
        color: Color,
        into ctx: inout GraphicsContext
    ) {
        let labels = unit.labels(for: mark)
        if let top = labels.top {
            ctx.draw(
                Text(top).font(BrutalistType.mono(.medium, size: 8)).foregroundStyle(color),
                at: CGPoint(x: x, y: base - 30),
                anchor: .center
            )
        }
        if let bottom = labels.bottom {
            ctx.draw(
                Text(bottom).font(BrutalistType.mono(.medium, size: 7)).foregroundStyle(color),
                at: CGPoint(x: x, y: base + 7),
                anchor: .center
            )
        }
    }
}
