# Round Review Card Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the recovered collapsible analytical card stack on Sign & File and Round Detail without changing the current Trends or Round Play experiences.

**Architecture:** Add round-review presentation paths to the shared design-system cards while retaining their current default APIs for Trends. Derive the additional single-round putting and scoring values in `ScorlyReviewKit`, then pass them from both feature screens. Recover only the relevant June 17 stash blobs and manually merge newer comparison-reference and refinement behavior.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, Swift Package Manager, XcodeGen, iOS 26 simulator

---

## Execution note

The implementation uses dedicated `RoundStrokesGainedCard` and
`RoundScoringDistributionCard` primitives instead of adding presentation
modes to the existing shared types. This is a narrower compatibility boundary:
the current Trends call sites and their default card rendering remain unchanged.

## File map

**Create**

- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewDisclosureCard.swift`: accessible collapsed/expanded shell used only by the round-review presentation.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingProfileChart.swift`: Canvas rendering for cumulative putts per hole.
- `Packages/ScorlyDesignSystem/Tests/ScorlyDesignSystemTests/RoundReviewCardCompatibilityTests.swift`: compile-time coverage for both existing Trends initializers and restored round-review initializers.

**Modify**

- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewChartValues.swift`: add putting-profile and putt-distribution value types.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Theme/BrutalistColor.swift`: restore the statistical ink/fill tokens used by the recovered charts.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedCard.swift`: add a round-disclosure presentation while preserving the existing flat presentation and initializer defaults used by Trends.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedBars.swift`: add the recovered ranked round-review bars alongside the current Trends bars.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedTimeline.swift`: add recovered interval labeling and round-review timeline behavior without changing current call-site defaults.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/AccuracyRoseCard.swift`: restore the disclosure-card windrose composition.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingSummaryCard.swift`: restore distribution heroes and running-average chart.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ScoringDistributionCard.swift`: add the round-disclosure scoring spectrum while preserving the existing two-argument Trends initializer.
- `Packages/ScorlyDesignSystem/Tests/ScorlyDesignSystemTests/StrokesGainedSummaryTests.swift`: cover recovered timeline-label behavior.
- `Packages/ScorlyReviewKit/Sources/ScorlyReviewKit/RoundDetailMetrics.swift`: derive score-to-par, cumulative putting average, and putt distribution.
- `Packages/ScorlyReviewKit/Tests/ScorlyReviewKitTests/RoundDetailMetricsTests.swift`: regression coverage for the new values and hole numbering.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/ConfirmView.swift`: select round-disclosure cards and pass live metrics while retaining refinement and filing.
- `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/RoundDetailView.swift`: select round-disclosure cards and pass saved-round metrics while retaining comparison and deletion.

Do not modify files under `Packages/ScorlyFeatureStats` or any Round Play source.

### Task 1: Derive recovered single-round metrics

**Files:**

- Modify: `Packages/ScorlyReviewKit/Tests/ScorlyReviewKitTests/RoundDetailMetricsTests.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewChartValues.swift`
- Modify: `Packages/ScorlyReviewKit/Sources/ScorlyReviewKit/RoundDetailMetrics.swift`

- [ ] **Step 1: Add the failing metric assertions**

Extend `derivesReviewStatistics()` with:

```swift
#expect(metrics.scoreToPar == 0)
#expect(metrics.puttingAverageProfile.map(\.holeNumber) == [1, 2, 3])
#expect(metrics.puttingAverageProfile.map(\.averagePuttsPerHole) == [2, 2, 5.0 / 3.0])
#expect(metrics.puttDistribution.onePutt == 1)
#expect(metrics.puttDistribution.twoPutt == 2)
#expect(metrics.puttDistribution.threePuttPlus == 0)
```

Extend `directInitFiltersUnplayed()` with:

```swift
#expect(metrics.puttingAverageProfile.map(\.holeNumber) == [1, 2])
#expect(metrics.puttingAverageProfile.map(\.averagePuttsPerHole) == [2, 2])
```

Extend `directBackNineScorecard()` with:

```swift
#expect(metrics.puttingAverageProfile.map(\.holeNumber) == Array(10...18))
```

Add:

```swift
@Test("Score to par sums played holes only")
func scoreToPar() {
    let metrics = RoundDetailMetrics(
        holeStats: [
            hole(par: 4, strokes: 6, putts: 2),
            hole(par: 3, strokes: 2, putts: 1),
            hole(par: 5, strokes: 0, putts: 0),
        ],
        holesPlayed: .front9
    )

    #expect(metrics.scoreToPar == 1)
}

@Test("Empty rounds expose empty putting analysis")
func emptyRoundPuttingAnalysis() {
    let metrics = RoundDetailMetrics(holeStats: [], holesPlayed: .front9)

    #expect(metrics.scoreToPar == 0)
    #expect(metrics.puttingAverageProfile.isEmpty)
    #expect(metrics.puttDistribution.total == 0)
}
```

- [ ] **Step 2: Run the focused test and confirm the new API is absent**

Run:

```bash
swift test --package-path Packages/ScorlyReviewKit --filter RoundDetailMetricsTests
```

Expected: compilation fails because `scoreToPar`, `puttingAverageProfile`, and `puttDistribution` do not exist. This is the additive-API red boundary.

- [ ] **Step 3: Add the recovered design-system value types**

Append the recovered definitions from `refs/stash:Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewChartValues.swift` without replacing current types:

```swift
public struct PuttingAveragePoint: Sendable, Equatable, Identifiable {
    public let holeNumber: Int
    public let averagePuttsPerHole: Double
    public var id: Int { holeNumber }

    public init(holeNumber: Int, averagePuttsPerHole: Double) {
        self.holeNumber = holeNumber
        self.averagePuttsPerHole = averagePuttsPerHole
    }
}

public struct PuttDistributionValues: Sendable, Equatable {
    public let onePutt: Int
    public let twoPutt: Int
    public let threePuttPlus: Int

    public init(onePutt: Int = 0, twoPutt: Int = 0, threePuttPlus: Int = 0) {
        self.onePutt = onePutt
        self.twoPutt = twoPutt
        self.threePuttPlus = threePuttPlus
    }

    public var total: Int { onePutt + twoPutt + threePuttPlus }

    public func share(_ count: Int) -> Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
}
```

- [ ] **Step 4: Add temporary compiling stubs and verify assertion failures**

Add the three public properties to `RoundDetailMetrics` and initialize them with neutral values:

```swift
public let scoreToPar: Int
public let puttingAverageProfile: [PuttingAveragePoint]
public let puttDistribution: PuttDistributionValues
```

```swift
scoreToPar = 0
puttingAverageProfile = []
puttDistribution = PuttDistributionValues()
```

Run the focused test again. Expected: tests compile and fail on the non-empty profile and distribution assertions.

- [ ] **Step 5: Implement the metric derivation**

Use the played-hole collection for score and distribution:

```swift
scoreToPar = played.reduce(0) { $0 + $1.strokes - $1.par }
puttingAverageProfile = Self.puttingAverageProfile(from: holeStats, holesPlayed: holesPlayed)
puttDistribution = Self.puttDistribution(from: played)
```

Add the recovered helpers, including a shared printed-hole-number helper:

```swift
private static func puttingAverageProfile(
    from holes: [HoleStat],
    holesPlayed: HolesPlayed
) -> [PuttingAveragePoint] {
    var totalPutts = 0
    var playedHoles = 0
    return holes.enumerated().compactMap { index, hole in
        guard hole.strokes > 0 else { return nil }
        totalPutts += hole.putts
        playedHoles += 1
        return PuttingAveragePoint(
            holeNumber: printedHoleNumber(index: index, holesPlayed: holesPlayed, count: holes.count),
            averagePuttsPerHole: Double(totalPutts) / Double(playedHoles)
        )
    }
}

private static func puttDistribution(from holes: [HoleStat]) -> PuttDistributionValues {
    var onePutt = 0
    var twoPutt = 0
    var threePuttPlus = 0
    for hole in holes {
        switch hole.putts {
        case 1: onePutt += 1
        case 2: twoPutt += 1
        case 3...: threePuttPlus += 1
        default: break
        }
    }
    return PuttDistributionValues(
        onePutt: onePutt,
        twoPutt: twoPutt,
        threePuttPlus: threePuttPlus
    )
}

private static func printedHoleNumber(index: Int, holesPlayed: HolesPlayed, count: Int) -> Int {
    holesPlayed == .back9 && count <= 9 ? index + 10 : index + 1
}
```

Use `printedHoleNumber` in `scorecardGroups` as well.

- [ ] **Step 6: Verify the metric tests are green**

Run the focused test command again. Expected: all `RoundDetailMetricsTests` pass.

- [ ] **Step 7: Prepare the repository handoff for this chunk**

Report the branch proposal `fix/restore-review-cards`, modified files, commit proposal `restore round review metrics`, PR draft, and flags. Stop before `git checkout`, `git add`, or `git commit` until the developer explicitly approves the handoff.

### Task 2: Restore the disclosure shell and putting chart

**Files:**

- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewDisclosureCard.swift`
- Create: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingProfileChart.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Theme/BrutalistColor.swift`

- [ ] **Step 1: Recover the exact source blobs for review**

Read, but do not apply wholesale:

```bash
git show refs/stash^3:Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ReviewDisclosureCard.swift
git show refs/stash^3:Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingProfileChart.swift
git diff HEAD refs/stash -- Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Theme/BrutalistColor.swift
```

The first two blobs are the complete source of truth for the new files. Restore them with `apply_patch`. For the color file, add only tokens referenced by the round-review implementation; retain every token currently used by Trends and Round Play.

- [ ] **Step 2: Restore `ReviewDisclosureCard`**

Create the generic `ReviewDisclosureCard<Content>` exactly from the recovered blob. Confirm these contract points in the result:

```swift
public init(
    meta: String,
    title: String,
    metric: String,
    initiallyExpanded: Bool = false,
    @ViewBuilder content: @escaping () -> Content
)
```

The header must toggle `isExpanded`, use `Motion.adaptive`, call `Haptics.soft()`, draw `CornerMarks`, and expose an accessibility label/value.

- [ ] **Step 3: Restore `PuttingProfileChart`**

Create the chart exactly from the recovered blob. It must render a running-average line from `[PuttingAveragePoint]`, use a dashed final-average rule, label first/middle/last holes, and handle an empty point list by drawing nothing.

- [ ] **Step 4: Compile the design-system package**

Run:

```bash
swift build --package-path Packages/ScorlyDesignSystem
```

Expected: build succeeds with no missing token or symbol errors.

- [ ] **Step 5: Prepare the repository handoff for this chunk**

Report new and modified files and propose commit `add round review disclosure charts`. Stop before staging or committing until explicit approval.

### Task 3: Restore analytical card presentations without changing Trends

**Files:**

- Create: `Packages/ScorlyDesignSystem/Tests/ScorlyDesignSystemTests/RoundReviewCardCompatibilityTests.swift`
- Modify: `Packages/ScorlyDesignSystem/Tests/ScorlyDesignSystemTests/StrokesGainedSummaryTests.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedCard.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedBars.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedTimeline.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/AccuracyRoseCard.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/PuttingSummaryCard.swift`
- Modify: `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/ScoringDistributionCard.swift`

- [ ] **Step 1: Write compatibility and timeline tests first**

Add the recovered timeline assertions to `StrokesGainedSummaryTests`:

```swift
@Test("Wide SG timelines label every second y-axis gridline")
func sgTimelineLabelsAreIntervalled() {
    #expect(sgTimelineShouldLabel(tick: 1, yMaxCeil: 2))
    #expect(!sgTimelineShouldLabel(tick: 1, yMaxCeil: 3))
    #expect(sgTimelineShouldLabel(tick: 2, yMaxCeil: 3))
    #expect(sgTimelineShouldLabel(tick: 0, yMaxCeil: 8))
}
```

Create a compile-time compatibility test:

```swift
import SwiftUI
import Testing
@testable import ScorlyDesignSystem

struct RoundReviewCardCompatibilityTests {
    @Test("Existing and round-review card initializers coexist")
    func initializersCoexist() {
        _ = StrokesGainedCard(meta: "TREND", total: nil, summaryStyle: .categoryExtremes, breakdownDensity: .spacious)
        _ = StrokesGainedCard(meta: "ROUND", total: nil, presentation: .roundDisclosure)
        _ = ScoringDistributionCard(counts: [:], total: 0)
        _ = ScoringDistributionCard(counts: [:], total: 0, scoreToPar: 0)
        #expect(Bool(true))
    }
}
```

- [ ] **Step 2: Run tests and verify the round-review APIs fail to compile**

Run:

```bash
swift test --package-path Packages/ScorlyDesignSystem
```

Expected: compilation fails for `presentation`, the three-argument scoring initializer, and `sgTimelineShouldLabel`.

- [ ] **Step 3: Add an explicit strokes-gained presentation mode**

Add:

```swift
public enum SGCardPresentation: Sendable {
    case flat
    case roundDisclosure
}
```

Add `presentation: SGCardPresentation = .flat` to the current initializer. Keep the current body as `flatBody`; add the recovered stash body as `roundDisclosureBody`, wrapped in `ReviewDisclosureCard`. Do not remove `summaryStyle`, `breakdownDensity`, timeline labels, or their defaults because `MultiRoundSGCard` depends on them.

Port the recovered ranked bars and timeline helpers under distinct names where necessary so `.flat` renders identically to current `main`.

- [ ] **Step 4: Restore the accuracy and putting cards**

Replace `AccuracyRoseCard` and `PuttingSummaryCard` with their recovered `refs/stash` implementations, then manually retain any current public initializer needed by another caller. These cards are used only by Sign & File and Round Detail.

Required putting initializer:

```swift
public init(
    totalPutts: Int,
    averagePuttsPerHole: Double?,
    profile: [PuttingAveragePoint],
    distribution: PuttDistributionValues
)
```

Keep `PuttMakeRateCard` and `PuttMakeRateRows` so other design-system consumers retain the make-rate visualization.

- [ ] **Step 5: Add a round-review scoring initializer while retaining Trends**

Keep this existing initializer and flat body behavior:

```swift
public init(counts: [ScoringOutcome: Int], total: Int)
```

Add:

```swift
public init(counts: [ScoringOutcome: Int], total: Int, scoreToPar: Int)
```

The new initializer selects the recovered `ReviewDisclosureCard` spectrum. The two-argument initializer remains the default flat presentation used by `HoleOutcomeDistribution` in Trends.

- [ ] **Step 6: Implement interval labeling and run design-system tests**

Add the recovered helper:

```swift
func sgTimelineShouldLabel(tick: Int, yMaxCeil: Int) -> Bool {
    yMaxCeil <= 2 || tick.isMultiple(of: 2)
}
```

Run the full design-system test command. Expected: all tests pass, including both initializer paths.

- [ ] **Step 7: Prove Trends source did not change**

Run:

```bash
git diff --exit-code -- Packages/ScorlyFeatureStats
```

Expected: exit code 0 and no output.

- [ ] **Step 8: Prepare the repository handoff for this chunk**

Report created and modified design-system files and propose commit `restore round review cards`. Stop before staging or committing until explicit approval.

### Task 4: Integrate both round-review screens

**Files:**

- Modify: `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/ConfirmView.swift`
- Modify: `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/RoundDetailView.swift`

- [ ] **Step 1: Update Sign & File card inputs**

Pass `presentation: .roundDisclosure` to `StrokesGainedCard`. Preserve `comparisonReference`, `baselineRounds`, the estimated-hole caption, `refineSheetOpen`, and `SGRefinementSheet`.

Update putting and scoring calls:

```swift
PuttingSummaryCard(
    totalPutts: metrics.totalPutts,
    averagePuttsPerHole: metrics.averagePuttsPerHole,
    profile: metrics.puttingAverageProfile,
    distribution: metrics.puttDistribution
)

ScoringDistributionCard(
    counts: metrics.outcomes,
    total: metrics.playedHoleCount,
    scoreToPar: metrics.scoreToPar
)
```

For scratch comparison only, pass the current personal baseline projection to the recovered SG expanded view. Do not change filing, notes, signature, or navigation code.

- [ ] **Step 2: Update Round Detail card inputs**

Apply the same card presentation and metric arguments. Retain the current `SGReferenceProjection`, scratch-only season average, delete dialog, repository call, error state, and archive callbacks.

- [ ] **Step 3: Build the affected feature packages**

Run:

```bash
swift build --package-path Packages/ScorlyFeatureRound
swift build --package-path Packages/ScorlyFeatureHistory
```

Expected: both builds succeed with no initializer ambiguity or missing symbols.

- [ ] **Step 4: Run affected tests**

Run:

```bash
swift test --package-path Packages/ScorlyReviewKit
swift test --package-path Packages/ScorlyDesignSystem
swift test --package-path Packages/ScorlyFeatureRound
swift test --package-path Packages/ScorlyFeatureHistory
```

Expected: all tests pass.

- [ ] **Step 5: Prepare the repository handoff for this chunk**

Report both modified feature files and propose commit `wire restored round review layout`. Stop before staging or committing until explicit approval.

### Task 5: Full verification and visual acceptance

**Files:**

- Verify all files listed above; no new production changes unless verification identifies a concrete defect.

- [ ] **Step 1: Run formatting and static checks**

Run:

```bash
make format
make lint
```

Expected: formatter completes and lint reports no violations. Review formatter changes before continuing.

- [ ] **Step 2: Run the project verification suite**

Run:

```bash
make packages-test
make build
make test
```

Expected: every command exits 0.

- [ ] **Step 3: Inspect Sign & File in the iPhone 17 simulator**

Launch a completed live round and confirm:

- hero stamp and scorecard remain visible;
- all five analytical cards start collapsed;
- each header shows the correct summary metric;
- expansion reveals the recovered chart without clipping;
- strokes-gained unavailable state is readable;
- SG refinement still opens when estimated holes exist;
- signing and filing still work.

- [ ] **Step 4: Inspect Round Detail in the iPhone 17 simulator**

Open a saved 18-hole and back-nine round and confirm:

- collapsed and expanded layouts match Sign & File;
- back-nine chart labels use holes 10 through 18;
- selected SG comparison text is correct;
- deletion still presents confirmation and returns to Archive after success.

- [ ] **Step 5: Check accessibility behavior**

With VoiceOver inspection, confirm each disclosure header announces the card title, metric, and expand/collapse action. With Reduce Motion enabled, confirm content changes without spatial motion.

- [ ] **Step 6: Review final scope**

Run:

```bash
git diff --check
git status --short
git diff -- Packages/ScorlyFeatureStats Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/PlayView.swift
```

Expected: no whitespace errors, only intended files are modified, and the protected Trends and Round Play paths show no diff.

- [ ] **Step 7: Prepare the final commit and PR handoff**

Provide:

- branch: `fix/restore-review-cards`
- complete NEW / MODIFIED / DELETED list;
- lowercase imperative commit sequence or approved squash message;
- PR title `restore round review cards`;
- PR body with `## what` and `## test` sections;
- flags covering no dependencies, secrets, or schema changes and noting the shared-card compatibility path.

Wait for explicit approval before any remaining `git add`, commit, push, or `gh pr create` action.
