import Foundation

/// Splits a course's tees into Forward / Middle / Back buckets so the Rounds filter
/// can group across course-specific tee names. Ranks by ascending yardage into thirds;
/// falls back to name keywords when yardage is missing.
public enum TeeCategorization {
    public struct Tee: Sendable, Equatable {
        public let externalId: UUID
        public let name: String
        public let yardage: Int?

        public init(externalId: UUID, name: String, yardage: Int?) {
            self.externalId = externalId
            self.name = name
            self.yardage = yardage
        }
    }

    /// Returns the bucket assignment for every tee on a single course.
    public static func categorize(tees: [Tee]) -> [UUID: TeeCategory] {
        guard !tees.isEmpty else { return [:] }

        // 1-2 tees don't split cleanly into thirds; fall through to name keywords.
        if tees.count >= 3, tees.allSatisfy({ $0.yardage != nil }) {
            return byYardageRank(tees)
        }

        if tees.contains(where: { $0.yardage == nil }) {
            return byNameKeyword(tees)
        }

        // 1-2 tees with yardage: a 2-tee course becomes forward + back (skip middle).
        return byYardageRank(tees)
    }

    private static func byYardageRank(_ tees: [Tee]) -> [UUID: TeeCategory] {
        // Break ties by name for a stable result run-to-run.
        let sorted = tees.sorted { lhs, rhs in
            let lyd = lhs.yardage ?? Int.max
            let ryd = rhs.yardage ?? Int.max
            if lyd != ryd { return lyd < ryd }
            return lhs.name < rhs.name
        }
        let teeCount = sorted.count
        var result: [UUID: TeeCategory] = [:]
        for (index, tee) in sorted.enumerated() {
            result[tee.externalId] = bucket(forRank: index, count: teeCount)
        }
        return result
    }

    private static func bucket(forRank index: Int, count: Int) -> TeeCategory {
        switch count {
        case 1: return .middle
        case 2: return index == 0 ? .forward : .back
        default:
            // Integer thirds, remainder absorbed by middle.
            let forwardCount = count / 3
            let backCount = count / 3
            if index < forwardCount { return .forward }
            if index >= count - backCount { return .back }
            return .middle
        }
    }

    private static func byNameKeyword(_ tees: [Tee]) -> [UUID: TeeCategory] {
        var result: [UUID: TeeCategory] = [:]
        for tee in tees {
            result[tee.externalId] = categoryFromName(tee.name)
        }
        return result
    }

    private static func categoryFromName(_ name: String) -> TeeCategory {
        let lower = name.lowercased()
        let forwardKeywords = ["red", "yellow", "green", "ladies", "ladie", "junior", "forward"]
        let backKeywords = ["blue", "black", "champion", "tips", "tournament", "tiger", "pro", "back"]
        if forwardKeywords.contains(where: lower.contains) { return .forward }
        if backKeywords.contains(where: lower.contains) { return .back }
        return .middle
    }
}
