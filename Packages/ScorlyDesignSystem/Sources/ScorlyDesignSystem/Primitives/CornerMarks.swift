import SwiftUI

/// Printer's-rule registration ticks at each corner of a panel.
/// Drawn as right-angle hairlines, non-interactive overlay.
public struct CornerMarks: View {
    private let size: CGFloat
    private let inset: CGFloat
    private let color: Color
    private let weight: CGFloat

    public init(
        size: CGFloat = 8,
        inset: CGFloat = 6,
        color: Color = BrutalistColor.rule,
        weight: CGFloat = 1
    ) {
        self.size = size
        self.inset = inset
        self.color = color
        self.weight = weight
    }

    public var body: some View {
        ZStack {
            corner(.topLeading)
            corner(.topTrailing)
            corner(.bottomTrailing)
            corner(.bottomLeading)
        }
        .allowsHitTesting(false)
    }

    private func corner(_ alignment: Alignment) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: size, height: weight)
            Rectangle().fill(color).frame(width: weight, height: size)
        }
        .frame(width: size, height: size)
        .rotationEffect(rotation(for: alignment))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(inset)
    }

    private func rotation(for alignment: Alignment) -> Angle {
        switch alignment {
        case .topLeading: return .degrees(0)
        case .topTrailing: return .degrees(90)
        case .bottomTrailing: return .degrees(180)
        case .bottomLeading: return .degrees(270)
        default: return .degrees(0)
        }
    }
}
