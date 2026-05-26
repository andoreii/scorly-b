import SwiftUI

/// Tappable summary row for a single shot. Renders badge + title on
/// the left, a chip summary (lie · club · distance) on the right, and
/// invokes `onTap` when pressed. The caller is expected to present an
/// editor (bottom sheet) — this primitive no longer expands inline.
public struct ShotBlock: View {
    public enum FieldOrder {
        case resultFirst
        case distanceFirst
    }

    private let badge: String
    private let title: String
    @Binding private var lie: String?
    @Binding private var lieModifier: String?
    @Binding private var club: String?
    @Binding private var distance: Int?
    private let onTap: () -> Void

    public init(
        badge: String,
        title: String,
        lie: Binding<String?>,
        lieModifier: Binding<String?>,
        club: Binding<String?>,
        distance: Binding<Int?>,
        onTap: @escaping () -> Void
    ) {
        self.badge = badge
        self.title = title
        _lie = lie
        _lieModifier = lieModifier
        _club = club
        _distance = distance
        self.onTap = onTap
    }

    public var body: some View {
        HStack {
            HStack(spacing: 10) {
                Text(badge.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .opacity(0.7)
                Text(title.uppercased())
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
        var parts: [String] = []
        if let lie {
            if let lieModifier {
                parts.append("\(lie.uppercased()) · \(lieModifier.uppercased())")
            } else {
                parts.append(lie.uppercased())
            }
        } else {
            parts.append("—")
        }
        if let club { parts.append(club.uppercased()) }
        if let distance { parts.append("\(distance)Y") }
        return parts.joined(separator: " · ")
    }
}

/// Editor body for a shot — lie keypad + club grid + distance wheel,
/// ordered by `fieldOrder`. Intended to live inside a bottom sheet
/// presented from a `ShotBlock` summary row.
public struct ShotEditor: View {
    private let target: String
    private let clubs: [String]
    private let clubDistanceDefaults: [String: Int]
    private let distanceRange: ClosedRange<Int>
    private let distanceLabel: String
    private let fieldOrder: ShotBlock.FieldOrder
    private let extraTopRight: LieKeypad.AuxButton?
    @Binding private var lie: String?
    @Binding private var lieModifier: String?
    @Binding private var club: String?
    @Binding private var distance: Int?

    public init(
        target: String,
        clubs: [String],
        clubDistanceDefaults: [String: Int] = [:],
        distanceRange: ClosedRange<Int> = 0...400,
        distanceLabel: String = "Distance",
        fieldOrder: ShotBlock.FieldOrder = .resultFirst,
        extraTopRight: LieKeypad.AuxButton? = nil,
        lie: Binding<String?>,
        lieModifier: Binding<String?>,
        club: Binding<String?>,
        distance: Binding<Int?>
    ) {
        self.target = target
        self.clubs = clubs
        self.clubDistanceDefaults = clubDistanceDefaults
        self.distanceRange = distanceRange
        self.distanceLabel = distanceLabel
        self.fieldOrder = fieldOrder
        self.extraTopRight = extraTopRight
        _lie = lie
        _lieModifier = lieModifier
        _club = club
        _distance = distance
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch fieldOrder {
            case .resultFirst:
                resultSection
                clubSection.padding(.top, 14)
                distanceSection.padding(.top, 14)
            case .distanceFirst:
                distanceSection
                clubSection.padding(.top, 14)
                resultSection.padding(.top, 14)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Result")
            LieKeypad(value: $lie, modifier: $lieModifier, target: target, extraTopRight: extraTopRight)
        }
    }

    @ViewBuilder
    private var clubSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Club")
            ClubGrid(options: clubs, selection: $club)
                .onChange(of: club, initial: false) { _, newValue in
                    guard let newValue, let mapped = clubDistanceDefaults[newValue] else { return }
                    distance = mapped
                }
        }
    }

    @ViewBuilder
    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel(distanceLabel)
            DistanceWheel(value: $distance, range: distanceRange, step: 1, unit: "YDS")
        }
    }
}
