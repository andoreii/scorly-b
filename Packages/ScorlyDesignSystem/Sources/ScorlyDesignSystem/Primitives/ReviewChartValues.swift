import Foundation

public struct AccuracyRoseValues: Sendable, Equatable {
    public struct DirectionStack: Sendable, Equatable, Hashable {
        public var clean: Int
        public var bunker: Int
        public var water: Int
        public var ob: Int

        public init(clean: Int = 0, bunker: Int = 0, water: Int = 0, ob: Int = 0) {
            self.clean = clean
            self.bunker = bunker
            self.water = water
            self.ob = ob
        }

        public var total: Int {
            clean + bunker + water + ob
        }
    }

    public enum Direction: String, CaseIterable, Sendable {
        case left
        case right
        case long
        case short
    }

    public let hitRate: Double?
    public let opportunities: Int
    public let totalMisses: Int
    public let byDirection: [Direction: DirectionStack]

    public init(
        hitRate: Double?,
        opportunities: Int,
        totalMisses: Int,
        byDirection: [Direction: DirectionStack]
    ) {
        self.hitRate = hitRate
        self.opportunities = opportunities
        self.totalMisses = totalMisses
        self.byDirection = byDirection
    }

    public static let empty = Self(hitRate: nil, opportunities: 0, totalMisses: 0, byDirection: [:])

    public func petalLength(for direction: Direction) -> Double {
        let total = byDirection[direction]?.total ?? 0
        let maxTotal = Direction.allCases.map { byDirection[$0]?.total ?? 0 }.max() ?? 0
        guard maxTotal > 0 else { return 0 }
        return Double(total) / Double(maxTotal)
    }

    public func percent(for direction: Direction) -> Double {
        guard totalMisses > 0 else { return 0 }
        return Double(byDirection[direction]?.total ?? 0) / Double(totalMisses)
    }
}

public enum PuttDistanceBucket: String, CaseIterable, Sendable, Identifiable {
    case feet0to3 = "0–3"
    case feet4to6 = "4–6"
    case feet7to10 = "7–10"
    case feet11to15 = "11–15"
    case feet16to20 = "16–20"
    case feet21to30 = "21–30"
    case feet31plus = "31+"

    public var id: String {
        rawValue
    }

    public static func bucket(forFeet feet: Int) -> Self {
        switch feet {
        case ...3: .feet0to3
        case 4...6: .feet4to6
        case 7...10: .feet7to10
        case 11...15: .feet11to15
        case 16...20: .feet16to20
        case 21...30: .feet21to30
        default: .feet31plus
        }
    }
}

public struct PuttMakeValues: Sendable, Equatable {
    public let made: Int
    public let attempted: Int

    public init(made: Int = 0, attempted: Int = 0) {
        self.made = made
        self.attempted = attempted
    }

    public var rate: Double? {
        attempted > 0 ? Double(made) / Double(attempted) : nil
    }
}

public struct PuttingAveragePoint: Sendable, Equatable, Identifiable {
    public let holeNumber: Int
    public let averagePuttsPerHole: Double

    public init(holeNumber: Int, averagePuttsPerHole: Double) {
        self.holeNumber = holeNumber
        self.averagePuttsPerHole = averagePuttsPerHole
    }

    public var id: Int {
        holeNumber
    }
}

public struct PuttDistributionValues: Sendable, Equatable {
    public let onePutt: Int
    public let twoPutt: Int
    public let threePuttPlus: Int

    public init(onePutt: Int = 0, twoPutt: Int = 0, threePuttPlus: Int = 0) {
        self.onePutt = onePutt
        self.twoPutt = twoPutt
        self.threePuttPlus = threePuttPlus
    }

    public var total: Int {
        onePutt + twoPutt + threePuttPlus
    }

    public func share(_ count: Int) -> Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
}

public enum ScoringOutcome: String, CaseIterable, Sendable, Identifiable {
    case birdiePlus
    case par
    case bogey
    case doublePlus

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .birdiePlus: "BIRDIE OR BETTER"
        case .par: "PAR"
        case .bogey: "BOGEY"
        case .doublePlus: "DOUBLE OR WORSE"
        }
    }

    public static func outcome(forVsPar difference: Int) -> Self {
        switch difference {
        case ...(-1): .birdiePlus
        case 0: .par
        case 1: .bogey
        default: .doublePlus
        }
    }
}

public struct ScorecardHoleValues: Sendable, Equatable, Identifiable {
    public let number: Int
    public let par: Int
    public let strokes: Int?

    public init(number: Int, par: Int, strokes: Int?) {
        self.number = number
        self.par = par
        self.strokes = strokes
    }

    public var id: Int {
        number
    }
}

public struct ScorecardGroupValues: Sendable, Equatable, Identifiable {
    public let label: String
    public let holes: [ScorecardHoleValues]

    public init(label: String, holes: [ScorecardHoleValues]) {
        self.label = label
        self.holes = holes
    }

    public var id: String {
        label
    }

    public var strokes: Int {
        holes.compactMap(\.strokes).reduce(0, +)
    }

    public var playedPar: Int {
        holes.filter { $0.strokes != nil }.reduce(0) { $0 + $1.par }
    }
}
