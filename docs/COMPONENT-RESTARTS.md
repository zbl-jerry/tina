# System component restarts

Quick toggles can restart the Dock, the Finder, the menu bar or the
third-party input method in use without logging out or rebooting the Mac.
This document records the research, the product decisions, the system design
and what was verified.

Tina issue: [#36](https://github.com/zbl-jerry/tina/issues/36).

## Why

Most Mac failures are local rather than system wide: a Dock icon stops
responding, menu bar icons disappear or shift, a Finder window stops
refreshing, or a third-party input method hangs and will not produce
candidates. macOS has no per-component restart control. The alternatives are
Activity Monitor (which first requires knowing that the Dock is `Dock` and the
status items are `ControlCenter`), `killall` in Terminal, or rebooting the
whole Mac and reopening the working set.

The research in issue #36 examined [FixTim](https://github.com/Lakr233/FixTim)
(v1.2.1, MIT, 3.2 MB zip). FixTim offers a one-click soft restart of the whole
user session. That clears every local failure at once, but it also quits every
app and discards unsaved work; its own issues #3 and #5 record side effects
(corner-triggered screen saver stops working, some login items fail to return,
Safari breaks). The useful part is narrower: restart only the component that is
stuck, keep every other app running, and keep the action reversible.

The issue concluded **MVP**: four user-domain components, a short confirmation
before each, a visible result, no privileged helper and no new permission.
This implementation follows that boundary and extends the existing Quick
toggles feature instead of adding a feature-catalog entry: the rows inherit the
feature's availability, permission checks, panel layout, visibility keys and
settings backup.

## What it does

Four rows join the Quick toggles list, in the menu bar panel and in the Quick
panel (⌃⌘V):

- **Restart the Dock** relaunches the Dock, restoring icons, previews and
  stacks. Open apps and windows are untouched.
- **Restart the Finder** reloads the Finder and its windows. It reuses the
  polite quit-and-relaunch path the hidden-files and desktop-icons rows already
  use, falling back to `killall` when the Finder will not quit.
- **Restart the menu bar** relaunches the process that hosts the system status
  items (`ControlCenter`, plus `SystemUIServer` where that process still
  exists), restoring icons that disappeared or moved.
- **Restart the input method** relaunches the third-party input method in use
  and leaves the selected input source preference alone. No third-party input
  method means the row is disabled and says so.

Every restart confirms first, in the same alert the Trash action uses, and says
what will briefly disappear. The row then reports progress, success or failure
in its caption. Failures are never silent.

The issue's MVP, item by item:

| Issue #36 requirement | Where it is met |
|---|---|
| Four rows beside Empty the Trash and Quit all apps | `QuickToggleAction.restartDock/restartFinder/restartMenuBar/restartInputMethod`, `QuickTogglesSection` |
| Restart the Dock and its icons, previews and stacks | `QuickTogglesService.restartDock`, `killall Dock` with a `launchctl kickstart` fallback |
| Restart the Finder politely, then forcibly, reusing the existing logic | `restartFinder()` shared with the hidden-files and desktop-icons rows |
| Restart the menu bar hosts | `QuickTogglesSupport.menuBarHostNames`, probed at run time |
| Restart the current third-party input method | `QuickTogglesSupport.inputMethodTarget`, `restartInputMethod` |
| Disable the input method row with a reason when none is running | `inputMethodTarget == nil` disables and captions the row |
| Confirm before each action and describe what disappears | `requestRestart`, per-action confirmation copy |
| Report the result, never fail silently | `RunState.running/succeeded/failed`, caption in the row |
| Follow the Kill Process protection rules | `KillProcessSupport.isProtectedName`, checked before every kill |
| No new permission or privileged helper | Process relaunch only; the Finder reuses the existing Automation grant |

Deliberately out of this version:

- A one-click soft restart of the whole user session, or logging every app out.
- Automatic detection of a stuck component and an unprompted repair prompt.
- Restarting `coreaudiod`, `WindowServer`, `launchd` or anything else that
  needs root, a privileged helper or a session restart.
- Restoring the exact window state of apps after a restart; nothing is quit
  except the chosen component.
- Dock layout backup and restore (the optional follow-up in issue #36).

## Product design

### Where it lives

The four rows are part of the existing **Quick toggles** section, so they
appear in:

- the menu bar panel's Quick toggles tab,
- the Quick panel opened with ⌃⌘V,

with the same order, per-row visibility toggles, drag handles and reset action
as every other row. Existing saved orders keep their order; the four new rows
are appended to the end of a saved order. Fresh installs get them grouped
after **Quit all apps**.

The rows are not added to the Radial menu. Its quick-toggle wheel is a
separate, deliberately short list; adding four process actions there would
turn a quick pointer gesture into a destructive menu.

### Row behavior

- **Idle**: title, one-line description as the tooltip, no caption.
- **Click**: a warning alert names the component and explains what disappears
  for a moment. Cancel is the second button (Escape); Restart is the first
  (Return). Nothing runs before the primary button is pressed.
- **Running**: the row is disabled and reads "Restarting…".
- **Success**: the caption reads "Restarted." for about 2.4 seconds, then the
  row returns to idle.
- **Failure**: the caption reads "Could not complete." and stays visible until
  the next attempt. The component's own reload is the proof of success; the
  service does not claim a restart it could not start.
- **Input method with no third-party method running**: the row stays visible
  and draggable in edit mode, is dimmed and disabled, and the caption explains
  that no third-party input method is running.

### Confirmation copy

The confirmations call out the interruption rather than the mechanism:

- Dock: icons, previews and stacks disappear for a moment; apps and windows
  are not affected.
- Finder: windows close and come back; a file operation in progress may be
  interrupted.
- Menu bar: the bar and its status items disappear for a moment; apps keep
  running.
- Input method: uncommitted candidates are lost; other apps are not affected.

### Permissions and safety

- No new permission. The Dock, the menu bar and the input method are the
  user's own processes, reached without Automation consent. The Finder reuses
  the Automation grant already used by Empty the Trash and the Finder flag
  rows; without it, `killall` is the fallback.
- The Kill Process protection rule is applied before every termination:
  `kernel_task`, `launchd`, `WindowServer`, `loginwindow` and Tina itself are
  never candidates. The names this feature can touch are a fixed allow list,
  not user input.
- Restarting the menu bar never touches `WindowServer`; a session stays intact.

## System design

### Types

- `QuickToggleAction` gains four storage ids: `restartDock`, `restartFinder`,
  `restartMenuBar`, `restartInputMethod`. They map to `AppFeature.quickToggles`,
  so availability, the feature hub, the section gate and settings backup apply
  without new plumbing.
- `QuickTogglesService.RunState` gains `succeeded` for the transient result
  caption. Success states reset after 2.4 seconds; failure and permission
  states stay until the next run or a permission refresh.
- `QuickTogglesService.InputMethodTarget` is a runtime binding (bundle id,
  localized name, bundle path, pid). The published value drives row enablement.
- `QuickTogglesSupport.InputMethodCandidate` and the pure
  `inputMethodTarget(sourceID:candidates:)` decision keep AppKit and Carbon out
  of the tested layer.

### Resolving the input method

The third-party input method to restart is chosen in this order:

1. The current keyboard input source id (TIS) is matched against running apps
   whose bundle lives under `.../Input Methods/` and outside `/System/`. The
   longest bundle-id prefix wins, which handles ids such as
   `com.tencent.inputmethod.wetype.pinyin` for the app
   `com.tencent.inputmethod.wetype`.
2. If the current source is an Apple layout but exactly one third-party input
   method is running, that one is the target. This is the common "the input
   method is stuck and cannot even be selected" case.
3. Otherwise the target is ambiguous or absent, and the row is disabled rather
   than restarting the wrong input method.

The TIS and `NSWorkspace` reads run on the main thread (`refreshInputMethodTarget`,
called when the list appears and again before the confirmation). The actual
termination and relaunch run on the service's work queue.

### Restart strategies

| Component | Strategy | Why |
|---|---|---|
| Dock | `killall Dock`; `launchctl kickstart -k gui/<uid>/com.apple.Dock` when that fails | launchd relaunches the Dock by itself; the fallback covers a process that ignores SIGTERM |
| Finder | Existing `restartFinder()`: polite quit when the Automation grant is present, otherwise `killall Finder` | No duplicate logic; the Finder restarts itself under launchd |
| Menu bar | Probe `pgrep -x` for `ControlCenter` and `SystemUIServer`, `killall` only the ones present | Host names differ across macOS releases; killing an absent name would report a false failure |
| Input method | `terminate()` → wait → `SIGKILL` fallback → reopen the bundle | The app may not answer a quit event; the bundle path was captured before the kill |

All killing runs off the main thread. Each strategy returns a Boolean; only
`true` maps to `succeeded`.

### Preferences

Four visibility keys join the quick-toggle set:
`panelToggleRestartDock`, `panelToggleRestartFinder`,
`panelToggleRestartMenuBar`, `panelToggleRestartInputMethod`. They are
registered `true`, included in `panelToggleOrder`, reset by the section's reset
action, and travel in settings backup like the other quick-toggle keys.

### Localization

All new copy is part of `QuickToggleFeatureStrings`, which carries one static
per language. The fifteen languages are updated together, and a test checks
that every new field is present and non-empty in each of them.

## Verification

- `Tests/QuickTogglesRestartTests.swift` pins the pure rules: action ids and
  feature mapping, menu-bar host probing, input-method target selection
  (current source, single fallback, ambiguity, Apple layouts), protected names,
  registered defaults, saved-order migration and localization coverage.
- `./build.sh --test` runs the whole suite, including the existing Quick
  toggles contracts.
- The restart paths themselves are manual checks on a Mac: each confirmation,
  each success caption, the disabled input-method row, and a failed Finder
  restart during a copy. They are reported in the pull request rather than
  automated, because terminating the host's Dock, Finder or menu bar from a
  test run would disrupt the machine running the tests.
