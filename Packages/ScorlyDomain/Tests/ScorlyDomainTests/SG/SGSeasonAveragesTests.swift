import Foundation
import Testing
@testable import ScorlyDomain

struct SGSeasonAveragesTests {
    @Test("season averages exclude the focused round and ignore nil-sg rounds")
    func excludeFocusedAndNil() {
        let focusedId = UUID()
        let focused = makeRound(id: focusedId, ott: 5, app: 5, arg: 5, putt: 5, total: 20)
        let other1 = makeRound(id: UUID(), ott: 1, app: 2, arg: 3, putt: 4, total: 10)
        let other2 = makeRound(id: UUID(), ott: 3, app: 4, arg: 5, putt: 6, total: 18)
        let noSG = makeRoundWithoutSG(id: UUID())

        let avg = sgSeasonAverages(excluding: focusedId, from: [focused, other1, other2, noSG])

        let unwrapped = try? #require(avg)
        guard let unwrapped else { return }
        // Mean of other1 and other2 only — focused excluded by id, noSG by nil sgTotals.
        #expect(unwrapped.ott == Decimal(2))
        #expect(unwrapped.app == Decimal(3))
        #expect(unwrapped.arg == Decimal(4))
        #expect(unwrapped.putt == Decimal(5))
        #expect(unwrapped.total == Decimal(14))
    }

    @Test("season averages return nil when no other round has SG data")
    func nilWhenAlone() {
        let onlyId = UUID()
        let only = makeRound(id: onlyId, ott: 1, app: 1, arg: 1, putt: 1, total: 4)
        let noSG = makeRoundWithoutSG(id: UUID())
        #expect(sgSeasonAverages(excluding: onlyId, from: [only, noSG]) == nil)
    }

    // MARK: - Fixtures

    private func makeRound(
        id: UUID,
        ott: Int,
        app: Int,
        arg: Int,
        putt: Int,
        total: Int
    ) -> CompletedRound {
        CompletedRound(
            id: id,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            par: 72,
            totalScore: 80,
            holesPlayed: .eighteen,
            sgTotals: SGTotals(
                ott: Decimal(ott),
                app: Decimal(app),
                arg: Decimal(arg),
                putt: Decimal(putt),
                total: Decimal(total)
            )
        )
    }

    private func makeRoundWithoutSG(id: UUID) -> CompletedRound {
        CompletedRound(
            id: id,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            par: 72,
            totalScore: 80,
            holesPlayed: .eighteen,
            sgTotals: nil
        )
    }
}
