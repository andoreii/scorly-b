# Trouble Avoidance Strongest Exclusion Design

## Goal

Prevent `TROUBLE AVOID.` from appearing in the Skills profile `STRONGEST`
summary while retaining it as a visible, scored radar axis.

## Behavior

- Trouble Avoidance remains in the eight-axis radar polygon.
- Trouble Avoidance continues to contribute to the overall score.
- Trouble Avoidance remains eligible for `WEAKEST` and `BIGGEST MOVER`.
- Only the `STRONGEST` summary selection excludes Trouble Avoidance.
- If no other axis is supplied, `STRONGEST` uses the existing empty display.

## Implementation

Put the ranking policy next to `RadarAxis`, where it can be unit tested
without rendering SwiftUI. `SkillsRadarCard` consumes that selector instead
of applying `max` directly in the view.

## Verification

Add a feature-stats test where Trouble Avoidance has the highest value and
Approach is next highest, then assert that Approach is selected. Also test
that Trouble Avoidance alone produces no strongest selection. Run the
feature-stats tests and the application build.
