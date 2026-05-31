# Round Detail Overhaul Design

## Goal

Turn Round Detail into a complete read-only review of one filed card. It
retains the existing hero stamp, adds the full scorecard, and reuses the
Trends visual vocabulary for strokes gained, accuracy, putting, and scoring.

## Screen Order

1. Existing inverse round hero stamp.
2. Full read-only scorecard.
3. Strokes gained.
4. FIR wind rose.
5. GIR wind rose.
6. Total putts, average putts per hole, and make percentage by distance.
7. Scoring distribution.
8. Existing delete action and end-of-record footer.

## Presentation

The screen remains a paper-ledger review surface using the existing
bone-cream ground, ink rules, mono metadata, tabular numerals, and scorecard
pip notation.

The scorecard adopts the live scorecard sheet's filed-card vocabulary:
front-nine and back-nine groups when applicable, hole and par headers, pip
notation, group totals, and the birdie/par/bogey legend. It is read-only and
does not include the live GIR, FIR, putts, or three-putt summary strip.

Strokes gained uses the compact Trends category-row styling for the four
categories but preserves the selected round's cumulative hole-by-hole SG
timeline. It may continue showing the existing season-average comparison
marker as context; all primary values and timeline points belong to the
selected round.

FIR and GIR use the same wind rose composition seen in Trends. FIR includes
fairway opportunities for this round only. GIR includes played holes for this
round only.

Putting leads with total putts and average putts per played hole, followed by
the same distance-bucket make-rate bar visualization used in Trends. A round
without recorded putt distances renders empty distance buckets rather than
inventing values.

Scoring distribution uses the same outcome-donut vocabulary as Trends and
counts only completed holes in this round.

## Architecture

`ScorlyFeatureHistory` must not import `ScorlyFeatureStats`, and
`ScorlyDesignSystem` must not import domain types. Shared Trends
visualizations therefore move to design-system primitives with small
presentation-only value types:

- Wind rose data, chart, and accuracy card.
- Putt make-rate bucket input and make-rate card.
- Hole-outcome input and distribution card.
- A read-only scorecard primitive driven by preformatted hole values.

Stats maps its existing aggregate calculations into those shared value
types. History introduces a single-round presentation mapper that derives
the scorecard rows, wind rose inputs, putt buckets, and outcome counts from
`CompletedRound` and `HoleStat`, then feeds the shared primitives.

The scorecard stays presentation-only in the design system rather than
sharing `RoundPlayState`, because the detail page does not own live editing
state or sheet interactions.

## Data Rules

- Every new accuracy, putting, and scoring figure is computed from the
  selected `CompletedRound` only.
- FIR denominator is fairway opportunities, excluding par-three holes.
- GIR denominator is played holes.
- Average putts per hole divides total putts by completed holes with recorded
  strokes; when there are no completed holes it displays an empty value.
- Make percentage includes only putts with recorded distances and treats the
  final logged putt on a completed hole as made, matching Trends.
- Scoring distribution omits holes without a positive stroke total.
- Missing strokes-gained data retains the current inline unavailable state.

## Verification

Add focused tests for the History single-round mapper before implementing its
view wiring: FIR/GIR rose inputs, putting totals and buckets, scoring outcome
counts, and scorecard grouping for nine and eighteen holes. Keep or adapt
Stats aggregate tests while moving shared presentation input types, ensuring
the Trends screen still receives equivalent values. Run package tests,
architecture tests, formatting checks where available, and an application
build.

## Constraints

- Preserve the existing round hero stamp.
- Do not add feature-to-feature imports.
- Do not alter unrelated in-progress changes in the dirty worktree.
- The React reference source listed in project guidance is not present in the
  local workspace, so existing SwiftUI implementations define the reusable
  visual baseline for this change.
