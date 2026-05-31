public extension RoundPlayState {
    /// ARG rows store each recovery shot's start position. The first
    /// recovery starts where the approach finished; later starts are
    /// written by the previous row's LANDED AT wheel.
    func argStartDistance(slot: Int, at index: Int) -> Int? {
        guard entries.indices.contains(index), slot >= 0 else { return nil }
        let entry = entries[index]
        let slotDistance = entry.argShots.flatMap { shots in
            shots.indices.contains(slot) ? shots[slot].distanceYards : nil
        }
        return slotDistance ?? (slot == 0 ? entry.approachLandingDistance : nil)
    }

    /// Records where an ARG shot finished by writing the following
    /// ARG row's start distance. Final-shot outcomes are anchored by
    /// the first putt or the holed result and never call this method.
    func setARGTransitionDistance(_ yards: Int?, after slot: Int, at index: Int) {
        guard entries.indices.contains(index), slot >= 0 else { return }
        let nextSlot = slot + 1
        guard nextSlot < inferredARGCount(at: index) else { return }
        var current = entries[index].argShots ?? []
        while current.count <= nextSlot {
            current.append(ARGShotEntry())
        }
        current[nextSlot].distanceYards = yards
        entries[index].argShots = current
    }

    /// Number of ARG starts captured precisely enough to contribute
    /// to SG. The approach landing wheel supplies slot zero's distance.
    func recordedARGCount(at index: Int) -> Int {
        guard entries.indices.contains(index) else { return 0 }
        let shots = entries[index].argShots ?? []
        return shots.indices.prefix(inferredARGCount(at: index)).filter { slot in
            shots[slot].lie != nil && argStartDistance(slot: slot, at: index) != nil
        }.count
    }
}
