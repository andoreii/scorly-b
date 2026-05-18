import Foundation

/// Strokes Gained math, defined per shot and aggregated per hole / round.
///
/// **Per-shot SG.** For a stroke that starts at position `(L, D)` and
/// ends at position `(L', D')`, the strokes gained is:
///
///     SG = E(L, D) − E(L', D') − 1
///
/// where `E` is Broadie's expected-strokes-to-hole-out function from
/// `SGBenchmarkTable`. For the holed shot, `E(L', D') = 0`, so the
/// formula collapses to `E(L, D) − 1`.
///
/// **Reconstruction.** Hole inputs come from the v1 / v2 hole-stat
/// shape (tee shot lie + distance, approach lie + distance,
/// putt-distance list, total stroke count). `SGCalculator` walks the
/// stroke timeline:
///
/// 1. Tee shot (always present if `strokes ≥ 1`). Categorised `.ott`
///    on par 4 / par 5; `.app` on par 3 (tee shot is the approach).
/// 2. Approach (par 4 / par 5 only, if `strokes ≥ 2`). Always `.app`.
/// 3. ARG fillers — `strokes − 1 − puttCount` (par 3) or
///    `strokes − 2 − puttCount` (par 4 / par 5) shots between the
///    approach and the first putt. All categorised `.arg`.
/// 4. Putts — one per entry in `puttDistancesFeet`. All `.putt`.
///
/// **Missing data → `nil` SG.** Any shot whose start *or* end position
/// can't be fully determined returns `nil` for its SG. Aggregates
/// (per-category totals, round total) sum only the non-nil shots —
/// matching the "aggregates exclude nils" rule. A category with zero
/// shots aggregates to `0`.
public enum SGCalculator {
    // MARK: - Public API

    /// Strokes Gained for a sequence of holes (typically a complete
    /// 18-hole round, but works for partial rounds too — the caller
    /// just passes whatever holes are eligible).
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

    /// SG for a single stroke. Returns `nil` if either endpoint is
    /// unknown.
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

    /// Sums per-shot SG into per-category and overall totals. Nils are
    /// silently skipped — a category with only-nil shots still totals
    /// `0` (the same as a category with no shots), since both mean
    /// "nothing measurable to report here". Callers that need to
    /// distinguish "computed as zero" from "no data" should inspect
    /// the per-shot list directly.
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

    /// One shot in the reconstructed timeline. `start` is `nil` and/or
    /// `end` is `.unknown` when the input doesn't pin the shot down.
    struct ReconstructedShot {
        let category: SGCategory
        let start: ShotPosition?
        let end: ShotEnd
    }

    /// Walks the v1-style hole inputs into a per-stroke timeline.
    /// Internal so tests can pin the reconstruction independent of the
    /// SG arithmetic.
    static func reconstruct(_ input: HoleSGInput) -> [ReconstructedShot] {
        guard input.strokes >= 1 else { return [] }
        let putts = input.puttDistancesFeet ?? []
        let isPar3 = input.par == 3

        var shots: [ReconstructedShot] = []

        // 1. Tee shot — always present.
        shots.append(reconstructTeeShot(input: input, putts: putts, isPar3: isPar3))

        // 2. Approach (par 4 / par 5 with at least 2 strokes).
        if !isPar3, input.strokes >= 2 {
            shots.append(reconstructApproachShot(input: input, putts: putts))
        }

        // 3. ARG fillers between approach and first putt.
        let preARG = shots.count
        let argCount = max(0, input.strokes - preARG - putts.count)
        for index in 0..<argCount {
            let isLast = index == argCount - 1
            let end: ShotEnd = {
                if isLast {
                    if let firstPutt = putts.first {
                        return .position(ShotPosition(lie: .green, distance: Decimal(firstPutt)))
                    }
                    return .holed
                }
                return .unknown
            }()
            // Intermediate ARG shots have no recoverable start position
            // (we only know the lie of the approach landing, not the
            // distance); mark `nil` so SG comes out `nil` rather than
            // guessed.
            shots.append(ReconstructedShot(category: .arg, start: nil, end: end))
        }

        // 4. Putts.
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

    private static func reconstructTeeShot(
        input: HoleSGInput,
        putts: [Int],
        isPar3: Bool
    ) -> ReconstructedShot {
        let category: SGCategory = isPar3 ? .app : .ott
        let startLie: SGBenchmarkLie = isPar3 ? .fairway : .tee
        let start = ShotPosition(lie: startLie, distance: Decimal(input.yardage))

        // 1-stroke hole = ace. Tee shot was holed.
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

        // Off-green tee shot. For par 4 / par 5 we can derive the
        // remaining distance from `teeShotDistance`; for par 3 we
        // typically don't have it (the v1 UI only recorded
        // teeShotDistance on holes where the tee-then-approach split
        // applies), so end stays unknown.
        guard !isPar3, let teeShotDistance = input.teeShotDistance else {
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
        putts: [Int]
    ) -> ReconstructedShot {
        let start: ShotPosition? = {
            guard let teeShotLie = input.teeShotLie,
                  let approachDistance = input.approachDistance, approachDistance > 0
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
                } else if input.strokes == 2 {
                    // Holed-out approach with no putts and exactly 2
                    // strokes total — the approach is the holed shot.
                    end = .holed
                } else {
                    end = .unknown
                }
            } else {
                // Approach missed the green; the actual end-distance
                // is unrecoverable from the v1 fields. SG comes out nil.
                end = .unknown
            }
        } else {
            end = .unknown
        }

        return ReconstructedShot(category: .app, start: start, end: end)
    }

    /// Maps the v2 `Lie` enum to the 5 non-tee benchmark categories.
    /// `.green` maps through directly so this is a total function.
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

// MARK: - Public input + output types

/// One hole's worth of input data, shaped to match the v1 hole-stat
/// schema (tee shot lie + travel distance, approach lie + remaining
/// distance, putt-distance list). v2 will populate this from the
/// `HoleStat` value type once that's added in Phase B5.
public struct HoleSGInput: Sendable, Equatable {
    public let par: Int
    /// Hole length, yards.
    public let yardage: Int
    /// Where the tee shot landed. `nil` means the user didn't record
    /// a lie for this hole (older rounds, partial data).
    public let teeShotLie: Lie?
    /// **Distance the tee shot travelled**, in yards. (Not the distance
    /// remaining — for that, see `approachDistance`.)
    public let teeShotDistance: Int?
    /// Where the approach landed. Unused on par 3 (the tee shot is the
    /// approach).
    public let approachLie: Lie?
    /// Distance remaining when the approach was taken, in yards.
    /// Should equal `yardage − teeShotDistance` if both are recorded;
    /// the calculator trusts whichever one's present.
    public let approachDistance: Int?
    /// One entry per putt taken, in **feet**. Empty array if no putts
    /// (chip-in / hole-out from off the green).
    public let puttDistancesFeet: [Int]?
    /// Total strokes taken on the hole. The reconstruction uses this
    /// to infer the count of around-the-green shots between the
    /// approach and the first putt.
    public let strokes: Int

    public init(
        par: Int,
        yardage: Int,
        teeShotLie: Lie? = nil,
        teeShotDistance: Int? = nil,
        approachLie: Lie? = nil,
        approachDistance: Int? = nil,
        puttDistancesFeet: [Int]? = nil,
        strokes: Int
    ) {
        self.par = par
        self.yardage = yardage
        self.teeShotLie = teeShotLie
        self.teeShotDistance = teeShotDistance
        self.approachLie = approachLie
        self.approachDistance = approachDistance
        self.puttDistancesFeet = puttDistancesFeet
        self.strokes = strokes
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
///
/// All fields are non-optional `Decimal` — nil per-shot values are
/// excluded from the sums (per the "aggregates exclude nils" rule).
/// A category with no shots, or only-nil shots, totals to `0`.
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

/// A shot's starting or ending position. Internal: tests reach in
/// via the `@testable` import.
struct ShotPosition: Equatable {
    let lie: SGBenchmarkLie
    /// Yards for `.tee/.fairway/.rough/.sand/.recovery`; **feet** for
    /// `.green`. Matches `SGBenchmarkTable.expectedStrokes` semantics.
    let distance: Decimal
}

/// Where a shot ended. Distinct from `ShotPosition?` because "in the
/// hole" is a different state from "we don't know".
enum ShotEnd: Equatable {
    case position(ShotPosition)
    case holed
    case unknown
}
