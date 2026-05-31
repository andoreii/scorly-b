# Round Play and SG Reference Quality-of-Life Design

## Scope

This change improves round-play precision, removes redundant around-the-green
entry, simplifies the Trends filter row, adds a user-selectable strokes-gained
reference, and replaces five page hero phrases with direct page titles.

## Round-Play Distance Capture

### Approach landing distance

Replace the `LANDED AT (FROM PIN)` quick-select chip grid in the approach sheet
with the existing horizontal `DistanceWheel`.

- Range: `1...150`
- Step: `1`
- Unit: `YDS`
- Keep the existing conditional visibility: show it only after a non-green,
  non-OB approach result that implies an around-the-green phase.
- Apply the same rule to the par-3 tee / approach editor.
- Continue storing the canonical yard value in
  `HoleEntry.approachLandingDistance`.

### Around-the-green capture

The approach landing distance already anchors the start of the first
around-the-green shot. Do not ask the player to record that value again.

For a hole with `n` inferred around-the-green shots:

- Keep the result lie keypad for every shot.
- Hide the distance wheel for the final shot because the first putt, or the
  holed result, anchors its end position.
- For each non-final shot, show a `LANDED AT (FROM PIN)` distance wheel after
  its lie keypad. Use range `1...150`, step `1`, unit `YDS`.
- Keep the existing domain meaning: each `ARGShot` stores the playable lie and
  distance where that recovery shot starts.
- Source the first ARG slot's distance from
  `HoleEntry.approachLandingDistance`.
- Bind each non-final ARG distance wheel to the following raw
  `ARGShotEntry.distanceYards`, because that selected landing distance becomes
  the next recovery shot's start distance.
- When deriving typed `ARGShot` values, accept an older slot-local first
  distance as a fallback so already-saved local rounds remain readable.
- Update summaries and refinement completeness checks so a one-chip hole is
  considered fully captured when its start lie and approach landing distance
  are present, without a duplicate ARG distance entry.

## Trends Filter Row

Remove the read-only `LAST 10` / `LAST 20` card rendered to the right of the
Trends filter button. Stretch the filter button across the available width,
matching History.

Keep sample-window selection inside the existing aggregate filter sheet.

## Strokes-Gained Reference

### Preference

Add a persistent Settings preference:

- Section: `STROKES GAINED`
- Caption: `COMPARISON REFERENCE`
- Options: `SCRATCH`, `PERSONAL AVG`
- Default: `SCRATCH`
- Persistence: `UserDefaults`

The selected reference applies everywhere SG is presented:

- Sign-and-file preview
- Saved round detail
- Trends multi-round SG card

### Canonical storage

Keep all computed and stored `SGTotals` scratch-relative. Do not alter the
database schema or save a second SG variant.

### Personal baseline

For `PERSONAL AVG`, derive the baseline from the latest 20 completed rounds
that contain SG totals. Ignore rounds without SG data. If no SG-enabled round
exists, render scratch-relative values and label the reference as scratch
until a personal baseline is available.

For category totals, subtract the personal category average from the
scratch-relative value:

```text
personal-relative category = scratch-relative category - personal category average
```

Recompute total as the sum of the four recentered categories.

For single-round cumulative timelines:

- `SCRATCH`: preserve the current per-hole timeline unchanged.
- `PERSONAL AVG`: distribute the personal total baseline evenly across the
  played holes and subtract that per-hole share from each hole SG total.
  Distribute each category average the same way so each recentered hole value
  remains internally consistent.
- The cumulative timeline endpoint must equal the recentered round total.

For Trends, recenter the averaged multi-round SG values. The Trends SG card
does not render a hole timeline.

### Presentation labels

Every SG card must state the active reference:

- `VS SCRATCH`
- `VS PERSONAL AVG`

Do not label a value as personal-relative when the personal baseline is
unavailable.

## Page Headers

Replace the page hero phrase with a direct one-line title while keeping each
page's existing mono tagline:

| Screen | New title |
| --- | --- |
| Trends | `Trends` |
| History | `History` |
| Courses | `Courses` |
| New round setup | `Round Setup` |
| Active-round setup editor | `Round Setup` |
| Settings | `Settings` |

Keep the current hero type treatment and spacing unless a one-line title
requires a small local spacing adjustment.

## Architecture

Add a small domain-level SG reference type and projection helper. The helper
accepts canonical scratch-relative values plus completed rounds, selects the
latest 20 SG-enabled rounds, and returns presentation-ready values for the
chosen reference. Feature views consume that helper and pass active-reference
labels into the existing design-system SG card.

Keep distance-wheel UI changes inside the round feature. Keep the Trends filter
layout change inside the stats feature. Keep preference persistence at the app
composition boundary and pass the selected value into feature views.

## Testing

Add focused coverage for:

- Approach landing wheel stores exact one-yard values.
- Single ARG shot does not ask for a redundant distance.
- Multi-ARG capture requires distance only between ARG shots.
- SG personal baseline uses the latest 20 SG-enabled rounds.
- SG personal recentering subtracts category averages and recomputes total.
- Personal single-round timeline endpoint matches the recentered total.
- Scratch mode preserves existing SG values and timeline.
- Missing personal history falls back to scratch labeling.
- Trends filter row no longer renders a separate window card.
- Updated page header strings.

## Non-Goals

- No Supabase migration.
- No change to canonical yard storage.
- No change to the mathematical scratch benchmark table.
- No personalized expected-strokes curves by lie and distance.
