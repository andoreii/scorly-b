import ScorlyDomain

/// Sign-and-File-time SG computation. Mirrors the gate in
/// `RoundsRepositoryLive.computeSG` so the SG card matches before and after filing.
enum SGPreview {
    static func compute(
        holes: [Hole],
        stats: [HoleStat],
        yardageByHoleNumber: [Int: Int]
    ) -> (totals: SGTotals?, holes: [SGTotals]?) {
        guard !holes.isEmpty, holes.count == stats.count else { return (nil, nil) }
        let canCompute = zip(holes, stats).allSatisfy { hole, stat in
            yardageByHoleNumber[hole.number] != nil && stat.puttDistances != nil
        }
        guard canCompute else { return (nil, nil) }
        let inputs: [HoleSGInput] = zip(holes, stats).map { hole, stat in
            HoleSGInput(
                par: stat.par,
                yardage: yardageByHoleNumber[hole.number] ?? 0,
                teeShotLie: stat.teeShotLie,
                teeShotDistance: stat.teeShotDistance,
                approachLie: stat.approachLie,
                approachDistance: stat.approachDistance,
                puttDistancesFeet: stat.puttDistances,
                strokes: stat.strokes,
                approachLandingDistance: stat.approachLandingDistance,
                argShots: stat.argShots,
                layupLie: stat.layupLie,
                layupDistance: stat.layupDistance
            )
        }
        let result = SGCalculator.compute(holes: inputs)
        return (result.totals, result.holes.map(\.totals))
    }
}
