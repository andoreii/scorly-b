import SwiftUI

/// Composite block for a single shot (tee or approach). Lie keypad +
/// club grid + distance wheel, wrapped in a `CollapsibleBlock`.
public struct ShotBlock: View {
    private let badge: String
    private let title: String
    private let target: String
    private let clubs: [String]
    private let distanceRange: ClosedRange<Int>
    @Binding private var lie: String?
    @Binding private var club: String?
    @Binding private var distance: Int?
    @Binding private var isOpen: Bool

    public init(
        badge: String,
        title: String,
        target: String,
        clubs: [String],
        distanceRange: ClosedRange<Int> = 0...400,
        lie: Binding<String?>,
        club: Binding<String?>,
        distance: Binding<Int?>,
        isOpen: Binding<Bool>
    ) {
        self.badge = badge
        self.title = title
        self.target = target
        self.clubs = clubs
        self.distanceRange = distanceRange
        _lie = lie
        _club = club
        _distance = distance
        _isOpen = isOpen
    }

    public var body: some View {
        CollapsibleBlock(badge: badge, title: title, summary: summary, isOpen: $isOpen) {
            VStack(alignment: .leading, spacing: 6) {
                SubLabel("Result")
                LieKeypad(value: $lie, target: target)
                SubLabel("Club").padding(.top, 14)
                ClubGrid(options: clubs, selection: $club)
                SubLabel("Distance").padding(.top, 14)
                DistanceWheel(value: $distance, range: distanceRange, step: 5, unit: "YDS")
            }
        }
    }

    private var summary: String {
        var parts: [String] = []
        parts.append(lie?.uppercased() ?? "—")
        if let club { parts.append(club.uppercased()) }
        if let distance { parts.append("\(distance)Y") }
        return parts.joined(separator: " · ")
    }
}
