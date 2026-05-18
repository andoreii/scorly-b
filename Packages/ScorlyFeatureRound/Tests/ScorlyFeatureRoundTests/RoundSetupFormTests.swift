import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

@Suite("RoundSetupForm")
struct RoundSetupFormTests {
    @Test("isReady is false until both course and tee are set")
    func readinessGates() {
        var form = RoundSetupForm()
        #expect(!form.isReady)
        form.courseId = UUID()
        #expect(!form.isReady)
        form.teeId = UUID()
        #expect(form.isReady)
    }

    @Test("Defaults mirror the brutalist design source")
    func defaultsMatchDesign() {
        let form = RoundSetupForm()
        #expect(form.holesPlayed == .eighteen)
        #expect(form.roundType == .casual)
        #expect(form.roundFormat == .stroke)
        #expect(form.conditions.contains(.sunny))
        #expect(form.temperature == 17)
        #expect(form.walkingVsRiding == .walking)
        #expect(form.mentalState == 7)
        #expect(form.notes.isEmpty)
        #expect(form.players.count == 1)
        #expect(form.players.first?.name == "You")
    }

    @Test("Adding a player up to the cap works")
    func playersCap() {
        var form = RoundSetupForm()
        for next in form.players.count..<4 {
            form.players.append(.init(name: "Guest \(next)", handicap: 18))
        }
        #expect(form.players.count == 4)
    }
}
