import Foundation
import Testing
@testable import ScorlyDomain

struct SGComparisonReferenceTests {
    @Test("Scratch projection preserves canonical totals and timeline")
    func scratchProjectionPreservesCanonicalValues() {
        let total = totals(ott: 1, app: 2, arg: 3, putt: 4)
        let holes = [
            totals(ott: 1, app: 0, arg: 1, putt: 0),
            totals(ott: 0, app: 2, arg: 2, putt: 4),
        ]

        let projection = SGReferenceProjection.project(
            reference: .scratch,
            totals: total,
            holes: holes,
            baselineRounds: []
        )

        #expect(projection.activeReference == .scratch)
        #expect(projection.referenceLabel == "VS SCRATCH")
        #expect(projection.totals == total)
        #expect(projection.holes == holes)
    }

    @Test("Personal baseline uses the newest 20 SG-enabled rounds")
    func personalBaselineUsesNewestTwentySGRounds() {
        let rounds = Array(1...25).map { (index: Int) in
            round(
                day: index,
                totals: totals(
                    ott: Decimal(index),
                    app: Decimal(index),
                    arg: Decimal(index),
                    putt: Decimal(index)
                )
            )
        } + [
            round(day: 30, totals: nil),
        ]

        let baseline = SGReferenceProjection.personalBaseline(from: rounds)

        #expect(baseline == totals(ott: 15.5, app: 15.5, arg: 15.5, putt: 15.5))
    }

    @Test("Personal projection subtracts each category baseline")
    func personalProjectionRecentersCategories() {
        let projection = SGReferenceProjection.project(
            reference: .personalAverage,
            totals: totals(ott: 3, app: 4, arg: 5, putt: 6),
            holes: nil,
            baselineRounds: [
                round(day: 1, totals: totals(ott: 1, app: 2, arg: 3, putt: 4)),
            ]
        )

        #expect(projection.activeReference == .personalAverage)
        #expect(projection.referenceLabel == "VS PERSONAL AVG")
        #expect(projection.totals == totals(ott: 2, app: 2, arg: 2, putt: 2))
    }

    @Test("Personal timeline distributes baseline and ends at recentered total")
    func personalTimelineEndsAtRecenteredTotal() {
        let projection = SGReferenceProjection.project(
            reference: .personalAverage,
            totals: totals(ott: 8, app: 10, arg: 12, putt: 14),
            holes: [
                totals(ott: 3, app: 4, arg: 5, putt: 6),
                totals(ott: 5, app: 6, arg: 7, putt: 8),
            ],
            baselineRounds: [
                round(day: 1, totals: totals(ott: 2, app: 4, arg: 6, putt: 8)),
            ]
        )

        #expect(projection.totals == totals(ott: 6, app: 6, arg: 6, putt: 6))
        #expect(projection.holes == [
            totals(ott: 2, app: 2, arg: 2, putt: 2),
            totals(ott: 4, app: 4, arg: 4, putt: 4),
        ])
        let timelineTotal = projection.holes?.reduce(Decimal(0)) { $0 + $1.total }
        #expect(timelineTotal == projection.totals?.total)
    }

    @Test("Personal projection falls back to scratch without history")
    func personalProjectionFallsBackWithoutHistory() {
        let total = totals(ott: 1, app: 2, arg: 3, putt: 4)

        let projection = SGReferenceProjection.project(
            reference: .personalAverage,
            totals: total,
            holes: nil,
            baselineRounds: []
        )

        #expect(projection.activeReference == .scratch)
        #expect(projection.referenceLabel == "VS SCRATCH")
        #expect(projection.totals == total)
    }

    private func round(day: Int, totals: SGTotals?) -> CompletedRound {
        CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: TimeInterval(day * 86_400)),
            par: 72,
            totalScore: 80,
            holesPlayed: .eighteen,
            sgTotals: totals
        )
    }

    private func totals(
        ott: Decimal,
        app: Decimal,
        arg: Decimal,
        putt: Decimal
    ) -> SGTotals {
        SGTotals(ott: ott, app: app, arg: arg, putt: putt, total: ott + app + arg + putt)
    }
}
