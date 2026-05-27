import ScorlyDesignSystem
import SwiftUI

/// The marquee Trends card: an eight-axis brutalist skills radar.
///
/// Always-on view: a header (label + title + overall score), a meta
/// row, and the radar polygon. There's no comparison polygon (that's
/// the round-detail view's job) and no expand/collapse — the trends
/// page already aggregates a sample window, so the polygon IS the
/// "season" read.
public struct SkillsRadarCard: View {
    private let axes: [RadarAxis]

    public init(axes: [RadarAxis]) {
        self.axes = axes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
                .padding(.vertical, 12)
            metaRow
            chart
                .padding(.top, BrutalistSpacing.s)
            summaryStrip
                .padding(.top, BrutalistSpacing.l)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BrutalistColor.bg)
        .overlay(CornerMarks())
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SKILLS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text("Skills profile")
                    .font(BrutalistType.sans(.bold, size: 24))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("OVERALL")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.dim)
                Text("\(overall)")
                    .font(BrutalistType.sans(.bold, size: 34))
                    .kerning(-1.2)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                Text("/ 100")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                    .padding(.top, 2)
            }
        }
    }

    private var metaRow: some View {
        HStack {
            Text("\(axes.count) AREAS · 0–100")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            Spacer()
        }
    }

    // MARK: - Chart

    private var chart: some View {
        // Extend the chart edge-to-edge of the card by negating the
        // card's horizontal padding so the polygon can grow as large
        // as the card width allows. Side labels ("TROUBLE", "DRIVING")
        // are positioned right against the card edge with just a few
        // points of breathing room — handled by the Geometry's
        // adaptive labelRadius cap.
        SkillsRadarChart(axes: axes)
            .aspectRatio(1.1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, -16)
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let strongest = RadarAxis.strongest(in: axes)
        let weakest = axes.min { $0.windowValue < $1.windowValue }
        let biggest = axes.max { abs($0.delta) < abs($1.delta) }
        return HStack(spacing: 0) {
            summaryCell(label: "STRONGEST", axis: strongest, tone: .positive, drawDivider: false)
            summaryCell(label: "WEAKEST", axis: weakest, tone: .negative, drawDivider: true)
            summaryCell(label: "BIGGEST MOVER", axis: biggest, tone: .movement, drawDivider: true)
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func summaryCell(
        label: String,
        axis: RadarAxis?,
        tone: SummaryTone,
        drawDivider: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(axis?.label ?? "—")
                .font(BrutalistType.sans(.semibold, size: 13))
                .kerning(-0.2)
                .foregroundStyle(BrutalistColor.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(axis.map { "\($0.windowValue)" } ?? "—")
                    .font(BrutalistType.mono(.semibold, size: 22))
                    .monospacedDigit()
                    .foregroundStyle(valueColor(for: axis, tone: tone))
                Text(axis.map { deltaString($0.delta) } ?? "—")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.4)
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .overlay(alignment: .leading) {
            if drawDivider {
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(width: 1)
            }
        }
    }

    private enum SummaryTone {
        case positive
        case negative
        case movement
    }

    private func valueColor(for axis: RadarAxis?, tone: SummaryTone) -> Color {
        guard let axis else { return BrutalistColor.fg }
        switch tone {
        case .positive: return BrutalistColor.sgPos
        case .negative: return BrutalistColor.sgNeg
        case .movement:
            switch axis.trendDirection {
            case .up: return BrutalistColor.sgPos
            case .down: return BrutalistColor.sgNeg
            case .unchanged: return BrutalistColor.fg
            }
        }
    }

    private func deltaString(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta) VS AVG" }
        if delta < 0 { return "\(delta) VS AVG" }
        return "0 VS AVG"
    }

    // MARK: - Helpers

    private var overall: Int {
        guard !axes.isEmpty else { return 0 }
        let total = axes.reduce(0) { $0 + $1.windowValue }
        return Int((Double(total) / Double(axes.count)).rounded())
    }

    private var divider: some View {
        Rectangle()
            .fill(BrutalistColor.rule)
            .frame(height: 1)
    }
}
