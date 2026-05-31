extension HoleStatInsert {
    init(roundId: Int, local stat: LocalHoleStat) {
        let penaltyEvents = PenaltyEventJSONCodec.decode(stat.penaltyEventsJSON)
        self.init(
            roundId: roundId,
            holeNumber: stat.holeNumber,
            strokes: stat.strokes,
            putts: stat.putts,
            teeShot: stat.teeShot,
            approach: stat.approach,
            teeClub: stat.teeClub,
            approachClub: stat.approachClub,
            penaltyStrokes: max(stat.penaltyStrokes, penaltyEvents.count),
            greenInReg: stat.greenInReg,
            threePutt: stat.threePutt,
            girOpportunity: true,
            fairwayOpportunity: stat.par >= 4,
            upAndDownSuccess: stat.upAndDownSuccess,
            sandSaveSuccess: stat.sandSaveSuccess,
            puttDistances: stat.puttDistances,
            teeShotDistance: stat.teeShotDistance,
            approachDistance: stat.approachDistance,
            pinPosition: stat.pinPosition,
            holeStatExternalId: stat.externalId.uuidString,
            penaltyEventsJson: stat.penaltyEventsJSON,
            approachLandingDistance: stat.approachLandingDistance,
            argShotsJson: stat.argShotsJSON,
            layupLie: stat.layupLie,
            layupDistance: stat.layupDistance
        )
    }
}
