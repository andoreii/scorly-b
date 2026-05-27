import SwiftUI

/// Horizontal scroll-snap distance picker. Big tabular numeric
/// readout at the top, ticked strip below, center indicator.
/// Mirrors the React `DistanceWheel` component.
public struct DistanceWheel: View {
    @Binding private var value: Int?
    private let range: ClosedRange<Int>
    private let step: Int
    private let majorEvery: Int
    private let unit: String
    private let majorTopLabel: ((Int) -> String?)?
    private let itemWidth: CGFloat = 30

    @State private var lastTickValue: Int?

    public init(
        value: Binding<Int?>,
        range: ClosedRange<Int> = 0...400,
        step: Int = 5,
        majorEvery: Int? = nil,
        unit: String = "YDS",
        majorTopLabel: ((Int) -> String?)? = nil
    ) {
        _value = value
        self.range = range
        self.step = step
        self.majorEvery = majorEvery ?? (step * 4)
        self.unit = unit
        self.majorTopLabel = majorTopLabel
    }

    private var wheelHeight: CGFloat {
        majorTopLabel != nil ? 100 : 90
    }

    public var body: some View {
        let values = stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
        ZStack {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(value.map { "\($0)" } ?? "—")
                        .font(BrutalistType.bigStat)
                        .kerning(-1)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(BrutalistType.mono(.medium, size: 10))
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
                wheel(values: values)
            }
            // Center indicator line
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 2, height: 26)
                .padding(.bottom, 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
        }
        .frame(height: wheelHeight)
        .background(BrutalistColor.panel)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var tickStripHeight: CGFloat {
        majorTopLabel != nil ? 54 : 44
    }

    private func wheel(values: [Int]) -> some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(values, id: \.self) { v in
                        tick(v).frame(width: itemWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: scrollBinding(values: values))
            .scrollTargetBehavior(.viewAligned)
            .safeAreaPadding(.horizontal, max(0, (geo.size.width - itemWidth) / 2))
        }
        .frame(height: tickStripHeight)
    }

    private func scrollBinding(values: [Int]) -> Binding<Int?> {
        Binding<Int?>(
            get: { value ?? values.first },
            set: { newValue in
                guard let newValue, value != newValue else { return }
                value = newValue
                if newValue != lastTickValue {
                    lastTickValue = newValue
                    Haptics.soft()
                }
            }
        )
    }

    private func tick(_ v: Int) -> some View {
        let isMajor = v % majorEvery == 0
        let hasTopLabel = majorTopLabel != nil
        let topLabel: String? = hasTopLabel ? majorTopLabel.flatMap { $0(v) } : nil
        let labelHeight: CGFloat = 10
        let gap: CGFloat = 6
        return VStack(spacing: gap) {
            if hasTopLabel {
                if isMajor, let topLabel {
                    Text(topLabel)
                        .font(BrutalistType.mono(.medium, size: 8))
                        .foregroundStyle(BrutalistColor.muted)
                        .frame(height: labelHeight)
                } else {
                    Color.clear.frame(height: labelHeight)
                }
            }
            Rectangle()
                .fill(BrutalistColor.fg.opacity(isMajor ? 0.7 : 0.25))
                .frame(width: 1, height: isMajor ? 18 : 10)
            if isMajor {
                Text("\(v)")
                    .font(BrutalistType.mono(.medium, size: 8))
                    .foregroundStyle(BrutalistColor.muted)
                    .frame(height: labelHeight)
            } else {
                Color.clear.frame(height: labelHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: tickStripHeight)
    }
}
