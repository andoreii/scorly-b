import SwiftUI

/// Tappable summary row for putting. Shows badge + "Putting" + the
/// putt count / distances summary. The caller is expected to present
/// a `PuttingEditor` in a bottom sheet on tap.
public struct PuttingBlock: View {
    private let badge: String
    private let putts: Int
    private let distances: [Int?]
    private let onTap: () -> Void

    public init(
        badge: String,
        putts: Int,
        distances: [Int?],
        onTap: @escaping () -> Void
    ) {
        self.badge = badge
        self.putts = putts
        self.distances = distances
        self.onTap = onTap
    }

    public var body: some View {
        HStack {
            HStack(spacing: 10) {
                Text(badge.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .opacity(0.7)
                Text("PUTTING")
                    .font(BrutalistType.blockTitle)
                    .kerning(0.6)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(summary.uppercased())
                    .font(BrutalistType.monoLabel)
                    .kerning(0.6)
                    .opacity(0.85)
                    .lineLimit(1)
                Text("→")
                    .font(BrutalistType.monoCaption)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .contentShape(Rectangle())
        .brutalistTap {
            Haptics.soft()
            onTap()
        }
    }

    private var summary: String {
        if putts == 0 { return "0 PUTTS" }
        let filtered = distances.prefix(putts).compactMap { $0 }
        let base = "\(putts) PUTT\(putts == 1 ? "" : "S")"
        if filtered.isEmpty { return base }
        return base + " · " + filtered.map { "\($0)" }.joined(separator: " / ") + " FT"
    }
}

/// Editor body for putts — count picker + per-putt distance editor.
/// Intended to live inside a bottom sheet.
public struct PuttingEditor: View {
    @Binding private var putts: Int
    @Binding private var distances: [Int?]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        putts: Binding<Int>,
        distances: Binding<[Int?]>
    ) {
        _putts = putts
        _distances = distances
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Putts")
            HStack(spacing: 6) {
                ForEach(0...5, id: \.self) { count in
                    let active = putts == count
                    Text("\(count)")
                        .font(BrutalistType.mono(.semibold, size: 14))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(active ? BrutalistColor.fg : .clear)
                        .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                        .brutalistTap {
                            Haptics.medium()
                            withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                                putts = count
                                if distances.count > count {
                                    distances = Array(distances.prefix(count))
                                }
                            }
                        }
                }
            }
            if putts > 0 {
                SubLabel("Distances")
                    .padding(.top, 14)
                PuttDistancesEditor(putts: putts, distances: $distances)
            }
        }
    }
}
