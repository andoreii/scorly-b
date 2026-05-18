import Foundation
import Testing
@testable import ScorlyDomain

struct TeeCategorizationTests {
    @Test("Three tees split into one each forward/middle/back")
    func threeTeesSplitEvenly() {
        let red = makeTee(name: "Red", yardage: 5_100)
        let white = makeTee(name: "White", yardage: 6_100)
        let blue = makeTee(name: "Blue", yardage: 6_800)

        let result = TeeCategorization.categorize(tees: [white, blue, red])

        #expect(result[red.externalId] == .forward)
        #expect(result[white.externalId] == .middle)
        #expect(result[blue.externalId] == .back)
    }

    @Test("Five tees: one forward, three middle, one back")
    func fiveTeesSplit() {
        let tees = (1...5).map { index in
            makeTee(name: "T\(index)", yardage: 5_000 + index * 200)
        }

        let result = TeeCategorization.categorize(tees: tees)

        #expect(result[tees[0].externalId] == .forward)
        #expect(result[tees[1].externalId] == .middle)
        #expect(result[tees[2].externalId] == .middle)
        #expect(result[tees[3].externalId] == .middle)
        #expect(result[tees[4].externalId] == .back)
    }

    @Test("Six tees: two each")
    func sixTeesSplit() {
        let tees = (1...6).map { index in
            makeTee(name: "T\(index)", yardage: 5_000 + index * 200)
        }

        let result = TeeCategorization.categorize(tees: tees)

        #expect(result[tees[0].externalId] == .forward)
        #expect(result[tees[1].externalId] == .forward)
        #expect(result[tees[2].externalId] == .middle)
        #expect(result[tees[3].externalId] == .middle)
        #expect(result[tees[4].externalId] == .back)
        #expect(result[tees[5].externalId] == .back)
    }

    @Test("Two tees split into forward + back")
    func twoTeesSplit() {
        let short = makeTee(name: "Short", yardage: 5_500)
        let long = makeTee(name: "Long", yardage: 6_900)

        let result = TeeCategorization.categorize(tees: [long, short])

        #expect(result[short.externalId] == .forward)
        #expect(result[long.externalId] == .back)
    }

    @Test("Single tee falls into middle")
    func singleTee() {
        let only = makeTee(name: "Only", yardage: 6_000)
        let result = TeeCategorization.categorize(tees: [only])
        #expect(result[only.externalId] == .middle)
    }

    @Test("Missing yardage falls back to name keyword pass")
    func nameKeywordFallback() {
        let red = makeTee(name: "Red", yardage: nil)
        let white = makeTee(name: "White", yardage: nil)
        let blue = makeTee(name: "Blue", yardage: nil)

        let result = TeeCategorization.categorize(tees: [red, white, blue])
        #expect(result[red.externalId] == .forward)
        #expect(result[white.externalId] == .middle)
        #expect(result[blue.externalId] == .back)
    }

    @Test("Ties on yardage broken by name for stability")
    func ranksStableOnTies() {
        let alpha = makeTee(name: "Alpha", yardage: 6_000)
        let bravo = makeTee(name: "Bravo", yardage: 6_000)
        let charlie = makeTee(name: "Charlie", yardage: 6_000)

        let first = TeeCategorization.categorize(tees: [charlie, alpha, bravo])
        let second = TeeCategorization.categorize(tees: [bravo, charlie, alpha])
        #expect(first == second)
        #expect(first[alpha.externalId] == .forward)
        #expect(first[bravo.externalId] == .middle)
        #expect(first[charlie.externalId] == .back)
    }

    private func makeTee(name: String, yardage: Int?) -> TeeCategorization.Tee {
        TeeCategorization.Tee(externalId: UUID(), name: name, yardage: yardage)
    }
}
