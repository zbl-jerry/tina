# Window pinning

Window pinning keeps any window visible above other apps as a live mirror.
The mirror follows the source window's size and contents, can be moved and
resized, and hands input back to the real window when you click it. This
document records the research, the product decisions, the system design and
what was verified.

Tina issue: [#37](https://github.com/zbl-jerry/tina/issues/37).

## Why

Writing code, reading documentation, joining a call or watching logs often
needs one window to stay visible while other apps are used. macOS has no
general answer:

- Split View, Stage Manager and Mission Control rearrange or push aside the
  other windows instead of letting one cover them.
- Picture in Picture covers video only.
- Tina's pinned screenshot keeps an image, not a live window.
- Third-party always-on-top tools are paid, and some require disabling SIP
  because they change other apps' window levels.

The research in issue #37 examined [Topit](https://github.com/lihaoyun6/Topit)
0.1.5 (AGPL-3.0, 2.2 MB DMG). Topit established the behavior: capture a window
with ScreenCaptureKit, draw it in a floating panel, and hand control back to
the real window on hover or click. Its public issues document the hard edges:
input-method candidate windows, cursor placement, full-screen Spaces, menu bar
edges, third-party app switching and long-running streams. The issue concluded
**MVP**, and this implementation follows that boundary: a live mirror over
public APIs, never a change to another app's real window level.

## What it does

A pinned window is a floating panel that shows a live ScreenCaptureKit stream
of the source window:

- **Pick any normal window.** The picker lists on-screen application windows
  in front-to-back order, with the app icon, title and size. Several windows
  can be pinned at once.
- **Live, not a screenshot.** The mirror follows the source window's content
  and resize. Frame rate is adjustable from 1 to 60 frames per second and
  defaults to 30.
- **Floating and movable.** Panels sit above ordinary windows, join every
  Space and can be dragged anywhere or resized with a locked aspect ratio.
- **Hands control back.** Clicking the mirror hides it and raises the real
  window. The mirror returns when the pointer leaves that window. The hand-off
  can also be triggered by hover, and can raise the window without switching
  the active app.
- **Pauses when nobody can see the source.** Capture stops while the source is
  minimized, on another Space, closed or fully covered, and while the user
  pauses a pin.
- **Per-pin actions.** Pause and resume, unpin, hand off, and unpin all are on
  the title bar and the context menu.
- **Closes with its source.** A closed window removes its mirror on the next
  poll.

The issue's MVP, item by item:

| Issue #37 requirement | Where it is met |
|---|---|
| Pick a window from the menu panel, a shortcut or the switcher | Menu panel tile and Settings open the picker. Shortcut and switcher entries are deferred; the issue asks for one entry point. |
| Pin several windows at once | `WindowPinningService` owns one controller per window |
| Live mirror that follows moves, resizes and content | ScreenCaptureKit `desktopIndependentWindow` stream, rebuilt on size change |
| Unpin automatically when the source closes | The 0.5 s WindowServer poll removes a missing window |
| Draggable, resizable, above ordinary windows | `WindowPinPanel`, an `OverlayPanel` at floating level |
| Hover or click hands input to the real window, with a focus option | Click and hover modes; `windowPinningKeepFocus` |
| Unpin, pause, close all per pin | Title bar buttons and context menu |
| 30 Hz default, adjustable; pause when hidden, off-Space or covered | Frame-rate setting, occlusion and visibility rules |
| Feature Hub entry in Windows and Dock, installed on demand | `AppFeature.windowPinning`, `installedByDefault = false` |
| Screen Recording and Accessibility through the permission portal | `feature.permissions` and the permission rows |
| Settings join backup and import | Every preference is in `Defaults.registeredDefaults` |

Deliberately out of this version:

- The mirror never changes another app's real window level. That needs
  private APIs or disabling SIP, which the issue rules out.
- No global shortcut or window-switcher entry yet; the menu panel and Settings
  are the two picker entries.
- No see-through mirror, automatic overlap avoidance, per-app exclusion,
  border or shadow styling, or script/URL entry. The issue lists these as
  follow-ups.
- No promise to cover full-screen Spaces, Stage Manager peeks or system UI.

## Product design

### Where it lives

- **Features hub, Windows and Dock**: one row, uninstalled by default.
  Installing it turns on the pinning switch.
- **Menu panel, Utilities**: a **Window pinning** tile opens the picker. The
  tile can be hidden or reordered like every other panel tool.
- **Settings, Window pinning**: the same picker, the frame rate, the hand-off
  mode, the focus option, the pause option, and the list of live mirrors with
  pause and unpin actions.
- **Each mirror**: a title bar with the source app's icon and title, pause and
  close buttons, and a context menu with use the window, unpin, pause and
  unpin all.

### Choosing a window

The picker shows every normal application window on screen. Background
helpers, floating panels, the Dock, menu bar items, hidden windows, tiny
tooltips and Tina's own windows are excluded. Titles that macOS withholds are
replaced by the app's name, so an unreadable title never becomes an empty row.
Search matches the title or the app name. The picker refreshes while it stays
open, so a window that closes simply leaves the list.

Pinning needs Screen Recording. Without the grant the picker explains the
permission and offers the system prompt instead of showing a list that could
not be mirrored.

### Handing control back

The mirror is an image, so it cannot receive typing. Clicking its body:

1. hides the mirror and stops its stream,
2. raises the real window through Accessibility,
3. activates its app, unless **Keep keyboard focus where it is** is on,
4. brings the mirror back once the pointer leaves the real window's frame,
   or after 30 seconds at most.

Hover mode performs the same hand-off after the pointer rests on the mirror
for 0.35 seconds. Click is the default because it never steals focus while the
pointer merely crosses a panel. Header drags move the panel; body drags move it
too, while a body click without movement hands off.

When keep-focus is on but Accessibility is unavailable, the real window cannot
be raised without activating its app; the code falls back to activation rather
than hiding the mirror over an unchanged screen.

### Pausing

Capture is paused, and the stream torn down, when:

- the user pauses that pin,
- the source window is minimized or on another Space,
- the source is completely covered by ordinary opaque windows,
- the mirror is hidden during a hand-off.

**Pause while the source is hidden** can be switched off, which keeps the
stream alive but still stops the WindowServer polling from pausing it. A
paused mirror keeps its last frame, dimmed, with a Paused badge.

Fully covered means every point of the source frame lies under a higher,
opaque, layer-zero window. Rectangle subtraction computes that exactly instead
of relying on intersection alone, so a dialog that covers most of a window
does not pause it.

## System design

### Files

| Piece | File |
|---|---|
| Pure model, candidate rules, geometry, occlusion | `Sources/Tina/Core/WindowPinningSupport.swift` |
| Strings (all 15 languages) | `Sources/Tina/Core/WindowPinningStrings.swift` |
| Service, WindowServer snapshot, picker model | `Sources/Tina/Services/WindowPinning/WindowPinningService.swift` |
| Capture stream, controller, floating panel | `Sources/Tina/Services/WindowPinning/PinnedWindowController.swift` |
| Picker | `Sources/Tina/UI/WindowPinning/WindowPinningPickerView.swift` |
| Settings page | `Sources/Tina/UI/Settings/WindowPinningSettings.swift` |
| Tests | `Tests/WindowPinningTests.swift` |

Integration points: `FeatureCatalog`, `FeatureRuntime`, `Defaults`,
`FeatureVisibilitySupport`, `SettingsDirectory`, `SettingsView`,
`MenuPanelView`, `PanelLayout`, `FeaturePresets`, `ReleaseChangeAliases`,
`AppDelegate` permission sync lists, `build.sh` test sources.

### Data model

```text
WindowPinCandidate
  windowID: CGWindowID
  pid: pid_t
  appName, title, bundleIdentifier
  frame: CGRect            // WindowServer, top-left origin

WindowPinSummary
  id, title, appName, isPaused

PinnedWindowController
  candidate, source frame and size
  capture: WindowPinCapture
  panel: WindowPinPanel
  user-paused, visibility-paused, handed-off
```

Pins are intentionally not persisted. A mirror is a live object; restoring one
after a relaunch would have to re-identify the same window, which the
WindowServer ids do not guarantee. The preferences that shape new pins are
persisted:

| Key | Default |
|---|---|
| `windowPinningEnabled` | `false` |
| `windowPinningFrameRate` | `30`, clamped to 1–60 |
| `windowPinningHandoff` | `click` (or `hover`) |
| `windowPinningKeepFocus` | `true` |
| `windowPinningPauseWhenHidden` | `true` |
| `panelUtilityWindowPinning` | `true` |

All of them are registered defaults, so Settings backup exports and imports
them with the rest.

### Window enumeration

One `CGWindowListCopyWindowInfo` reading of `.optionOnScreenOnly` and one of
`.optionAll` per poll produce a snapshot shared by every pin:

- the on-screen list is in front-to-back order and provides live frames and
  occlusion order,
- the all list distinguishes a minimized or off-Space window (still present)
  from a closed one (absent),
- owner names and titles come from the same entries; `NSRunningApplication`
  supplies the localized app name, bundle id and activation policy.

A candidate must be layer 0, visible, at least 120×80, owned by another
process, not system chrome and owned by a regular application. This keeps
tooltips, panels, status items and background helpers out.

### Capture

Each pin owns a `WindowPinCapture`:

- `SCShareableContent.excludingDesktopWindows` resolves the window id to an
  `SCWindow`; `SCContentFilter(desktopIndependentWindow:)` restricts capture
  to that window,
- `SCStreamConfiguration` uses the window's backing-scale pixel size (capped
  at 4096 px), `minimumFrameInterval` from the frame rate, BGRA, sRGB, no
  cursor, no shadow, `scalesToFit` and `preservesAspectRatio`,
- frames are converted with one shared `CIContext` and delivered on the main
  queue to the panel's image layer,
- pausing stops the stream and drops it; resuming builds a fresh stream, so
  macOS performs no capture work for an invisible mirror,
- a size or frame-rate change rebuilds the stream with the new configuration.

A generation counter makes a late start or a late frame from a discarded
stream harmless.

### Panel

`WindowPinPanel` subclasses `OverlayPanel`, the borderless panel the Shelf and
pinned screenshots use, at floating level, joining every Space and excluded
from window cycling. Its content view draws a compact title bar and keeps the
live image in a `CALayer` (implicit animations disabled per frame). Window
resizing is delegated to an aspect-locked size that reserves the title bar
outside the source aspect.

### Polling and occlusion

A single 0.5 s timer polls while the feature is engaged. For each pin it
decides:

- window absent from the all list: unpin and close the panel,
- window not on screen: pause,
- window fully covered by higher, opaque, layer-zero windows: pause,
- window resized: update the aspect and rebuild the stream.

The service also refreshes the picker while it is open. Polling stops as soon
as the feature is uninstalled, switched off or loses Screen Recording, and
then every stream and panel is torn down.

### Hand-off and restore

Clicking the body raises the real window through
`AXWindowResolver.element(for:in:pid:)` and `kAXRaiseAction`; the source app is
activated unless keep-focus is on. A 0.1 s timer watches the pointer against
the AppKit-converted source frame and restores the mirror once the pointer
leaves it, with a 30 s ceiling.

### Permissions and lifecycle

The feature declares Screen Recording and Accessibility. The permission portal
lists it under both, and the existing permission sinks re-sync it when either
grant changes. Without Screen Recording the service closes all pins and the
picker explains why. Without Accessibility a mirror still captures and drags,
but hand-off falls back to activating the source app.

## Limits

- The mirror never changes the real window's level, so it cannot cover a
  full-screen Space, a system panel or another app's full-screen window in the
  way the source itself would.
- A window on another Space is paused rather than mirrored across Spaces;
  macOS does not let a ScreenCaptureKit window filter follow a hidden Space.
  The floating panel still joins the current Space.
- Windows that opt out of capture (protected video, some secure fields, the
  lock screen) show black in the mirror. This is a platform guarantee, not a
  bug.
- Occlusion pausing needs every covering window to be opaque and in layer 0.
  A translucent or unusual-level window can keep capture running while the
  source is hard to see.
- Hover hand-off makes the mirror disappear as soon as the pointer rests on
  it, including on its title bar; click mode keeps the panel reachable.
- Pinned mirrors do not survive a relaunch or Settings import.
- A capture stream costs real GPU and battery. The default 30 fps, occlusion
  pause and per-pin pause are the controls that keep that cost proportional to
  what is visible.
- The picker cannot list a window before Screen Recording is granted; macOS
  withholds the needed metadata.

## Verification

Run in the `feature/window-pinning` worktree on this Mac:

| Check | Result |
|---|---|
| `./build.sh --dev` | build succeeded |
| `./build/TinaDeveloper --selftest` | `SELFTEST OK` |
| `./build.sh --test` | `TESTS OK (125807 checks)`, including 113 window-pinning checks |
| `./build.sh` | official build succeeded |
| `./build/Tina --selftest` | `SELFTEST OK` |

The automated checks cover the pure decisions: candidate filtering, first-run
and resize geometry, cascaded placement, exact occlusion, pause rules,
preference defaults, every translation and the catalog contract. They do not
capture a real window, raise one through Accessibility, drag a panel or grant
a permission.

A manual pass still needs a real desktop:

1. Install the feature from the Hub and grant Screen Recording and
   Accessibility.
2. Open the picker from the panel and pin a terminal and a browser window.
3. Move, resize and edit the source windows; confirm the mirrors follow.
4. Move and resize a mirror; click it and confirm the real window rises and
   the mirror returns when the pointer leaves.
5. Minimize the source, move it to another Space, cover it with another
   window, and confirm the Paused badge.
6. Close the source and confirm its mirror disappears.
7. Switch frame rate and hand-off mode; pause and resume a pin; unpin all.
