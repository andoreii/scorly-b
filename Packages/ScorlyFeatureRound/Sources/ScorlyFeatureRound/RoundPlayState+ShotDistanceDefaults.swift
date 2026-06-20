public extension RoundPlayState {
    /// Distance shown before the player changes the dial. Existing input
    /// always wins; untouched shots start at zero except a par-3 tee shot,
    /// which starts at the selected tee's yardage for that hole.
    func resolvedSlotDistance(_ slot: ShotSlot, at index: Int) -> Int {
        if let distance = slotDistance(slot, at: index) { return distance }
        guard entries.indices.contains(index), holes.indices.contains(index) else { return 0 }
        guard slot == .teeToGreen, holes[index].par == 3 else { return 0 }
        let holeNumber = holes[index].number
        return tee?.teeHoles.first { $0.holeNumber == holeNumber }?.yardage ?? 0
    }

    /// Select a club and reset the dial to that club's fixed yardage.
    func selectClub(_ club: String, for slot: ShotSlot, at index: Int) {
        setSlotClub(club, to: slot, at: index)
        setSlotDistance(brutalistClubDistances[club] ?? 0, to: slot, at: index)
    }
}

/// Standard golf-bag club order, matching the React design source.
/// Wedges are labelled by loft (50°/54°/58°) rather than GW/SW/LW.
public let brutalistClubs: [String] = [
    "Driver", "3-Wood", "5-Wood", "Hybrid",
    "3i", "4i", "5i", "6i", "7i", "8i", "9i",
    "PW", "50", "54", "58", "Putter",
]

/// Default yardages used to auto-set the distance wheel when the user
/// picks a club in a shot editor.
public let brutalistClubDistances: [String: Int] = [
    "Driver": 250,
    "3-Wood": 225,
    "5-Wood": 210,
    "Hybrid": 200,
    "3i": 195,
    "4i": 185,
    "5i": 175,
    "6i": 165,
    "7i": 150,
    "8i": 140,
    "9i": 130,
    "PW": 120,
    "50": 100,
    "54": 85,
    "58": 70,
    "Putter": 0,
]
