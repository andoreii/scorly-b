import Foundation
import Testing
@testable import ScorlyDomain

struct InsightEngineTests {
    private let now = Date(timeIntervalSince1970: 1_745_000_000) // arbitrary anchor

    @Test("Empty input set returns no insights")
    func emptyInput() {
        #expect(InsightEngine.weeklyInsights(from: [], referenceDate: now).isEmpty)
    }

    @Test("Rounds older than 7 days from referenceDate are excluded")
    func windowFiltersOldRounds() {
        // Single round 8 days old — should be filtered out → empty result.
        let old = roundWithSG(daysAgo: 8, putt: dec("-0.5"))
        #expect(InsightEngine.weeklyInsights(from: [old], referenceDate: now).isEmpty)
    }

    @Test("Rounds without sgTotals are silently skipped")
    func skipsNoSGRounds() {
        let withoutSG = round(daysAgo: 1, sg: nil)
        #expect(InsightEngine.weeklyInsights(from: [withoutSG], referenceDate: now).isEmpty)
    }

    @Test("Returns top-3 weaknesses ordered most-negative first")
    func weaknessesOrderedByMagnitude() {
        // Single round in window: ott=-1.0, app=-0.5, arg=-0.2, putt=+0.3.
        // Weaknesses should be [ott, app, arg] (3 most-negative, putt
        // excluded because positive). Strength is putt. Practice focus is ott.
        let theRound = roundWithSG(
            daysAgo: 1,
            ott: dec("-1.0"),
            app: dec("-0.5"),
            arg: dec("-0.2"),
            putt: dec("0.3")
        )
        let insights = InsightEngine.weeklyInsights(from: [theRound], referenceDate: now)
        #expect(insights.count == 5) // 3 weaknesses + 1 strength + 1 practice focus

        let weaknesses = insights.filter { $0.kind == .weakness }
        #expect(weaknesses.map(\.category) == [.ott, .app, .arg])
        #expect(weaknesses.map(\.avgPerRound) == [dec("-1.0"), dec("-0.5"), dec("-0.2")])

        let strength = insights.first { $0.kind == .strength }
        #expect(strength?.category == .putt)
        #expect(strength?.avgPerRound == dec("0.3"))

        let focus = insights.first { $0.kind == .practiceFocus }
        #expect(focus?.category == .ott)
    }

    @Test("Strength omitted when all categories are negative")
    func noStrengthWhenAllNegative() {
        let theRound = roundWithSG(
            daysAgo: 0,
            ott: dec("-1.0"),
            app: dec("-0.5"),
            arg: dec("-0.2"),
            putt: dec("-0.1")
        )
        let insights = InsightEngine.weeklyInsights(from: [theRound], referenceDate: now)
        #expect(!insights.contains { $0.kind == .strength })
        #expect(insights.filter { $0.kind == .weakness }.count == 3)
        #expect(insights.contains { $0.kind == .practiceFocus })
    }

    @Test("Weaknesses + practice focus omitted when all categories are non-negative")
    func noWeaknessWhenAllPositive() {
        let theRound = roundWithSG(
            daysAgo: 0,
            ott: dec("0.4"),
            app: dec("0.3"),
            arg: dec("0.2"),
            putt: dec("0.1")
        )
        let insights = InsightEngine.weeklyInsights(from: [theRound], referenceDate: now)
        #expect(!insights.contains { $0.kind == .weakness })
        #expect(!insights.contains { $0.kind == .practiceFocus })
        let strength = insights.first { $0.kind == .strength }
        #expect(strength?.category == .ott)
        #expect(strength?.avgPerRound == dec("0.4"))
    }

    @Test("Averages across multiple in-window rounds")
    func averagesAcrossRounds() {
        // Two rounds: putt averages (0.4 + 0.0)/2 = 0.2; ott (-0.5 + -0.5)/2 = -0.5.
        let first = roundWithSG(daysAgo: 1, ott: dec("-0.5"), putt: dec("0.4"))
        let second = roundWithSG(daysAgo: 3, ott: dec("-0.5"), putt: dec("0.0"))
        let insights = InsightEngine.weeklyInsights(from: [first, second], referenceDate: now)
        let strength = insights.first { $0.kind == .strength }
        #expect(strength?.avgPerRound == dec("0.2"))
        let weakness = insights.first { $0.kind == .weakness }
        #expect(weakness?.avgPerRound == dec("-0.5"))
    }

    // MARK: - Helpers

    private func roundWithSG(
        daysAgo: Double,
        ott: Decimal = 0,
        app: Decimal = 0,
        arg: Decimal = 0,
        putt: Decimal = 0
    ) -> CompletedRound {
        let totals = SGTotals(ott: ott, app: app, arg: arg, putt: putt, total: ott + app + arg + putt)
        return round(daysAgo: daysAgo, sg: totals)
    }

    private func round(daysAgo: Double, sg: SGTotals?) -> CompletedRound {
        let date = now.addingTimeInterval(-daysAgo * 24 * 60 * 60)
        return CompletedRound(
            id: UUID(),
            datePlayed: date,
            par: 72,
            totalScore: 80,
            holesPlayed: .eighteen,
            sgTotals: sg
        )
    }

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
