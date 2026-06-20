import SwiftUI

/// Running putts-per-hole average for one filed round. The dashed rule
/// is the round's final average.
struct PuttingProfileChart: View {
    let points: [PuttingAveragePoint]
    let average: Double?

    var body: some View {
        Canvas { context, size in
            guard !points.isEmpty else { return }
            let layout = PuttingProfileLayout(points: points, average: average, size: size)
            drawGrid(context: context, layout: layout)
            drawAverage(context: context, layout: layout)
            drawLine(context: context, layout: layout)
            drawPoints(context: context, layout: layout)
            drawLabels(context: context, layout: layout)
        }
    }

    private func drawGrid(context: GraphicsContext, layout: PuttingProfileLayout) {
        for tick in 0...layout.yMax {
            let y = layout.yFor(Double(tick))
            var line = Path()
            line.move(to: CGPoint(x: layout.padL, y: y))
            line.addLine(to: CGPoint(x: layout.size.width - layout.padR, y: y))
            context.stroke(
                line,
                with: .color(tick == 0 ? BrutalistColor.fg : BrutalistColor.hair),
                style: StrokeStyle(lineWidth: tick == 0 ? 1 : 0.6, dash: tick == 0 ? [] : [2, 3])
            )
            context.draw(
                Text("\(tick)")
                    .font(BrutalistType.monoMicro)
                    .foregroundColor(BrutalistColor.muted),
                at: CGPoint(x: layout.padL - 6, y: y),
                anchor: .trailing
            )
        }
    }

    private func drawAverage(context: GraphicsContext, layout: PuttingProfileLayout) {
        guard let average = layout.average else { return }
        let y = layout.yFor(average)
        var line = Path()
        line.move(to: CGPoint(x: layout.padL, y: y))
        line.addLine(to: CGPoint(x: layout.size.width - layout.padR, y: y))
        context.stroke(
            line,
            with: .color(BrutalistColor.fg),
            style: StrokeStyle(lineWidth: 0.9, dash: [1, 3])
        )
        context.draw(
            Text(String(format: "%.2f", average))
                .font(BrutalistType.mono(.semibold, size: 9))
                .foregroundColor(BrutalistColor.muted),
            at: CGPoint(x: layout.size.width - layout.padR + 6, y: y),
            anchor: .leading
        )
    }

    private func drawLine(context: GraphicsContext, layout: PuttingProfileLayout) {
        var line = Path()
        for index in points.indices {
            let point = layout.point(at: index)
            if index == points.startIndex {
                line.move(to: point)
            } else {
                line.addLine(to: point)
            }
        }
        context.stroke(
            line,
            with: .color(BrutalistColor.fg),
            style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawPoints(context: GraphicsContext, layout: PuttingProfileLayout) {
        for index in points.indices {
            let point = layout.point(at: index)
            let radius: CGFloat = 2.4
            let circle = Path(ellipseIn: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(circle, with: .color(BrutalistColor.bg))
            context.stroke(circle, with: .color(BrutalistColor.fg), lineWidth: 1.3)
        }
    }

    private func drawLabels(context: GraphicsContext, layout: PuttingProfileLayout) {
        for index in layout.labelIndices {
            let point = layout.point(at: index)
            let label = Text("H\(points[index].holeNumber)")
                .font(BrutalistType.monoMicro)
                .foregroundColor(BrutalistColor.muted)
            let anchor: UnitPoint = index == points.startIndex
                ? .leading
                : (index == points.index(before: points.endIndex) ? .trailing : .center)
            context.draw(label, at: CGPoint(x: point.x, y: layout.size.height - 6), anchor: anchor)
        }
    }
}

private struct PuttingProfileLayout {
    let points: [PuttingAveragePoint]
    let average: Double?
    let size: CGSize
    let padL: CGFloat = 24
    let padR: CGFloat = 34
    let padT: CGFloat = 12
    let padB: CGFloat = 22
    let yMax: Int

    init(points: [PuttingAveragePoint], average: Double?, size: CGSize) {
        self.points = points
        self.average = average
        self.size = size
        yMax = max(3, Int(ceil(points.map(\.averagePuttsPerHole).max() ?? 0)))
    }

    var labelIndices: [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        return [points.startIndex, points.count / 2, points.index(before: points.endIndex)]
    }

    func point(at index: Int) -> CGPoint {
        CGPoint(x: xFor(index), y: yFor(points[index].averagePuttsPerHole))
    }

    func xFor(_ index: Int) -> CGFloat {
        let width = size.width - padL - padR
        return padL + width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
    }

    func yFor(_ value: Double) -> CGFloat {
        let height = size.height - padT - padB
        return padT + height * CGFloat(1 - value / Double(yMax))
    }
}
