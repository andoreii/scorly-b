# Round Detail Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Round Detail a complete single-round review with a filed scorecard and the Trends visual vocabulary for SG, accuracy, putting, and scoring.

**Architecture:** Add presentation-only chart and scorecard primitives to `ScorlyDesignSystem`, driven by domain-free value structs. Add a `RoundDetailMetrics` mapper in History that converts one `CompletedRound` into shared visual inputs, and compose the new page in `RoundDetailView`. Existing Trends adapters can delegate rendering to the new primitives while retaining multi-round trend-only material.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, Swift Package Manager, XcodeGen app build

---

### Task 1: Single-Round Detail Metrics

**Files:**
- Create: `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/RoundDetailMetrics.swift`
- Modify: `Packages/ScorlyFeatureHistory/Tests/ScorlyFeatureHistoryTests/PlaceholderTests.swift`

- [ ] **Step 1: Write failing tests for one-round outcomes, putting, and scorecard grouping**

Add tests that construct a `CompletedRound` with par-three and par-four holes and expect:

```swift
let metrics = RoundDetailMetrics(round: round)
#expect(metrics.playedHoleCount == 3)
#expect(metrics.totalPutts == 5)
#expect(metrics.averagePuttsPerHole == 5.0 / 3.0)
#expect(metrics.fairwayRose.opportunities == 2)
#expect(metrics.greenRose.opportunities == 3)
#expect(metrics.puttMakeStats[.feet7to10]?.attempted == 1)
#expect(metrics.outcomes[.par] == 1)
#expect(metrics.scorecardGroups.count == 2) // for an eighteen-hole card
```

- [ ] **Step 2: Run focused History tests and confirm RED**

Run:

```bash
swift test --package-path Packages/ScorlyFeatureHistory
```

Expected: FAIL because `RoundDetailMetrics` and its shared input types do not exist.

- [ ] **Step 3: Add the pure single-round mapper**

Implement `RoundDetailMetrics` with these stored outputs:

```swift
struct RoundDetailMetrics {
    let playedHoleCount: Int
    let totalPutts: Int
    let averagePuttsPerHole: Double?
    let fairwayRose: AccuracyRoseValues
    let greenRose: AccuracyRoseValues
    let puttMakeStats: [PuttDistanceBucket: PuttMakeValues]
    let outcomes: [ScoringOutcome: Int]
    let scorecardGroups: [ScorecardGroupValues]

    init(round: CompletedRound) { /* derive from round.holeStats only */ }
}
```

Use the existing Trends semantics: FIR excludes par threes; GIR includes played holes; final logged putt is made; outcomes bucket relative-to-par scores only when strokes are positive.

- [ ] **Step 4: Run History tests and confirm GREEN**

Run:

```bash
swift test --package-path Packages/ScorlyFeatureHistory
```

Expected: PASS.

### Task 2: Shared Design-System Visuals

**Files:**
- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/RoundScorecardCard.swift`
- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/AccuracyRoseCard.swift`
- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingSummaryCard.swift`
- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ScoringDistributionCard.swift`
- Modify: `Packages/ScorlyDesignSystem/Tests/ScorlyDesignSystemTests/BrutalistTokenTests.swift`

- [ ] **Step 1: Add failing value-type tests**

Add tests covering domain-free bucket and outcome mapping:

```swift
#expect(PuttDistanceBucket.bucket(forFeet: 10) == .feet7to10)
#expect(PuttDistanceBucket.bucket(forFeet: 31) == .feet31plus)
#expect(ScoringOutcome.outcome(forVsPar: -1) == .birdiePlus)
#expect(ScoringOutcome.outcome(forVsPar: 2) == .doublePlus)
```

- [ ] **Step 2: Run focused DesignSystem tests and confirm RED**

Run:

```bash
swift test --package-path Packages/ScorlyDesignSystem
```

Expected: FAIL because the new shared visual value types do not exist.

- [ ] **Step 3: Add domain-free primitives**

Implement:

```swift
public struct AccuracyRoseValues: Sendable, Equatable { /* hit rate + directional stacks */ }
public struct AccuracyRoseCard: View { /* FIR/GIR wind rose card */ }
public enum PuttDistanceBucket: String, CaseIterable, Sendable, Identifiable { /* feet bands */ }
public struct PuttMakeValues: Sendable, Equatable { /* made / attempted / rate */ }
public struct PuttingSummaryCard: View { /* total, average, make-rate rows */ }
public enum ScoringOutcome: String, CaseIterable, Sendable, Identifiable { /* four buckets */ }
public struct ScoringDistributionCard: View { /* distribution donut and ledger */ }
public struct ScorecardGroupValues: Sendable, Equatable { /* label + hole cells + total */ }
public struct RoundScorecardCard: View { /* read-only pip grid and legend */ }
```

Keep inputs domain-free, use existing tokens, and include no live tap state or quick-stat strip in `RoundScorecardCard`.

- [ ] **Step 4: Run DesignSystem tests and confirm GREEN**

Run:

```bash
swift test --package-path Packages/ScorlyDesignSystem
```

Expected: PASS.

### Task 3: Round Detail Page Composition

**Files:**
- Modify: `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/RoundDetailView.swift`
- Test: `Packages/ScorlyFeatureHistory/Tests/ScorlyFeatureHistoryTests/PlaceholderTests.swift`

- [ ] **Step 1: Compose the approved order**

At the start of `body`, calculate:

```swift
let metrics = RoundDetailMetrics(round: round)
```

Render after `RoundHeroStamp`, in order:

```swift
RoundScorecardCard(groups: metrics.scorecardGroups)
StrokesGainedCard(/* compact category rows plus round hole timeline */)
AccuracyRoseCard(kind: .fairway, values: metrics.fairwayRose)
AccuracyRoseCard(kind: .green, values: metrics.greenRose)
PuttingSummaryCard(totalPutts: metrics.totalPutts,
                   averagePuttsPerHole: metrics.averagePuttsPerHole,
                   stats: metrics.puttMakeStats)
ScoringDistributionCard(counts: metrics.outcomes,
                        total: metrics.playedHoleCount)
```

Use `breakdownDensity: .spacious` on `StrokesGainedCard` while keeping `holes: round.sgHoles`.

- [ ] **Step 2: Run History tests**

Run:

```bash
swift test --package-path Packages/ScorlyFeatureHistory
```

Expected: PASS.

### Task 4: Trends Delegation and Verification

**Files:**
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/Charts/AccuracyCard.swift`
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/Charts/MakePctByDistanceCard.swift`
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/Charts/HoleOutcomeDistribution.swift`
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/TrendCarouselAggregates.swift`
- Modify: `Packages/ScorlyFeatureStats/Tests/ScorlyFeatureStatsTests/TrendCarouselAggregatesTests.swift`

- [ ] **Step 1: Delegate matching Trends visuals to shared cards**

Make Trends use the shared presentation value types for accuracy roses, putt make rates, and scoring outcomes. Preserve Trends-only time-series rendering below the shared accuracy visualization where present.

- [ ] **Step 2: Run package and architecture verification**

Run:

```bash
swift test --package-path Packages/ScorlyDesignSystem
swift test --package-path Packages/ScorlyFeatureHistory
swift test --package-path Packages/ScorlyFeatureStats
swift test --package-path Packages/ScorlyDomain
make build
git diff --check
```

Expected: all commands exit successfully and `git diff --check` prints no whitespace errors.

- [ ] **Step 3: Prepare handoff without git mutations**

Because work is occurring in the existing dirty `main` worktree, do not stage, commit, push, or open a pull request. Report modified files, verification evidence, and any remaining unrelated worktree risk.
