# Multi-window tiling

Tina's window layout actions arrange one window at a time. Tiling adds three
actions that arrange **every ordinary window on one display** at once: a
balanced grid, rows, and columns. Pressing the same action again cycles through
distinct layouts instead of leaving the desktop unchanged.

This document records the research, the product decisions, the system design
and what was verified, for issue [#12](https://github.com/zbl-jerry/tina/issues/12).

## Why

A desktop with five to eight windows is common, and placing each one with a
half, third or corner shortcut is slow and imprecise. The upstream project
investigated for the issue, [Rectangle](https://github.com/rxhanson/Rectangle)
v2.0.4, treats multi-window arrangement as a first-class feature.

The reference implementation was read at tag `v2.0.4`:

- `Rectangle/MultiWindow/GridTiling.swift` enumerates band layouts, skips
  duplicate groupings, and advances only while the tracked windows still sit
  where the previous press left them.
- `Rectangle/MultiWindow/MultiWindowManager.swift` selects the display from the
  focused window (or the pointer), orders windows by their upper-left corner,
  and caps Rows and Columns with independent limits that default to 3.
- The README documents the user-facing contract: one window per row or column
  on the first press, balanced groups with no deliberately empty cells,
  duplicate layouts skipped, and app size restrictions taking precedence.

Tina already owns everything the feature needs: Accessibility frame writes, the
settle and read-back retry path, edge gaps, Stage Manager reservations, the
ignored-app list and global shortcut registration. No new permission, helper
or background process is involved.

## What it does

Three actions live with the other window layout actions:

- **Tile all windows** arranges the display into a balanced grid. It starts
  with one row and adds rows on repeated presses, alternating which row gets
  the extra window when that produces a different grid. Five windows cycle
  through `1×5`, `3+2`, `2+3`, `2+2+1` and `1+2+2`.
- **Tile in rows** starts with one window per row and then uses fewer rows,
  keeping the number of windows in a row at or below **Maximum windows per
  row** (default 3). Five windows with the default limit cycle through
  `1,1,1,1,1`, `2,2,1` and `3,2`.
- **Tile in columns** mirrors that across the vertical axis, using **Maximum
  windows per column** (default 3). Six windows cycle through six columns of
  one, three columns of two, and two columns of three.

Both limits are adjustable from 1 to 6 in **Settings → Window layout →
Tiling**. Tile all uses the larger limit as its row ceiling, so raising either
one lets it use more rows.

The target display is the one holding the focused window. When no ordinary
window is focused, the display under the pointer is used, matching Rectangle
and Tina's pointer actions. Only windows in the current Space are eligible:

- regular, non-hidden apps, excluding Tina itself and apps on the Window
  Layout ignore list;
- ordinary windows that are on screen, not minimized, not full-screen and not
  floating;
- windows larger than 80 by 80 points that expose settable position and size.

Windows are ordered from the upper-left corner, top to bottom and then left to
right, before the layout is assigned. The layout respects the configured window
and screen gaps, the menu bar and Dock reservations, and Stage Manager's strip
reservation.

A window that refuses AX writes stays where it is and does not stop the rest.
It is left out of the cycle's intact-window check, so the next press still
advances the windows that did move. A window that accepts a clamped size counts
as arranged. After every press a short, non-activating panel says how many
windows took the layout and how many did not respond.

### Deliberately not in this version

- Tiling across several displays at once.
- Cascade and stacked-window cycling.
- Animated transitions and persisted layout grids. The cycle state lives in
  memory for the app session, like Rectangle's.
- Redistributing space after an app reports a minimum size. A clamped window
  may leave a larger gap or overlap its neighbour; the next press reapplies the
  layout.
- Mouse-button shortcuts for the tiling actions. Tina's mouse-button support
  does not yet feed window actions.

## How it works

### Pure layout model

`WindowTilingLayout` turns a window count and the two limits into candidate
band populations:

- `bandLayouts` follows Rectangle's cycle: subdivision `s` from 1 to the limit
  yields `1 + (n - 1) / s` bands, and duplicate band counts collapse. Balanced
  populations put the remainder in the leading bands.
- `tileAllLayouts` walks row counts from 1 to the larger limit and emits both
  the top-heavy and bottom-heavy population for each, skipping duplicates.
- `sortedForTiling` orders window identities by their AX frame origin, which
  is top-left based.

`WindowTilingGeometry` turns populations into frames. It rounds each shared
edge once, so neighbouring tiles neither overlap nor leave a rounding gap, and
takes half of the configured window gap off every internal edge. The screen gap
is applied to the work area first with the existing `screenGapFrame`.

`WindowTilingCycle` is the repeat rule: advance to the next distinct frame set,
and recognise a grid that is still intact. Moving or resizing a window by hand
makes the grid unrecognisable and restarts the cycle.

### Service integration

`WindowLayoutService.apply` branches to `applyTiling` before the single-window
focus lookup. The tiling path:

1. picks the display (focused window, else pointer);
2. enumerates and filters the windows with a bounded 0.35 s AX timeout per app;
3. computes every candidate frame set for the required window count;
4. chooses the next index from the per-display, per-action cycle record;
5. writes each frame through the same bounded AX size/position helpers, with a
   second write pair only when the first read-back missed;
6. records prior frames in the existing per-window history, so the focused
   window can still be restored afterwards;
7. stores actual read-back frames and the tracked window set for the next
   press, and shows the confirmation panel.

Writes use the existing `EnhancedUserInterfaceSuspension` and cancel any settle
timer belonging to the same window, so a tiling press cannot fight a
single-window placement that is still settling. Tiling does not create settle
timers of its own: each window is read back immediately and the run continues.

### Settings and backup

`windowTilingMaxWindowsPerRow` and `windowTilingMaxWindowsPerColumn` are
registered preferences, so they travel with Settings backup. The three shortcut
keys and their action identifiers are registered too. All three actions start
unassigned, like every newer window layout action, and appear in
**Settings → Window layout**, **Settings → Shortcuts** and the panel's window
layout grid.

## Verification

Run in the `tina-tile-windows` worktree:

- `./build.sh --test --test-suite=window-tiling` passes 58 checks covering
  candidate generation, duplicate collapsing, clamping, ordering, frame
  geometry, gaps, cycle advance/restart, action identifiers and every
  language's text format.
- `./build.sh --test` passes the full suite (124,912 checks), including the
  localization contract and the repository text checks.
- `./build.sh --dev` builds and signs the developer bundle.
- `./build.sh` builds and signs the official bundle, and `./build/Tina
  --selftest` reports `SELFTEST OK`.

Not verified here: live multi-window Accessibility behaviour, the confirmation
panel's placement, and per-app minimum-size clamping were not exercised against
a real desktop. The build and unit tests prove the layout model and the
integration compiles; they do not prove that every app accepts the writes. A
manual pass with several apps, a Dock and a menu bar should confirm the
intended result before release.

## Limits

- Windows on other Spaces and minimized windows are out of scope, matching the
  current-Space rule.
- A window whose app enforces a minimum or fixed size may not match its cell.
  The layout still assigns the other windows and the next press retries.
- An unresponsive app costs its own bounded AX timeout before the run moves on;
  a tiling press is therefore synchronous and can be delayed by a hung app.
- The cycle is remembered per display and action, not across app launches.
- Tile all may use more rows than either limit when both are raised; the two
  limits bound the row and column band populations of their own actions.
