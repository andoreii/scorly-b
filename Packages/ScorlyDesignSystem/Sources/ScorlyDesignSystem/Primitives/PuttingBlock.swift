import SwiftUI

/// Putts count picker + per-putt distance editor, wrapped in a
/// `CollapsibleBlock`.
public struct PuttingBlock: View {
    private let badge: String
    @Binding private var putts: Int
    @Binding private var distances: [Int?]
    @Binding private var isOpen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        badge: String,
        putts: Binding<Int>,
        distances: Binding<[Int?]>,
        isOpen: Binding<Bool>
    ) {
        self.badge = badge
        _putts = putts
        _distances = distances
        _isOpen = isOpen
    }

    public var body: some View {
        CollapsibleBlock(badge: badge, title: "Putting", summary: summary, isOpen: $isOpen) {
            VStack(alignment: .leading, spacing: 6) {
                SubLabel("Putts")
                HStack(spacing: 6) {
                    ForEach(0...5, id: \.self) { count in
                        let active = putts == count
                        Button {
                            Haptics.medium()
                            withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                                putts = count
                                if distances.count > count {
                                    distances = Array(distances.prefix(count))
                                }
                            }
                        } label: {
                            Text("\(count)")
                                .font(BrutalistType.mono(.semibold, size: 14))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(active ? BrutalistColor.fg : .clear)
                                .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
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

    private var summary: String {
        if putts == 0 { return "0 PUTTS" }
        let filtered = distances.prefix(putts).compactMap { $0 }
        let base = "\(putts) PUTT\(putts == 1 ? "" : "S")"
        if filtered.isEmpty { return base }
        return base + " · " + filtered.map { "\($0)" }.joined(separator: " / ") + " FT"
    }
}
