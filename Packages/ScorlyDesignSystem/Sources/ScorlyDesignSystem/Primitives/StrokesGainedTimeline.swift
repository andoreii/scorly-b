import SwiftUI

/// 18-hole SG timeline: per-hole bars + cumulative trace. Used by `StrokesGainedCard`.
struct SGHoleTimeline: View {
    let holes: [SGCardValues]
    /// X-axis title. Defaults to "HOLE"; multi-round usages pass
    /// "ROUND" so the same chart can plot per-round cumulative SG.
    var xAxisTitle = "HOLE"

    var body: some View {
        Canvas { ctx, size in
            let layout = SGTimelineLayout(holes: holes, size: size)
            drawGridlines(ctx: ctx, layout: layout)
            drawNinesDivider(ctx: ctx, layout: layout)
            drawBars(ctx: ctx, layout: layout)
            drawTrace(ctx: ctx, layout: layout)
            drawFinalTag(ctx: ctx, layout: layout)
            drawAxisTitles(ctx: ctx, size: size, layout: layout)
        }
    }

    // MARK: - Draw helpers

    private func drawGridlines(ctx: GraphicsContext, layout: SGTimelineLayout) {
        let yMaxCeil = Int(ceil(layout.yMax))
        for tick in -yMaxCeil...yMaxCeil {
            let yPos = layout.yFor(Double(tick))
            var path = Path()
            path.move(to: CGPoint(x: layout.padL, y: yPos))
            path.addLine(to: CGPoint(x: layout.size.width - layout.padR, y: yPos))
            if tick == 0 {
                ctx.stroke(path, with: .color(BrutalistColor.fg), lineWidth: 1)
            } else {
                ctx.stroke(
                    path,
                    with: .color(BrutalistColor.hair),
                    style: StrokeStyle(lineWidth: 0.6, dash: [2, 3])
                )
            }
            let label = tick > 0 ? "+\(tick)" : "\(tick)"
            let labelText = Text(label)
                .font(BrutalistType.monoMicro)
                .foregroundColor(tick == 0 ? BrutalistColor.fg : BrutalistColor.muted)
            ctx.draw(labelText, at: CGPoint(x: layout.padL - 6, y: yPos), anchor: .trailing)
        }
    }

    private func drawNinesDivider(ctx: GraphicsContext, layout: SGTimelineLayout) {
        guard layout.holeCount == 18 else { return }
        var path = Path()
        let dividerX = layout.xFor(8) + layout.colW / 2
        path.move(to: CGPoint(x: dividerX, y: layout.padT))
        path.addLine(to: CGPoint(x: dividerX, y: layout.size.height - layout.padB))
        ctx.stroke(
            path,
            with: .color(BrutalistColor.fg.opacity(0.6)),
            style: StrokeStyle(lineWidth: 0.6, dash: [1, 4])
        )
        ctx.draw(
            Text("FRONT 9").font(BrutalistType.monoTick).foregroundColor(BrutalistColor.muted),
            at: CGPoint(x: layout.xFor(4), y: layout.padT + 10),
            anchor: .center
        )
        ctx.draw(
            Text("BACK 9").font(BrutalistType.monoTick).foregroundColor(BrutalistColor.muted),
            at: CGPoint(x: layout.xFor(13), y: layout.padT + 10),
            anchor: .center
        )
    }

    private func drawBars(ctx: GraphicsContext, layout: SGTimelineLayout) {
        let barWidth = max(layout.colW * 0.5, 4)
        for (index, value) in layout.values.enumerated() {
            let xPos = layout.xFor(index)
            let yPos = value >= 0 ? layout.yFor(value) : layout.zeroY
            let barH = max(abs(layout.yFor(value) - layout.zeroY), 0.5)
            let rect = CGRect(x: xPos - barWidth / 2, y: yPos, width: barWidth, height: barH)
            ctx.fill(
                Path(rect),
                with: .color((value >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg).opacity(0.85))
            )
            ctx.draw(
                Text("\(index + 1)").font(BrutalistType.monoMicro).foregroundColor(BrutalistColor.muted),
                at: CGPoint(x: xPos, y: layout.size.height - layout.padB + 12),
                anchor: .center
            )
        }
    }

    private func drawTrace(ctx: GraphicsContext, layout: SGTimelineLayout) {
        var trace = Path()
        for (index, value) in layout.cumulative.enumerated() {
            let point = CGPoint(x: layout.xFor(index), y: layout.yFor(value))
            if index == 0 {
                trace.move(to: point)
            } else {
                trace.addLine(to: point)
            }
        }
        ctx.stroke(trace, with: .color(BrutalistColor.fg), lineWidth: 1.4)
        for (index, value) in layout.cumulative.enumerated() {
            let point = CGPoint(x: layout.xFor(index), y: layout.yFor(value))
            let dot = Path(ellipseIn: CGRect(x: point.x - 2.2, y: point.y - 2.2, width: 4.4, height: 4.4))
            ctx.fill(dot, with: .color(BrutalistColor.bg))
            ctx.stroke(dot, with: .color(BrutalistColor.fg), lineWidth: 1)
        }
    }

    private func drawFinalTag(ctx: GraphicsContext, layout: SGTimelineLayout) {
        guard let last = layout.cumulative.last else { return }
        let xPos = layout.xFor(layout.cumulative.count - 1)
        let yPos = layout.yFor(last)
        let tagRect = CGRect(x: xPos + 6, y: yPos - 9, width: 42, height: 16)
        ctx.fill(Path(tagRect), with: .color(BrutalistColor.bg))
        ctx.stroke(Path(tagRect), with: .color(BrutalistColor.fg), lineWidth: 1)
        ctx.draw(
            Text(sgFormat(Decimal(last)))
                .font(BrutalistType.mono(.semibold, size: 10))
                .foregroundColor(last >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg),
            at: CGPoint(x: tagRect.midX, y: tagRect.midY),
            anchor: .center
        )
    }

    private func drawAxisTitles(ctx: GraphicsContext, size: CGSize, layout: SGTimelineLayout) {
        ctx.draw(
            Text(xAxisTitle).font(BrutalistType.monoTick).foregroundColor(BrutalistColor.muted),
            at: CGPoint(x: layout.padL, y: size.height - 4),
            anchor: .leading
        )
        ctx.draw(
            Text("SG / CUM").font(BrutalistType.monoTick).foregroundColor(BrutalistColor.muted),
            at: CGPoint(x: size.width - layout.padR, y: size.height - 4),
            anchor: .trailing
        )
    }
}

/// Pre-computed coordinate transforms for the timeline. Keeping these
/// in one struct avoids passing 8+ scalars to every draw helper.
private struct SGTimelineLayout {
    let values: [Double]
    let cumulative: [Double]
    let size: CGSize
    let padL: CGFloat = 32
    let padR: CGFloat = 32
    let padT: CGFloat = 14
    let padB: CGFloat = 26
    let yMax: Double
    let colW: CGFloat

    var holeCount: Int {
        values.count
    }

    init(holes: [SGCardValues], size: CGSize) {
        self.size = size
        let values = holes.map { sgDecimalToDouble($0.total) }
        self.values = values
        var cum: [Double] = []
        var acc: Double = 0
        for value in values {
            acc += value
            cum.append(acc)
        }
        cumulative = cum
        let maxBar = (values.map(abs).max() ?? 0) * 1.15
        let maxCum = (cum.map(abs).max() ?? 0) * 1.15
        yMax = max(maxBar, maxCum, 1)
        let innerW = size.width - padL - padR
        colW = values.isEmpty ? innerW : innerW / CGFloat(values.count)
    }

    var zeroY: CGFloat {
        yFor(0)
    }

    func xFor(_ index: Int) -> CGFloat {
        padL + colW * (CGFloat(index) + 0.5)
    }

    func yFor(_ value: Double) -> CGFloat {
        let innerH = size.height - padT - padB
        return padT + innerH * (1 - CGFloat((value + yMax) / (2 * yMax)))
    }
}
