# Display presets

Display presets save one working arrangement of the connected displays and
bring it back in one click, one shortcut, or automatically when a display
connects or disconnects. This document records the research, the product
decisions, the system design and what was verified.

Tina issue: [#11](https://github.com/zbl-jerry/tina/issues/11).

## Why

Tina already controls each display's brightness, each monitor's speakers and
whether a display is on. What it cannot do is restore a whole arrangement.
People who move a laptop between a desk dock and a home setup change the same
resolution, brightness, volume and main-display choices every day, and macOS
remembers only part of that. The alternatives are paid tools with their own
background helpers, or adjusting each control by hand.

The research in issue #11 examined the upstream project
[Crisp](https://github.com/didriksg/Crisp) (v1.7.1, MIT, 4.9 MB DMG). Crisp's
free tier covers display presets, arrangement and brightness; HiDPI scaling,
virtual displays, input switching and ICC/HDR are separate or paid concerns.
The issue concluded **MVP**: presets over the public display APIs, with HiDPI
scaling deferred because it needs the private CoreDisplay interface.

This implementation follows that boundary and extends the existing Displays
card instead of adding a new feature-catalog entry: a preset is a named
snapshot of controls Tina already owns, so it inherits the brightness
feature's availability, permissions and settings backup.

## What it does

A preset stores, for every display connected when it was saved:

- the display's resolution (logical size, backing pixel size and refresh rate),
- its brightness, when the display exposes a brightness route,
- its monitor speaker volume and mute state, when the monitor has speakers,
- the main-display choice.

Presets can be:

- **applied from the menu bar panel**, one chip per preset, and from Settings;
- **bound to a global shortcut** each (Carbon hotkeys, no Accessibility grant);
- **applied automatically** when a chosen display connects or disconnects;
- **updated from the current setup**, renamed, given another icon, or deleted.

Applying a preset reports every item it could not apply, per display and per
control. Nothing is silently skipped.

The issue's MVP, item by item:

| Issue #11 requirement | Where it is met |
|---|---|
| Save resolution, brightness, monitor volume and the main display for every display | `DisplayPresetService.captureDisplays`, `DisplayPreset` |
| Name and icon per preset | Create/edit sheet, validated symbol list |
| Apply from the menu panel | Preset chips in the Displays section |
| Bind a global shortcut | Per-preset Carbon hotkey, recorder in the editor |
| Apply when a chosen display connects or disconnects | One automatic rule per preset, topology observer |
| Report failed items instead of failing silently | `DisplayPresetReport`, failure list on both surfaces |
| Save only what public APIs can read and write | CoreGraphics modes and origins, existing brightness and DDC routes |
| Hide unsupported items in the editor | The editor only offers name, icon, shortcut and rule; capture skips what has no route |

Deliberately out of this version, matching issue #11's MVP:

- HiDPI/Retina scaling, virtual displays, ICC/HDR, input switching.
- Physically powering a display off (Tina's software display on/off is also not
  part of a preset in this version, so a preset never turns a working display
  dark).
- Window positions, wallpapers or Spaces.
- Per-display color profiles.

## Product design

### Where it lives

Presets sit in the existing **Displays** surfaces:

- **Menu bar panel, Displays card**: one compact chip per preset, plus a
  failure list after an apply. Chips appear only when at least one preset
  exists, so the panel does not grow for people who never use the feature.
- **Settings → Energy → Displays**: the management surface. Each row carries
  the preset's icon and name, Apply, Update from current, its shortcut field,
  its automatic rule, Edit and Delete. **Save current setup** creates a preset
  from what is connected now.

The feature is available with the Displays feature (`AppFeature.brightness`).
When the brightness feature is uninstalled, the preset service stops, its
hotkeys are released and no automatic rule runs. Brightness and monitor-speaker
items apply only while those controls are switched on; resolution and the main
display do not require them.

### Saving

Saving captures the state at that moment, so a preset is a snapshot, not a
live rule. It always captures every display Tina can see, including a display
Tina switched off in software (that display contributes no resolution, because
it has no mode while it is off).

The save/edit sheet asks for:

- a name (a blank name becomes "Preset"),
- one of a small set of SF Symbols,
- optionally an automatic rule: a display from the snapshot and whether the
  preset applies when that display connects or disconnects.

Editing changes only the name, icon and automatic rule. Capturing new values
is a separate **Update from current** action, so editing a name cannot
silently overwrite a working setup.

### Matching displays

A display is identified by its vendor, model and serial numbers, the same
identity the brightness feature uses for DDC paths and display restoration.
The built-in panel is matched by the same identity; two identical external
monitors that report the same identity are distinguished by their position in
the snapshot, which is stable for a given arrangement.

A display that is not connected is reported as such and its items are skipped.
A snapshot taken on one Mac therefore remains readable on another, but its
resolution and automatic rules are only meaningful where the same hardware is
present.

### Failure reporting

After an apply, the surface that started it shows every item that did not
apply:

- the display is not connected,
- the display does not support the saved resolution,
- the resolution change was refused or did not take effect,
- the display has no brightness control,
- the monitor's speakers are not available,
- the saved display could not become the main display.

A DDC channel that accepts a write and ignores it cannot be detected through
the public I2C API; that limitation is the same one the brightness sliders
have and is stated in [Limits](#limits).

### Automatic rules

One rule per preset, at most. When several presets match one display change,
the first in the preset list wins; this is documented rather than hidden so
that ordering is predictable. Automatic applies wait for the display
topology to settle, and are suppressed for a few seconds after any apply, so a
preset that changes resolution does not re-trigger itself.

## System design

### Files

| Piece | File |
|---|---|
| Model, matching, mode choice, reports, identities | `Sources/Tina/Core/DisplayPresetSupport.swift` |
| Strings (all 15 languages) | `Sources/Tina/Core/DisplayPresetStrings.swift` |
| Service: capture, apply, rules, hotkeys, storage | `Sources/Tina/Services/Display/DisplayPresetService.swift` |
| Settings surface | `Sources/Tina/UI/Settings/DisplayPresetSettings.swift` |
| Panel chips | `Sources/Tina/UI/MenuPanel/BrightnessSection.swift` |
| Tests | `Tests/DisplayPresetTests.swift` |

### Data model

```text
DisplayPreset
  id: UUID
  name: String
  symbol: String
  displays: [Display]
    fingerprint: "vendor:model:serial"
    name, isBuiltIn
    resolution? { width, height, pixelWidth, pixelHeight, refreshRate }
    brightness? Double
    volume? Double, muted? Bool
  mainDisplayFingerprint: String?
  shortcut: String?          // GlobalShortcut storage form
  trigger? { fingerprint, displayName, event: connected | disconnected }
```

The list is JSON in one registered preference (`displayPresets`), so it
travels with Settings backup like every other preference. Decoding is
fail-soft: unknown fields are ignored, out-of-range values are clamped, an
invalid symbol or shortcut is dropped, and a preset that no longer has a name
or a display entry is discarded rather than crashing the app.

### Capturing

The service reads the brightness service's display list, the current mode from
`CGDisplayCopyDisplayMode`, and the main display from `CGMainDisplayID`. It
never guesses a mode from the display's name and never reads private APIs.

### Applying

1. **Resolve** each saved display to a live display by identity.
2. **Choose modes.** Enumerate the live display's modes with
   `CGDisplayCopyAllDisplayModes` including duplicate low-resolution modes, and
   pick the exact logical size, backing pixel size and closest refresh rate.
   No match is a per-display failure, decided before any hardware write.
3. **Commit resolutions** in one `CGBeginDisplayConfiguration` transaction.
   Each display is read back afterwards; a mismatch restores that display's
   previous mode and reports a failure.
4. **Set the main display** in a second transaction by translating every active
   display's origin so the chosen display sits at `(0, 0)` (the public
   definition of the main display). Mirrored and virtual displays are left
   alone. The result is verified with `CGMainDisplayID`.
5. **Brightness and volume** are applied after the topology settles: brightness
   through `BrightnessService.setBrightness`, monitor volume through the
   existing DDC speaker route. Items with no live route are reported instead of
   written blindly.
6. **Publish a report** with per-item failures. Late volume failures append to
   the same report while that apply is still the newest one.

Resolution changes happen on the main thread because display reconfiguration
and SwiftUI layout are both main-thread concerns in this app; the work is a
short configuration transaction, not a wait on DDC.

### Main display through origins

macOS has no public "set main display" call. The main display is the one whose
global bounds start at `(0, 0)`. Moving the target display's origin to `(0, 0)`
and translating every other display by the same vector preserves the relative
arrangement and changes only which display owns the menu bar. The translation
is computed from live bounds after resolution changes, so a mode change cannot
leave displays overlapping.

### Automatic rules

The service observes `NSApplication.didChangeScreenParametersNotification`.
Online display identities are compared with the previous set after a short
settle delay; a newly seen identity is a connection and a vanished one is a
disconnection. The first preset whose rule matches is applied. The observer is
installed only while at least one rule exists, and it is removed when the
brightness feature is unavailable.

### Shortcuts

Each preset's shortcut is stored inside the preset. A small Carbon registrar
(one shared event handler, one id per preset) registers them while the
brightness feature is available. Recording a shortcut suspends them through the
existing `ShortcutCapture` path, and the feature binding registers them again
when recording ends.

### Settings backup and uninstall

`displayPresets` is a normal registered preference, so it is exported and
imported with the rest of the settings. Uninstalling the Displays feature is
refused to modify the stored presets: their data stays in place and comes back
if the feature is installed again, like every other feature's settings.

## Limits

- Only what is visible to the public display APIs is saved. HiDPI scaling
  presets need private calls and are out of scope.
- A DDC write that the monitor ignores is indistinguishable from one it
  accepted; the brightness and volume items report only whether a route
  existed.
- Two identical monitors with the same vendor, model and serial are matched by
  snapshot order, not by a unique hardware id.
- A preset never turns a display off. Doing so is available from the display
  row, but is not part of a snapshot.
- The main-display step assumes displays are not mirrored; mirrored displays
  keep their arrangement.
- Automatic rules apply to connections and disconnections seen while Tina is
  running, not to changes made while it was not.

## Verification

Run on an Apple M4 Mac with macOS 15.7.7 (24G720):

| Check | Result |
|---|---|
| `./build.sh --dev` | build succeeded, no new warnings |
| `./build/TinaDeveloper --selftest` | `SELFTEST OK` |
| `./build.sh --test` | `TESTS OK (124789 checks)`, including 54 display-preset checks |
| `./build.sh` | official build succeeded |
| `./build/Tina --selftest` | `SELFTEST OK` |

The automated checks cover the pure decisions: identity validation, storage
round trips and sanitization, mode matching, display and built-in matching,
automatic-rule selection and resolution comparison. They do not move a mode,
change a main display, write DDC or observe a real connection, and the
developer build was not driven through the Settings or panel UI on this host.
Those hardware paths still need a manual pass on a Mac with an external
display: save a preset, change the arrangement, apply it, and exercise an
automatic rule by replugging the display.
