import SwiftUI

/// Tap-to-place shot target. The hole's input made spatial: instead of
/// a directional keypad, the player taps *where the ball finished* on a
/// re-centring radial field. Three modes, each rescaled to what's being
/// aimed at:
///   - `.fairway` — tee / lay-up: a corridor; lateral accuracy decides
///     Fairway → rough → fairway bunker.
///   - `.green` — approach: rings on the pin; inside the disk is a GIR
///     (with a proximity readout in feet), outside is a directional miss.
///   - `.putt` — the cup: tight feet rings; dead-centre holes out,
///     anywhere else leaves a putt of N feet.
///
/// The field emits the **same raw lie vocabulary as `LieKeypad`** — a
/// `value` string ("Fairway", "Miss Left", "Green") plus an optional
/// `modifier` ("Bunker") — so the feature layer's existing
/// `decodeLie` consumes a tap and a keypad pick identically. Penalties
/// (OB / Water / Unplayable) are not tap outcomes; the sheet layers them
/// as explicit hazard tags.
///
/// Geometry mirrors the React `RPITargetField` 1:1 in a 300×300 space,
/// scaled to fill whatever square the layout hands it.
public struct TargetField: View {
    public enum Mode: Equatable, Sendable { case fairway, green, putt }

    /// The outcome of a single tap, in the `LieKeypad` vocabulary plus
    /// the spatial extras the directional keypad can't express.
    public struct Pick: Equatable, Sendable {
        /// Raw lie string ("Fairway", "Green", "Miss Left", …) or nil
        /// for a putt (a putt records no lie).
        public var value: String?
        /// Optional companion modifier ("Bunker"). nil otherwise.
        public var modifier: String?
        /// Normalised tap position within the field, 0…1 on each axis.
        /// Persisted so the ball + tracer can be redrawn on revisit.
        public var pos: CGPoint
        /// Whether this is a "good" outcome (fairway found / green hit /
        /// holed) — drives the accent treatment.
        public var good: Bool
        /// Short uppercase label for the result chip ("FAIRWAY",
        /// "12 FT SHORT", "STIFF").
        public var label: String
        /// Distance from the pin in feet. For `.green`, the proximity of
        /// a GIR (seeds the first putt). For `.putt`, the remaining
        /// length after a miss. nil when not applicable.
        public var proximityFeet: Int?
        /// True only for a putt tapped dead-centre (in the cup).
        public var holed: Bool

        public init(
            value: String?,
            pos: CGPoint,
            good: Bool,
            label: String,
            modifier: String? = nil,
            proximityFeet: Int? = nil,
            holed: Bool = false
        ) {
            self.value = value
            self.modifier = modifier
            self.pos = pos
            self.good = good
            self.label = label
            self.proximityFeet = proximityFeet
            self.holed = holed
        }
    }

    private let mode: Mode
    private let placement: Pick?
    private let onPick: (Pick) -> Void

    public init(mode: Mode, placement: Pick?, onPick: @escaping (Pick) -> Void) {
        self.mode = mode
        self.placement = placement
        self.onPick = onPick
    }

    // 300×300 authoring space (matches the React source exactly).
    private static let vb: CGFloat = 300
    private static let cx: CGFloat = 150
    private static let cy: CGFloat = 148
    private static let maxR: CGFloat = 122

    /// Square bounding rect for a circle of `radius` centred on `point`.
    private static func circle(at point: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / Self.vb
            Canvas { ctx, _ in
                ctx.scaleBy(x: scale, y: scale)
                draw(into: &ctx)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // SpatialTapGesture fires reliably for a stationary tap (a bare
            // DragGesture(minimumDistance: 0) does not), so any point in the
            // field registers — and it won't fight a parent sheet's drag.
            .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                place(value.location, geo: geo, side: side, scale: scale)
            })
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Map a tap/drag point (local space) into 300-space and emit a pick.
    private func place(_ location: CGPoint, geo: GeometryProxy, side: CGFloat, scale: CGFloat) {
        let originX = (geo.size.width - side) / 2
        let originY = (geo.size.height - side) / 2
        let x = (location.x - originX) / scale
        let y = (location.y - originY) / scale
        guard x >= 0, x <= Self.vb, y >= 0, y <= Self.vb else { return }
        Haptics.soft()
        onPick(TargetFieldClassifier.classify(mode: mode, x: x, y: y))
    }

    // MARK: - Drawing (300-space)

    private func draw(into ctx: inout GraphicsContext) {
        let acc = BrutalistColor.acc
        let hair = BrutalistColor.hair
        let dim = BrutalistColor.dim
        let center = CGPoint(x: Self.cx, y: Self.cy)

        // Fairway corridor.
        if mode == .fairway {
            let rect = TargetFieldClassifier.fairwayRect
            ctx.fill(Path(rect), with: .color(acc.opacity(0.10)))
            ctx.stroke(Path(rect), with: .color(acc), style: StrokeStyle(lineWidth: 0.8, dash: [3, 5]))
        }

        // Green disk.
        let greenR: CGFloat = mode == .green ? 56 : 0
        if greenR > 0 {
            let disk = Path(ellipseIn: Self.circle(at: center, radius: greenR))
            ctx.fill(disk, with: .color(acc.opacity(0.12)))
            ctx.stroke(disk, with: .color(acc), lineWidth: 1)
        }

        // Rings.
        let rings: [CGFloat] = mode == .putt ? [122, 92, 62, 32] : mode == .green ? [122, 92, 56] : [122, 84, 48]
        for (index, radius) in rings.enumerated() {
            let ring = Path(ellipseIn: Self.circle(at: center, radius: radius))
            ctx.stroke(
                ring,
                with: .color(hair),
                style: StrokeStyle(lineWidth: index == 0 ? 1 : 0.8, dash: index == 0 ? [2, 5] : [])
            )
        }

        // Crosshair.
        var cross = Path()
        cross.move(to: CGPoint(x: center.x, y: center.y - 126))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + 126))
        cross.move(to: CGPoint(x: center.x - 126, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + 126, y: center.y))
        ctx.stroke(cross, with: .color(hair), style: StrokeStyle(lineWidth: 0.7, dash: [2, 6]))

        // Axis labels.
        for axis in axisLabels() {
            ctx.draw(
                Text(axis.text).font(BrutalistType.mono(.medium, size: 7)).foregroundStyle(dim),
                at: axis.point,
                anchor: axis.anchor
            )
        }

        drawCentreMarker(into: &ctx, center: center, fg: BrutalistColor.fg)
        drawBallOrHint(into: &ctx, center: center)
    }

    private func drawBallOrHint(into ctx: inout GraphicsContext, center: CGPoint) {
        let acc = BrutalistColor.acc
        guard let placed = placement else {
            let hint = mode == .green ? "TAP WHERE IT LANDED" : "TAP WHERE IT FINISHED"
            ctx.draw(
                Text(hint).font(BrutalistType.mono(.medium, size: 8)).foregroundStyle(BrutalistColor.dim),
                at: CGPoint(x: center.x, y: Self.vb - 6),
                anchor: .center
            )
            return
        }
        let ball = CGPoint(x: placed.pos.x * Self.vb, y: placed.pos.y * Self.vb)
        let col = placed.good ? acc : BrutalistColor.fg
        var tracer = Path()
        tracer.move(to: center)
        tracer.addLine(to: ball)
        ctx.stroke(tracer, with: .color(col.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, dash: [1.5, 4]))
        let halo = Path(ellipseIn: CGRect(x: ball.x - 11, y: ball.y - 11, width: 22, height: 22))
        ctx.stroke(halo, with: .color(col.opacity(0.5)), lineWidth: 1.3)
        let dot = Path(ellipseIn: CGRect(x: ball.x - 5.2, y: ball.y - 5.2, width: 10.4, height: 10.4))
        ctx.fill(dot, with: .color(col))
    }

    private func drawCentreMarker(into ctx: inout GraphicsContext, center: CGPoint, fg: Color) {
        switch mode {
        case .putt:
            let cup = Path(ellipseIn: Self.circle(at: center, radius: 9))
            ctx.fill(cup, with: .color(BrutalistColor.bg))
            ctx.stroke(cup, with: .color(fg), lineWidth: 1.4)
            ctx.fill(Path(ellipseIn: Self.circle(at: center, radius: 3.2)), with: .color(fg))
            var pin = Path()
            pin.move(to: CGPoint(x: center.x, y: center.y - 9))
            pin.addLine(to: CGPoint(x: center.x, y: center.y - 30))
            ctx.stroke(pin, with: .color(fg), lineWidth: 1.2)
            var flag = Path()
            flag.move(to: CGPoint(x: center.x, y: center.y - 30))
            flag.addLine(to: CGPoint(x: center.x + 11, y: center.y - 27))
            flag.addLine(to: CGPoint(x: center.x, y: center.y - 24))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(fg))
        case .green:
            var pin = Path()
            pin.move(to: center)
            pin.addLine(to: CGPoint(x: center.x, y: center.y - 26))
            ctx.stroke(pin, with: .color(fg), lineWidth: 1.2)
            var flag = Path()
            flag.move(to: CGPoint(x: center.x, y: center.y - 26))
            flag.addLine(to: CGPoint(x: center.x + 12, y: center.y - 22))
            flag.addLine(to: CGPoint(x: center.x, y: center.y - 18))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(fg))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - 2.6, y: center.y - 2.6, width: 5.2, height: 5.2)),
                with: .color(fg),
                lineWidth: 1.3
            )
        case .fairway:
            var aim = Path()
            aim.move(to: CGPoint(x: center.x - 9, y: center.y))
            aim.addLine(to: CGPoint(x: center.x + 9, y: center.y))
            aim.move(to: CGPoint(x: center.x, y: center.y - 9))
            aim.addLine(to: CGPoint(x: center.x, y: center.y + 9))
            ctx.stroke(aim, with: .color(fg), lineWidth: 1.2)
        }
    }

    private struct AxisLabel {
        let text: String
        let point: CGPoint
        let anchor: UnitPoint
    }

    static func axisLabelTexts(for mode: Mode) -> [String] {
        switch mode {
        case .fairway, .green: ["LONG", "SHORT", "LEFT", "RIGHT"]
        case .putt: ["PAST", "SHORT"]
        }
    }

    private func axisLabels() -> [AxisLabel] {
        let labels = Self.axisLabelTexts(for: mode)
        let left = AxisLabel(text: "LEFT", point: CGPoint(x: Self.cx - 132, y: Self.cy + 3), anchor: .leading)
        let right = AxisLabel(text: "RIGHT", point: CGPoint(x: Self.cx + 132, y: Self.cy + 3), anchor: .trailing)
        switch mode {
        case .putt:
            return [
                AxisLabel(text: labels[0], point: CGPoint(x: Self.cx, y: Self.cy - 130), anchor: .center),
                AxisLabel(text: labels[1], point: CGPoint(x: Self.cx, y: Self.cy + 126), anchor: .center),
            ]
        case .fairway, .green:
            return [
                AxisLabel(text: labels[0], point: CGPoint(x: Self.cx, y: Self.cy - 130), anchor: .center),
                AxisLabel(text: labels[1], point: CGPoint(x: Self.cx, y: Self.cy + 126), anchor: .center),
                left, right,
            ]
        }
    }
}
