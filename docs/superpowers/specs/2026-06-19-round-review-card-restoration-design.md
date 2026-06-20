# Round review card restoration

## Context

The newer analytical card design for Sign & File and Round Detail was saved in the 17 June worktree stash but never committed. Later Trends and Round Play work merged from branches based on the older shared review primitives, leaving both round-review screens on the previous card layout.

The recovered work includes valid design-system primitives and additional round metrics, but the stash also contains unrelated and now-obsolete Trends changes. Applying the stash wholesale would overwrite newer behavior.

## Goal

Restore the recovered analytical card design on Sign & File and Round Detail while preserving all behavior currently on `main`.

Success means both screens use the same compact disclosure-card stack and reveal the recovered detailed analysis when expanded. Filing, deletion, strokes-gained refinement, comparison references, scorecard rendering, and navigation must continue to work unchanged.

## Approach

Selectively port the recovered shared review primitives and metric calculations, then manually merge them with the current feature views. Do not apply the complete stash.

This keeps the visual implementation faithful to the recovered version while avoiding changes to the newer Trends dashboard and Round Play flow.

## Shared card behavior

Add a reusable `ReviewDisclosureCard` shell in `ScorlyDesignSystem`.

- The collapsed state shows the card metadata, title, key metric, and disclosure indicator.
- Tapping the header toggles the analytical content with the established motion curve and soft haptic.
- Cards start collapsed so the full round remains scannable.
- The shell retains the brutalist border, corner registration marks, bone-paper background, mono metadata, and accessible expand/collapse labeling.
- Reduce Motion replaces the expansion transition with the design system's adaptive behavior.

The shared card stack consists of:

1. Strokes gained: total metric when collapsed; gained/lost split, ranked categories, strongest and weakest categories, and cumulative timeline when expanded.
2. Fairway accuracy: FIR metric when collapsed; directional windrose and miss-type legend when expanded.
3. Green accuracy: GIR metric when collapsed; directional windrose and miss-type legend when expanded.
4. Putting: putts per hole when collapsed; total and average heroes, one/two/three-putt distribution, and running average chart when expanded.
5. Scoring distribution: par-or-better percentage when collapsed; score-to-par hero and outcome spectrum when expanded.

The hero stamp and hole-by-hole scorecard remain permanently visible above the analytical cards.

## Data and compatibility

Extend `RoundDetailMetrics` with values required only by the restored visualizations:

- `scoreToPar`
- cumulative `puttingAverageProfile`
- one-putt, two-putt, and three-putt-plus distribution

These values are derived from the same played-hole snapshots already used for the existing cards. Back-nine rounds retain printed hole numbers 10 through 18.

Current behavior must be merged into the recovered card API:

- Sign & File retains the estimated-hole refinement entry point and sheet.
- Both screens retain the selected strokes-gained comparison reference.
- Personal baseline values remain visible only when the active comparison is scratch.
- Sign & File retains notes, signature gating, persistence, and finish navigation.
- Round Detail retains delete confirmation, repository deletion, error reporting, and archive navigation.
- Existing make-rate data remains available to other consumers even though the restored single-round Putting card uses round distribution and running average.

## Scope

Expected new shared primitives:

- `ReviewDisclosureCard.swift`
- `PuttingProfileChart.swift`

Expected restored or extended files:

- shared strokes-gained card and chart helpers
- accuracy rose card
- putting summary card
- scoring distribution card
- review chart value types
- design-system statistical color tokens
- `RoundDetailMetrics.swift`
- `ConfirmView.swift`
- `RoundDetailView.swift`

Unrelated Trends, Round Play, storage, synchronization, and schema code are out of scope.

## Verification

Follow a regression-first implementation:

1. Add failing `RoundDetailMetrics` tests for score-to-par, cumulative putting averages, putt distribution, empty rounds, and back-nine numbering.
2. Add focused design-system tests for any extracted pure layout or summary calculations needed by the restored cards.
3. Port the smallest recovered implementation required to pass those tests.
4. Run the affected package tests, then the complete package test suite and application build.
5. Launch the app in the iPhone 17 simulator and inspect Sign & File and Round Detail in collapsed and expanded states, including small-content and unavailable-SG cases.
6. Confirm accessibility labels and Reduce Motion behavior for disclosure headers.

## Risks

- Replacing entire files from the stash would remove newer comparison-reference and refinement behavior. Mitigation: merge card call sites manually.
- The recovered work depends on two files stored as untracked stash content. Mitigation: restore those files explicitly and include them in build verification.
- Chart geometry can compile while rendering poorly at narrow widths. Mitigation: simulator inspection on the project-standard device and content-size checks.
