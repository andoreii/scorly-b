import SwiftUI

public struct AnimatedNumericText: View {
    private let value: String
    private let trigger: Int
    private let delay: Double

    @State private var displayedValue: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: String, trigger: Int, delay: Double = 0) {
        self.value = value
        self.trigger = trigger
        self.delay = delay
        _displayedValue = State(initialValue: Self.initialValue(for: value))
    }

    public var body: some View {
        Text(displayedValue)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(
                Motion.adaptive(Motion.easeOutQuint, reduceMotion: reduceMotion),
                value: displayedValue
            )
            .accessibilityLabel(value)
            .task(id: "\(trigger):\(value)") {
                await animateToTarget()
            }
    }

    nonisolated static func initialValue(for value: String) -> String {
        guard
            let firstDigit = value.firstIndex(where: \.isNumber),
            let lastDigit = value.lastIndex(where: \.isNumber)
        else { return value }

        let prefix = value[..<firstDigit]
        let suffix = value[value.index(after: lastDigit)...]
        let numericRange = firstDigit...lastDigit
        let numericPart = value[numericRange]
        let decimalPlaces = numericPart.firstIndex(of: ".").map { decimalIndex in
            numericPart[numericPart.index(after: decimalIndex)...].count(where: \.isNumber)
        } ?? 0
        let zero = decimalPlaces == 0
            ? "0"
            : "0." + String(repeating: "0", count: decimalPlaces)

        return prefix + zero + suffix
    }

    @MainActor
    private func animateToTarget() async {
        guard !reduceMotion else {
            displayedValue = value
            return
        }

        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }
        guard !Task.isCancelled else { return }

        withAnimation(Motion.easeOutQuint) {
            displayedValue = value
        }
    }
}
