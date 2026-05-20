import SwiftUI

/// Brutalist integer slider. Hairline track with tick marks at every
/// step and a square ink knob — no glass, no shadows.
public struct BrutalistSlider: View {
    @Binding private var value: Int
    private let range: ClosedRange<Int>

    public init(value: Binding<Int>, in range: ClosedRange<Int>) {
        _value = value
        self.range = range
    }

    public var body: some View {
        GeometryReader { geo in
            let span = max(range.upperBound - range.lowerBound, 1)
            let knobSize: CGFloat = 22
            let trackWidth = max(0, geo.size.width - knobSize)
            let clampedValue = min(max(range.lowerBound, value), range.upperBound)
            let fraction = CGFloat(clampedValue - range.lowerBound) / CGFloat(span)
            let knobX = trackWidth * fraction
            let trackY = geo.size.height / 2

            ZStack(alignment: .leading) {
                // Tick marks (hairlines), drawn behind the track.
                ForEach(0...span, id: \.self) { i in
                    let x = (CGFloat(i) / CGFloat(span)) * trackWidth + knobSize / 2
                    let isMajor = i == 0 || i == span || i == span / 2
                    Rectangle()
                        .fill(BrutalistColor.hair)
                        .frame(width: 1, height: isMajor ? 10 : 6)
                        .position(x: x, y: trackY)
                }
                // Base track.
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(width: trackWidth, height: 1)
                    .position(x: knobSize / 2 + trackWidth / 2, y: trackY)
                // Filled portion up to the knob.
                Rectangle()
                    .fill(BrutalistColor.fg)
                    .frame(width: max(0, knobX), height: 2)
                    .position(x: knobSize / 2 + knobX / 2, y: trackY)
                // Square knob.
                Rectangle()
                    .fill(BrutalistColor.fg)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Rectangle()
                            .stroke(BrutalistColor.bg, lineWidth: 2)
                            .padding(3)
                    )
                    .position(x: knobX + knobSize / 2, y: trackY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let clampedX = min(max(0, g.location.x - knobSize / 2), trackWidth)
                        let f = clampedX / max(trackWidth, 1)
                        let newValue = range.lowerBound + Int((f * CGFloat(span)).rounded())
                        let bounded = min(max(range.lowerBound, newValue), range.upperBound)
                        if bounded != value {
                            Haptics.light()
                            value = bounded
                        }
                    }
            )
        }
        .frame(height: 32)
    }
}
