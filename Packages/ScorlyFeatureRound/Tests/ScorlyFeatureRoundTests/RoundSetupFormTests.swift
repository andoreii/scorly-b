import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

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
            form.players.append(.init(name: "Guest \(next)"))
        }
        #expect(form.players.count == 4)
    }

    @Test("Default You-slot has no handicap until seeded")
    func youSlotStartsNil() {
        let form = RoundSetupForm()
        #expect(form.players.first?.handicap == nil)
    }

    @Test("New guest player defaults to no handicap")
    func guestDefaultsNoHandicap() {
        var form = RoundSetupForm()
        form.players.append(.init(name: "Guest 1"))
        #expect(form.players.last?.handicap == nil)
    }

    @Test("Guest handicap can be set and cleared")
    func guestHandicapEditable() {
        var form = RoundSetupForm()
        form.players.append(.init(name: "Guest 1"))
        form.players[1].handicap = Decimal(string: "18.4")
        #expect(form.players[1].handicap == Decimal(string: "18.4"))
        form.players[1].handicap = nil
        #expect(form.players[1].handicap == nil)
    }

    @Test("RoundPlayer Codable preserves nil handicap")
    func roundPlayerCodableNil() throws {
        let player = RoundPlayer(name: "Guest 1", handicap: nil)
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(RoundPlayer.self, from: data)
        #expect(decoded == player)
        #expect(decoded.handicap == nil)
    }

    @Test("RoundPlayer Codable preserves numeric handicap")
    func roundPlayerCodableNumeric() throws {
        let player = RoundPlayer(name: "You", handicap: Decimal(string: "12.4"))
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(RoundPlayer.self, from: data)
        #expect(decoded == player)
        #expect(decoded.handicap == Decimal(string: "12.4"))
    }
}
