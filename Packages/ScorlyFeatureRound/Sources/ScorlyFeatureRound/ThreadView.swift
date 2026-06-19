import ScorlyDesignSystem
import SwiftUI

/// "The Thread" — the tee→cup list of shot nodes. Logged shots show a
/// mini tracer + result; the single next shot shows as a dashed
/// "tap to open" box. Tapping any row raises the input sheet. Mirrors
/// the React `RPIThread` / `RPIThreadRow`.
struct ThreadView: View {
    let nodes: [RoundPlayState.ThreadNode]
    let editingSlot: RoundPlayState.ShotSlot?
    let done: Bool
    let onOpen: (RoundPlayState.ShotSlot) -> Void

    private var loggedCount: Int {
        nodes.filter(\.logged).count
    }

    private var statusText: String {
        if done { return "HOLED IN \(loggedCount)" }
        if loggedCount == 0 { return "TEE IT UP" }
        return "\(loggedCount) STROKE\(loggedCount > 1 ? "S" : "")"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THE THREAD · TEE → CUP")
                    .font(BrutalistType.mono(.semibold, size: 9))
                    .kerning(1.2)
                Spacer()
                Text(statusText)
                    .font(BrutalistType.mono(.medium, size: 8.5))
                    .kerning(0.8)
                    .foregroundStyle(done ? BrutalistColor.acc : BrutalistColor.muted)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(BrutalistColor.hair).frame(height: 1) }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { position, node in
                        ThreadRow(
                            node: node,
                            isFirst: position == 0,
                            isLast: position == nodes.count - 1,
                            editing: node.slot == editingSlot
                        ) { onOpen(node.slot) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 1.6))
    }
}

private struct ThreadRow: View {
    let node: RoundPlayState.ThreadNode
    let isFirst: Bool
    let isLast: Bool
    let editing: Bool
    let onTap: () -> Void

    private var isPutt: Bool {
        node.mode == .putt
    }

    private var nodeColor: Color {
        node.logged ? (node.good ? BrutalistColor.acc : BrutalistColor.fg) : BrutalistColor.muted
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 11) {
                spine
                if node.logged { loggedBody } else { openBody }
            }
            .frame(minHeight: 68)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var spine: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : BrutalistColor.hair).frame(width: 1.4)
                Rectangle().fill(isLast ? Color.clear : BrutalistColor.hair).frame(width: 1.4)
            }
            nodeBadge
        }
        .frame(width: 30)
    }

    private var nodeBadge: some View {
        Text(String(format: "%02d", node.displayIndex))
            .font(BrutalistType.mono(.semibold, size: 10))
            .monospacedDigit()
            .foregroundStyle(nodeColor)
            .frame(width: 26, height: 26)
            .background(node.good ? BrutalistColor.accFill : (editing ? BrutalistColor.panel : BrutalistColor.bg))
            .overlay(
                Group {
                    if isPutt {
                        Circle().strokeBorder(nodeColor, style: strokeStyle)
                    } else {
                        Rectangle().strokeBorder(nodeColor, style: strokeStyle)
                    }
                }
            )
    }

    private var strokeStyle: StrokeStyle {
        node.logged ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1.5, dash: [3, 2])
    }

    private var loggedBody: some View {
        HStack(spacing: 11) {
            ThreadTracer(offset: node.directionOffset, good: node.good)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(node.title.uppercased())
                        .font(BrutalistType.mono(.semibold, size: 9))
                        .kerning(1)
                        .foregroundStyle(BrutalistColor.muted)
                    if let distance = node.distance {
                        Text("\(distance)")
                            .font(BrutalistType.sans(.bold, size: 22))
                            .kerning(-0.6)
                            .monospacedDigit()
                        Text(node.unit == .feet ? "FT" : "YDS")
                            .font(BrutalistType.mono(.semibold, size: 9))
                            .foregroundStyle(BrutalistColor.muted)
                    }
                    Spacer(minLength: 0)
                    if let club = node.club {
                        Text(club.uppercased())
                            .font(BrutalistType.mono(.medium, size: 9))
                            .foregroundStyle(BrutalistColor.dim)
                    }
                }
                if let label = node.resultLabel {
                    HStack {
                        Spacer(minLength: 0)
                        resultChip(label, good: node.good)
                    }
                }
            }
        }
    }

    private var openBody: some View {
        HStack(spacing: 10) {
            Text("+")
                .font(BrutalistType.mono(.regular, size: 15))
            Text("TAP TO OPEN SHOT")
                .font(BrutalistType.mono(.semibold, size: 10))
                .kerning(1)
            Spacer(minLength: 0)
            Text("→")
                .font(BrutalistType.mono(.medium, size: 13))
                .foregroundStyle(BrutalistColor.muted)
        }
        .foregroundStyle(BrutalistColor.fg)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(editing ? BrutalistColor.fg.opacity(0.03) : .clear)
        .overlay(Rectangle().strokeBorder(BrutalistColor.muted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    private func resultChip(_ label: String, good: Bool) -> some View {
        Text(label)
            .font(BrutalistType.mono(.semibold, size: 9))
            .kerning(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(good ? BrutalistColor.acc : .clear)
            .foregroundStyle(good ? BrutalistColor.bg : BrutalistColor.fg)
            .overlay(Rectangle().stroke(good ? BrutalistColor.acc : BrutalistColor.fg, lineWidth: 1))
    }
}
