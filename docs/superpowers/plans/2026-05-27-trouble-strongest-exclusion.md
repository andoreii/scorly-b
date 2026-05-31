# Trouble Avoidance Strongest Exclusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exclude Trouble Avoidance from the Skills profile strongest-area summary without changing its radar score or other summary roles.

**Architecture:** Add a testable `RadarAxis` summary selector and have `SkillsRadarCard` delegate strongest-area selection to it. The radar model remains unchanged, so all eight axes and the overall score continue to use the same values.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, Swift Package Manager

---

### Task 1: Strongest-Area Selection Policy

**Files:**
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/RadarAxis.swift`
- Modify: `Packages/ScorlyFeatureStats/Sources/ScorlyFeatureStats/Charts/SkillsRadarCard.swift`
- Test: `Packages/ScorlyFeatureStats/Tests/ScorlyFeatureStatsTests/TrendsModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
@Test("Trouble Avoidance is not eligible for strongest area")
func radarStrongestExcludesTroubleAvoidance() {
    let axes = [
        RadarAxis(key: .troubleAvoidance, windowValue: 100, seasonValue: 100),
        RadarAxis(key: .approach, windowValue: 80, seasonValue: 80),
    ]
    #expect(RadarAxis.strongest(in: axes)?.key == .approach)
}

@Test("Trouble Avoidance alone does not become strongest area")
func radarStrongestHasNoTroubleOnlyFallback() {
    let axes = [RadarAxis(key: .troubleAvoidance, windowValue: 100, seasonValue: 100)]
    #expect(RadarAxis.strongest(in: axes) == nil)
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
swift test --filter TrendsModelTests.radarStrongest
```

Expected: compilation fails because `RadarAxis.strongest(in:)` does not exist.

- [ ] **Step 3: Add the selector and use it in the view**

```swift
static func strongest(in axes: [RadarAxis]) -> RadarAxis? {
    axes
        .filter { $0.key != .troubleAvoidance }
        .max { $0.windowValue < $1.windowValue }
}
```

Replace the `SkillsRadarCard` direct `max` selection with:

```swift
let strongest = RadarAxis.strongest(in: axes)
```

- [ ] **Step 4: Run verification**

Run:

```bash
swift test
make build
git diff --check
```

Expected: all feature-stats tests pass, the application build succeeds, and the diff check has no output.

- [ ] **Step 5: Prepare git handoff**

Do not stage in the current dirty worktree. Present the modified files and a
draft commit/PR message for developer approval before any git mutation.
