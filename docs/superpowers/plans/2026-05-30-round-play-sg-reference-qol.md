# Round Play and SG Reference Quality-of-Life Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve round-play distance entry, remove redundant ARG prompts, simplify Trends filtering, add a persistent scratch-versus-personal SG reference, and replace phrase-style page heroes with direct titles.

**Architecture:** Keep canonical distances and stored SG scratch-relative. Translate the streamlined ARG UI back into the existing shot-start model at the round-state boundary, and add a domain-level SG presentation projection that recenters canonical totals only when views request the latest-20 personal reference.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, UserDefaults via `@AppStorage`, Swift Testing.

---

## File Map

### Create

- `Packages/ScorlyDomain/Sources/ScorlyDomain/SG/SGComparisonReference.swift`
  - Defines the persisted preference and presentation projection.
- `Packages/ScorlyDomain/Tests/ScorlyDomainTests/SG/SGComparisonReferenceTests.swift`
  - Pins latest-20 baseline selection, recentering, timeline endpoint, scratch preservation, and fallback.

### Modify

- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/RoundPlayState.swift`
  - Translates streamlined ARG entry into typed shot-start values and exposes capture-completeness helpers.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/ShotSheetView.swift`
  - Replaces approach landing buckets with a one-yard distance wheel.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/ARGEditorSection.swift`
  - Shows one-yard wheels only between ARG shots.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/SGRefinementSheet.swift`
  - Mirrors the live ARG capture flow and completeness rules.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/ConfirmView.swift`
  - Applies the active SG projection to sign-and-file.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/PlayView.swift`
  - Summarizes first ARG start distance through the translated state helper.
- `Packages/ScorlyFeatureRound/Tests/ScorlyFeatureRoundTests/RoundPlayStateTests.swift`
  - Pins non-redundant ARG translation and capture completeness.
- `Packages/ScorlyDesignSystem/Sources/ScorlyDesignSystem/Primitives/StrokesGainedCard.swift`
  - Labels the active comparison reference.
- `Packages/ScorlyReviewKit/Sources/ScorlyReviewKit/SGCardMapping.swift`
  - Continues mapping projected domain totals into design values.
- `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/RoundDetailView.swift`
  - Applies the active SG projection to saved rounds and changes the page title.
- `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/Charts/MultiRoundSGCard.swift`
  - Applies the active SG projection to Trends.
- `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/TrendsView.swift`
  - Passes the reference, removes the right window card, and changes the title.
- `Packages/ScorlyFeatureSettings/Package.swift`
  - Adds the domain dependency for the preference enum.
- `Packages/ScorlyFeatureSettings/Sources/ScorlyFeatureSettings/SettingsView.swift`
  - Adds the SG comparison section and changes the title.
- `Packages/ScorlyFeatureCourses/Sources/ScorlyFeatureCourses/CoursesView.swift`
  - Changes the title.
- `Packages/ScorlyFeatureHistory/Sources/ScorlyFeatureHistory/HistoryView.swift`
  - Changes the title.
- `Packages/ScorlyFeatureRound/Sources/ScorlyFeatureRound/SetupView.swift`
  - Changes both setup hero variants to `Round Setup`.
- `Scorly/Root/RootView.swift`
  - Persists the setting and passes the selected reference plus baseline rounds into features.

## Task 1: ARG Translation and Distance Wheels

- [ ] Add failing tests to `RoundPlayStateTests.swift`:
  - A single ARG shot derives its distance from `approachLandingDistance` without a duplicate slot-local distance.
  - A two-ARG-shot hole records an intermediate landing value as slot 2's start distance.
  - A single ARG shot is complete with its lie plus approach landing distance.
  - `ARGEditorSection.showsTransitionDistance(after:count:)` returns `false` for the final shot and `true` only between shots.
- [ ] Run:

```bash
swift test --package-path Packages/ScorlyFeatureRound --filter RoundPlayStateTests
```

Expected: fail because the new transition and completeness helpers do not exist.

- [ ] Add minimal state helpers:

```swift
func argStartDistance(slot: Int, at index: Int) -> Int?
func setARGTransitionDistance(_ yards: Int?, after slot: Int, at index: Int)
func recordedARGCount(at index: Int) -> Int
```

- [ ] Update typed ARG derivation so slot 1 uses
  `raw.distanceYards ?? entry.approachLandingDistance`, preserving older
  slot-local payloads first and using the new approach anchor as fallback.
- [ ] Replace approach landing chips with:

```swift
DistanceWheel(value: landingDistanceBinding, range: 1...150, step: 1, majorEvery: 10, unit: "YDS")
```

- [ ] Replace ARG buckets in live entry and refinement with transition wheels bound to the following raw slot. Show them only when `slot < count - 1`.
- [ ] Update sign-and-file completeness and Play summary to consume the shared state helpers.
- [ ] Re-run the FeatureRound suite and expect a pass.

## Task 2: SG Reference Projection

- [ ] Add failing `SGComparisonReferenceTests.swift` cases:
  - Scratch returns canonical totals and holes unchanged.
  - Personal baseline selects the newest 20 SG-enabled rounds after sorting and ignores nil-SG rounds.
  - Personal totals subtract each category baseline and recompute total.
  - Personal hole projection distributes the baseline across holes and ends at the recentered total.
  - Personal mode without history falls back to scratch and labels itself accordingly.
- [ ] Run:

```bash
swift test --package-path Packages/ScorlyDomain --filter SGComparisonReferenceTests
```

Expected: fail because `SGComparisonReference` and `SGReferenceProjection` do not exist.

- [ ] Add:

```swift
public enum SGComparisonReference: String, Codable, CaseIterable, Sendable {
    case scratch
    case personalAverage
}

public struct SGReferenceProjection: Sendable, Equatable {
    public let activeReference: SGComparisonReference
    public let totals: SGTotals?
    public let holes: [SGTotals]?
}
```

- [ ] Implement a latest-20 personal baseline helper, category subtraction, and exact hole-baseline distribution with the final hole receiving any Decimal remainder.
- [ ] Re-run the focused domain tests, then the full domain suite.

## Task 3: SG Preference Wiring

- [ ] Add `ScorlyDomain` to `ScorlyFeatureSettings`.
- [ ] Extend `SettingsView` with a `Binding<SGComparisonReference>` and a two-option `ChipGrid` under `STROKES GAINED · COMPARISON REFERENCE`.
- [ ] Persist the setting in `RootView`:

```swift
@AppStorage(SGComparisonReference.userDefaultsKey)
private var sgComparisonReferenceRaw = SGComparisonReference.scratch.rawValue
```

- [ ] Pass the selected reference and baseline rounds into Confirm, Round Detail, and Trends.
- [ ] Project canonical SG totals at each feature boundary before calling `SGCardMapping.cardValues`.
- [ ] Add an active-reference label parameter to `StrokesGainedCard`; render `VS SCRATCH` or `VS PERSONAL AVG` on every SG card.
- [ ] Build affected packages and run existing SG tests.

## Task 4: Trends Filter and Page Titles

- [ ] Remove the read-only Trends window card while preserving the sample-window selector in the sheet.
- [ ] Replace hero phrases with:

```text
Trends
History
Courses
Round Setup
Settings
```

- [ ] Keep the existing mono taglines.
- [ ] Run `make build`.

## Task 5: Verification and Handoff

- [ ] Run focused suites:

```bash
swift test --package-path Packages/ScorlyDomain
swift test --package-path Packages/ScorlyFeatureRound
swift test --package-path Packages/ScorlyFeatureStats
swift test --package-path Packages/ScorlyFeatureHistory
```

- [ ] Run:

```bash
make build
git diff --check
swiftformat --lint <touched Swift files>
```

- [ ] Run strict SwiftLint on newly created Swift files.
- [ ] Report repository-wide verification blockers separately from regressions.
- [ ] Prepare an unstaged handoff packet. Do not stage, commit, push, or open a PR until developer approval.
