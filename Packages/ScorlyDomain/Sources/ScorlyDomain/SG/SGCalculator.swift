import Foundation

/// Strokes Gained math: SG = E(start) - E(end) - 1, where E is Broadie's
/// expected-strokes-to-hole-out function from `SGBenchmarkTable`.
/// Hole inputs are reconstructed into a per-stroke timeline; shots whose
/// start/end can't be pinned return `nil` SG and are excluded from totals.
public enum SGCalculator {
    // MARK: - Public API

    /// Strokes Gained for a sequence of holes (partial rounds OK).
    public static func compute(
        holes: [HoleSGInput],
        benchmarks: SGBenchmarkTable = .bundled
    ) -> RoundSGResult {
        let perHole = holes.map { computeHole($0, benchmarks: benchmarks) }
        let allShots = perHole.flatMap(\.shots)
        return RoundSGResult(holes: perHole, totals: aggregate(allShots))
    }

    /// Strokes Gained for a single hole.
    public static func computeHole(
        _ input: HoleSGInput,
        benchmarks: SGBenchmarkTable = .bundled
    ) -> HoleSGResult {
        let reconstructed = reconstruct(input)
        let shots = reconstructed.map { shot -> SGShotResult in
            SGShotResult(
                category: shot.category,
                strokesGained: shotSG(start: shot.start, end: shot.end, benchmarks: benchmarks)
            )
        }
        return HoleSGResult(shots: shots, totals: aggregate(shots))
    }

    // MARK: - Per-shot math

    /// SG for a single stroke. Returns `nil` if either endpoint is unknown.
    static func shotSG(
        start: ShotPosition?,
        end: ShotEnd,
        benchmarks: SGBenchmarkTable
    ) -> Decimal? {
        guard let start,
              let startE = benchmarks.expectedStrokes(lie: start.lie, distance: start.distance)
        else {
            return nil
        }
        let endE: Decimal
        switch end {
        case .holed:
            endE = 0
        case let .position(pos):
            guard let value = benchmarks.expectedStrokes(lie: pos.lie, distance: pos.distance) else {
                return nil
            }
            endE = value
        case .unknown:
            return nil
        }
        return startE - endE - 1
    }

    // MARK: - Aggregation

    /// Sums per-shot SG into per-category and overall totals. Nil shots are skipped.
    static func aggregate(_ shots: [SGShotResult]) -> SGTotals {
        var sums: [SGCategory: Decimal] = [:]
        for category in SGCategory.allCases {
            sums[category] = 0
        }
        for shot in shots {
            if let value = shot.strokesGained {
                sums[shot.category, default: 0] += value
            }
        }
        let ott = sums[.ott] ?? 0
        let app = sums[.app] ?? 0
        let arg = sums[.arg] ?? 0
        let putt = sums[.putt] ?? 0
        return SGTotals(ott: ott, app: app, arg: arg, putt: putt, total: ott + app + arg + putt)
    }

    // MARK: - Reconstruction

    /// `start` is `nil` and/or `end` is `.unknown` when the input doesn't pin the shot down.
    struct ReconstructedShot {
        let category: SGCategory
        let start: ShotPosition?
        let end: ShotEnd
    }

    /// Chains each shot's start to the previous shot's end where possible.
    static func reconstruct(_ input: HoleSGInput) -> [ReconstructedShot] {
        guard input.strokes >= 1 else { return [] }
        let putts = input.puttDistancesFeet ?? []
        let isPar3 = input.par == 3
        let argShots = input.argShots ?? []

        var shots: [ReconstructedShot] = []
        // Nil = chain broke; next shot's start falls back to user fields/defaults.
        var prevEnd: ShotPosition?

        let teeShot = reconstructTeeShot(input: input, putts: putts, isPar3: isPar3)
        shots.append(teeShot)
        prevEnd = positionFromEnd(teeShot.end)

        // Layup (par 5 only, when the user marked one).
        if input.par == 5, input.strokes >= 3,
           let layupLie = input.layupLie,
           let layupDistance = input.layupDistance,
           layupDistance > 0 {
            let layupEnd = ShotPosition(
                lie: sgBenchmark(for: layupLie),
                distance: Decimal(layupDistance)
            )
            shots.append(ReconstructedShot(
                category: .app,
                start: prevEnd,
                end: .position(layupEnd)
            ))
            prevEnd = layupEnd
        }

        // Approach (par 4 / par 5, if a shot remains after tee + optional layup).
        if !isPar3, input.strokes > shots.count {
            let approach = reconstructApproachShot(
                input: input,
                putts: putts,
                prevEnd: prevEnd,
                argShots: argShots,
                isHoledShot: putts.isEmpty && input.strokes == shots.count + 1
            )
            shots.append(approach)
            prevEnd = positionFromEnd(approach.end)
        }

        // ARG fillers between the approach (or par-3 tee) and the first putt.
        let argCount = max(0, input.strokes - shots.count - putts.count)
        for index in 0..<argCount {
            let isLast = index == argCount - 1
            let start = argStart(
                index: index,
                argShots: argShots,
                prevEnd: prevEnd,
                isFirstARG: index == 0,
                landingLie: argLandingLie(input: input, isPar3: isPar3),
                landingDistance: argLandingDistance(input: input, isPar3: isPar3)
            )
            let end: ShotEnd = {
                if isLast {
                    if let firstPutt = putts.first {
                        return .position(ShotPosition(lie: .green, distance: Decimal(firstPutt)))
                    }
                    return .holed
                }
                if let next = argShots[safe: index + 1] {
                    return .position(ShotPosition(
                        lie: sgBenchmark(for: next.lie),
                        distance: Decimal(next.distanceToPinYards)
                    ))
                }
                // No recorded next shot: assume a midpoint default rather than nilling out.
                return .position(ShotPosition(
                    lie: sgBenchmark(for: argLandingLie(input: input, isPar3: isPar3) ?? .fairway),
                    distance: Decimal(DefaultARGStart.intermediateDistance)
                ))
            }()
            shots.append(ReconstructedShot(category: .arg, start: start, end: end))
            prevEnd = positionFromEnd(end)
        }

        for (index, distanceFeet) in putts.enumerated() {
            let start = ShotPosition(lie: .green, distance: Decimal(distanceFeet))
            let end: ShotEnd
            if index == putts.count - 1 {
                end = .holed
            } else {
                end = .position(ShotPosition(lie: .green, distance: Decimal(putts[index + 1])))
            }
            shots.append(ReconstructedShot(category: .putt, start: start, end: end))
        }

        return shots
    }

    // MARK: - Reconstruction helpers

    private static func positionFromEnd(_ end: ShotEnd) -> ShotPosition? {
        switch end {
        case let .position(pos): pos
        case .holed, .unknown: nil
        }
    }

    /// Lie of the shot that landed off-green and set up the chip phase.
    /// Par 3: the tee shot. Par 4/5: the approach.
    private static func argLandingLie(input: HoleSGInput, isPar3: Bool) -> Lie? {
        isPar3 ? input.teeShotLie : input.approachLie
    }

    /// Reused for par 3 too: distance from pin where the approach-class shot finished.
    private static func argLandingDistance(input: HoleSGInput, isPar3: Bool) -> Int? {
        input.approachLandingDistance
    }

    /// Prefers explicit `argShots[index]`, then the previous shot's end,
    /// then the recorded landing distance (first ARG only), then a default.
    private static func argStart(
        index: Int,
        argShots: [ARGShot],
        prevEnd: ShotPosition?,
        isFirstARG: Bool,
        landingLie: Lie?,
        landingDistance: Int?
    ) -> ShotPosition? {
        if let userShot = argShots[safe: index] {
            return ShotPosition(
                lie: sgBenchmark(for: userShot.lie),
                distance: Decimal(userShot.distanceToPinYards)
            )
        }
        if let prevEnd {
            return prevEnd
        }
        if isFirstARG, let landingLie {
            let distance = landingDistance ?? DefaultARGStart.distance(forLie: landingLie)
            return ShotPosition(
                lie: sgBenchmark(for: landingLie),
                distance: Decimal(distance)
            )
        }
        return nil
    }

    private static func reconstructTeeShot(
        input: HoleSGInput,
        putts: [Int],
        isPar3: Bool
    ) -> ReconstructedShot {
        let category: SGCategory = isPar3 ? .app : .ott
        let startLie: SGBenchmarkLie = isPar3 ? .fairway : .tee
        let start = ShotPosition(lie: startLie, distance: Decimal(input.yardage))

        // 1-stroke hole = ace.
        if input.strokes == 1 {
            return ReconstructedShot(category: category, start: start, end: .holed)
        }

        guard let teeShotLie = input.teeShotLie else {
            return ReconstructedShot(category: category, start: start, end: .unknown)
        }
        let benchLie = sgBenchmark(for: teeShotLie)

        // Tee shot landed on green — first-putt distance pinpoints the end.
        if teeShotLie == .green {
            if let firstPutt = putts.first {
                let pos = ShotPosition(lie: .green, distance: Decimal(firstPutt))
                return ReconstructedShot(category: category, start: start, end: .position(pos))
            }
            return ReconstructedShot(category: category, start: start, end: .unknown)
        }

        // Off-green tee shot: par 4/5 uses teeShotDistance; par 3 routes
        // through the approach-landing field from the par-3 tee editor.
        if isPar3 {
            if let landing = input.approachLandingDistance, landing > 0 {
                let pos = ShotPosition(lie: benchLie, distance: Decimal(landing))
                return ReconstructedShot(category: category, start: start, end: .position(pos))
            }
            let defaulted = DefaultARGStart.distance(forLie: teeShotLie)
            let pos = ShotPosition(lie: benchLie, distance: Decimal(defaulted))
            return ReconstructedShot(category: category, start: start, end: .position(pos))
        }
        guard let teeShotDistance = input.teeShotDistance else {
            return ReconstructedShot(category: category, start: start, end: .unknown)
        }
        let remaining = Decimal(input.yardage - teeShotDistance)
        guard remaining > 0 else {
            return ReconstructedShot(category: category, start: start, end: .unknown)
        }
        let pos = ShotPosition(lie: benchLie, distance: remaining)
        return ReconstructedShot(category: category, start: start, end: .position(pos))
    }

    private static func reconstructApproachShot(
        input: HoleSGInput,
        putts: [Int],
        prevEnd: ShotPosition?,
        argShots: [ARGShot],
        isHoledShot: Bool
    ) -> ReconstructedShot {
        // Prefers chain continuity (prevEnd); falls back to tee lie + approachDistance.
        let start: ShotPosition? = {
            if let prevEnd { return prevEnd }
            guard let teeShotLie = input.teeShotLie,
                  let approachDistance = input.approachDistance,
                  approachDistance > 0
            else {
                return nil
            }
            return ShotPosition(
                lie: sgBenchmark(for: teeShotLie),
                distance: Decimal(approachDistance)
            )
        }()

        let end: ShotEnd
        if let approachLie = input.approachLie {
            if approachLie == .green {
                if let firstPutt = putts.first {
                    end = .position(ShotPosition(lie: .green, distance: Decimal(firstPutt)))
                } else if isHoledShot {
                    end = .holed
                } else {
                    end = .unknown
                }
            } else {
                // Prefer explicit landing data, then first recorded chip start, then a default.
                let landingDistance = input.approachLandingDistance
                    ?? argShots.first?.distanceToPinYards
                    ?? DefaultARGStart.distance(forLie: approachLie)
                end = .position(ShotPosition(
                    lie: sgBenchmark(for: approachLie),
                    distance: Decimal(landingDistance)
                ))
            }
        } else {
            end = .unknown
        }

        return ReconstructedShot(category: .app, start: start, end: end)
    }

    /// Maps `Lie` to the 5 non-tee benchmark categories.
    static func sgBenchmark(for lie: Lie) -> SGBenchmarkLie {
        switch lie {
        case .fairway: .fairway
        case .roughLeft, .roughRight: .rough
        case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong: .sand
        case .recoveryLeft, .recoveryRight, .recoveryShort, .recoveryLong: .recovery
        case .green: .green
        }
    }
}

/// Default start distance (yards) for an around-the-green shot when the
/// user didn't record it, based on Broadie's typical greenside-miss distributions.
enum DefaultARGStart {
    static func distance(forLie lie: Lie) -> Int {
        switch lie {
        case .fairway: 35
        case .roughLeft, .roughRight: 20
        case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong: 12
        case .recoveryLeft, .recoveryRight, .recoveryShort, .recoveryLong: 30
        case .green: 0
        }
    }

    /// Fallback for an intermediate ARG shot with no recorded chain.
    static let intermediateDistance = 10
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Public input + output types

/// One hole's worth of input data.
public struct HoleSGInput: Sendable, Equatable {
    public let par: Int
    /// Hole length, yards.
    public let yardage: Int
    /// `nil` means the user didn't record a lie for this hole (older rounds, partial data).
    public let teeShotLie: Lie?
    /// Distance the tee shot travelled, in yards (not the distance remaining).
    public let teeShotDistance: Int?
    /// Where the approach landed. Unused on par 3 (the tee shot is the approach).
    public let approachLie: Lie?
    /// Distance remaining when the approach was taken, in yards.
    public let approachDistance: Int?
    /// One entry per putt taken, in feet. Empty if no putts (chip-in / hole-out).
    public let puttDistancesFeet: [Int]?
    public let strokes: Int
    /// Distance from the pin where the approach finished, in yards.
    /// Only meaningful when `approachLie` is non-green.
    public let approachLandingDistance: Int?
    /// One entry per around-the-green shot, ordered by stroke. Missing
    /// entries fall back to lie-based defaults.
    public let argShots: [ARGShot]?
    /// Par-5 only: lie where the layup landed; presence adds a third pre-green shot.
    public let layupLie: Lie?
    /// Par-5 only: yards remaining to the pin after the layup.
    public let layupDistance: Int?

    public init(
        par: Int,
        yardage: Int,
        teeShotLie: Lie? = nil,
        teeShotDistance: Int? = nil,
        approachLie: Lie? = nil,
        approachDistance: Int? = nil,
        puttDistancesFeet: [Int]? = nil,
        strokes: Int,
        approachLandingDistance: Int? = nil,
        argShots: [ARGShot]? = nil,
        layupLie: Lie? = nil,
        layupDistance: Int? = nil
    ) {
        self.par = par
        self.yardage = yardage
        self.teeShotLie = teeShotLie
        self.teeShotDistance = teeShotDistance
        self.approachLie = approachLie
        self.approachDistance = approachDistance
        self.puttDistancesFeet = puttDistancesFeet
        self.strokes = strokes
        self.approachLandingDistance = approachLandingDistance
        self.argShots = argShots
        self.layupLie = layupLie
        self.layupDistance = layupDistance
    }
}

/// One shot's SG result.
public struct SGShotResult: Sendable, Equatable {
    public let category: SGCategory
    /// `nil` when the shot's start or end position couldn't be
    /// reconstructed from the input.
    public let strokesGained: Decimal?

    public init(category: SGCategory, strokesGained: Decimal?) {
        self.category = category
        self.strokesGained = strokesGained
    }
}

/// Per-category SG totals plus the overall total.
public struct SGTotals: Sendable, Equatable {
    public let ott: Decimal
    public let app: Decimal
    public let arg: Decimal
    public let putt: Decimal
    public let total: Decimal

    public init(ott: Decimal, app: Decimal, arg: Decimal, putt: Decimal, total: Decimal) {
        self.ott = ott
        self.app = app
        self.arg = arg
        self.putt = putt
        self.total = total
    }
}

/// SG result for a single hole.
public struct HoleSGResult: Sendable, Equatable {
    public let shots: [SGShotResult]
    public let totals: SGTotals

    public init(shots: [SGShotResult], totals: SGTotals) {
        self.shots = shots
        self.totals = totals
    }
}

/// SG result for a complete (or partial) round.
public struct RoundSGResult: Sendable, Equatable {
    public let holes: [HoleSGResult]
    public let totals: SGTotals

    public init(holes: [HoleSGResult], totals: SGTotals) {
        self.holes = holes
        self.totals = totals
    }
}

// MARK: - Internal positional types

/// A shot's starting or ending position.
struct ShotPosition: Equatable {
    let lie: SGBenchmarkLie
    /// Yards for all lies except `.green`, where it's feet.
    let distance: Decimal
}

/// Where a shot ended. Distinct from `ShotPosition?`: "in the hole" vs "unknown".
enum ShotEnd: Equatable {
    case position(ShotPosition)
    case holed
    case unknown
}
