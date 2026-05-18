import SwiftUI

/// Standard label + value pair. Mono uppercase label, sans value.
public struct Stat: View {
    private let label: String
    private let value: String
    private let mutedColor: Color

    public init(label: String, value: String, mutedColor: Color = BrutalistColor.muted) {
        self.label = label
        self.value = value
        self.mutedColor = mutedColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(mutedColor)
            Text(value)
                .font(BrutalistType.statValue)
                .monospacedDigit()
        }
    }
}

/// Larger label + value, used in stat strips on Confirm and History.
/// `bd: true` draws a 1px leading border to separate from the prior
/// cell in a row.
public struct BigStat: View {
    private let label: String
    private let value: String
    private let sub: String?
    private let drawBorder: Bool

    public init(label: String, value: String, sub: String? = nil, drawBorder: Bool = false) {
        self.label = label
        self.value = value
        self.sub = sub
        self.drawBorder = drawBorder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.bigStat)
                .kerning(-0.8)
                .monospacedDigit()
            if let sub {
                Text(sub.uppercased())
                    .font(BrutalistType.monoMicro)
                    .foregroundStyle(BrutalistColor.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(alignment: .leading) {
            if drawBorder {
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

/// Compact label + value for grid cells (history footer, course
/// picker info row).
public struct MiniStat: View {
    private let label: String
    private let value: String
    private let useMono: Bool

    public init(label: String, value: String, useMono: Bool = false) {
        self.label = label
        self.value = value
        self.useMono = useMono
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(useMono ? BrutalistType.mono(.semibold, size: 13) : BrutalistType.inputBody)
                .monospacedDigit()
        }
    }
}

/// Smallest variant — picker card metadata row.
public struct Mini: View {
    private let label: String
    private let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.mono(.semibold, size: 12))
                .kerning(0.4)
                .monospacedDigit()
        }
    }
}
