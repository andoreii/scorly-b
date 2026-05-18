import SwiftUI

/// Scorecard notation:
/// - circle around number = under par (single ring = -1, double = -2+)
/// - square around number = over par (single box = +1, double = +2+)
/// - plain number         = par
/// - centered middle dot  = no score yet
public struct Pip: View {
    private let strokes: Int?
    private let par: Int
    private let size: CGFloat
    private let weight: CGFloat
    private let color: Color
    private let mutedColor: Color

    public init(
        strokes: Int?,
        par: Int,
        size: CGFloat = 20,
        weight: CGFloat = 1.2,
        color: Color = BrutalistColor.fg,
        mutedColor: Color = BrutalistColor.muted
    ) {
        self.strokes = strokes
        self.par = par
        self.size = size
        self.weight = weight
        self.color = color
        self.mutedColor = mutedColor
    }

    public var body: some View {
        ZStack {
            if let strokes {
                let d = strokes - par
                if d <= -2 {
                    Circle().stroke(color, lineWidth: weight)
                    Circle().stroke(color, lineWidth: weight).padding(3)
                } else if d == -1 {
                    Circle().stroke(color, lineWidth: weight)
                } else if d == 1 {
                    Rectangle().stroke(color, lineWidth: weight)
                } else if d >= 2 {
                    Rectangle().stroke(color, lineWidth: weight)
                    Rectangle().stroke(color, lineWidth: weight).padding(3)
                }
                Text("\(strokes)")
                    .font(BrutalistType.mono(.semibold, size: size > 22 ? 12 : 11))
                    .monospacedDigit()
                    .foregroundStyle(color)
            } else {
                Text("·")
                    .font(BrutalistType.mono(.medium, size: size > 22 ? 12 : 11))
                    .foregroundStyle(mutedColor)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Short caption for a score relative to par. Mirrors the `scoreLabel`
/// helper in the React design source.
public enum ScoreLabel {
    public static func text(strokes: Int, par: Int) -> String {
        let d = strokes - par
        if strokes == 1 { return "ACE" }
        switch d {
        case ..<(-1): return "EAGLE"
        case -1: return "BIRDIE"
        case 0: return "PAR"
        case 1: return "BOGEY"
        case 2: return "DOUBLE"
        case 3: return "TRIPLE"
        default: return "+\(d)"
        }
    }
}
