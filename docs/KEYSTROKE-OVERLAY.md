# Key overlay for screen recordings

Tina can show the keys you press while it records the screen. This document
records the research behind issue #10, the product decisions, the system
design, the privacy boundaries and what was verified.

## Why

Tutorials, code reviews and remote demos show the result of a shortcut but not
the shortcut itself. A viewer sees a menu open after `⌘⇧4`, not the keys that
opened it. Tina already draws the pointer path and click rings, and the typing
sampler records *when* someone typed, but nothing records *what* was pressed.

The upstream project investigated for issue #10, [KeyCastr](https://github.com/keycastr/keycastr)
at v0.11.1, solves this as a menu bar app. The research compared three roads:

1. **Record key content with the recording and draw it in the editor.** Reuses
   Tina's pointer/typing sidecars and the composer that draws every other
   overlay; works for area, window and display recordings; gives the editor the
   same picture as the export.
2. **Show a floating window and let the capture see it.** Simpler, but window
   recordings would miss it, it would double up wherever the composer also
   draws, and the row would be locked into the master pixels.
3. **Record only timings and invent a keyboard animation.** No permission, but
   it would show keys that were never pressed. Rejected: the feature exists to
   be truthful about what was pressed.

The research conclusion was **MVP** on the first road. The cost is one optional
permission and a new sidecar; the benefit is a recorder that can say how a
result was produced.

## What it does (MVP)

- A **Show keys while recording** switch in the screen recorder settings,
  **off by default**.
- When on, an overlay shows the pressed combination as key caps, such as
  `⌃⌥⇧⌘4`, `⇥`, `↩` or `←`.
- Four corner positions, or **Follow pointer**.
- Three sizes, a dwell of 1, 2 or 4 seconds, and a dark or light appearance.
- The row is shown live while recording, hidden while paused, and drawn into
  the editor preview and every video or GIF export.
- The row is cleared immediately when macOS turns on **Secure Event Input**
  (the state a password field requests), and nothing is captured while it is
  on.
- Settings explain that **Input Monitoring** is required. Without it the
  switch stays off and offers a request button and a shortcut to System
  Settings.

Deliberately not in this version:

- An always-on key display outside recordings.
- A key history panel or per-app filtering.
- Mouse movement or click visualization changes (Tina already has a pointer
  track and click rings).
- Keystroke statistics, exported logs or a searchable history.
- Showing a key on modifier-only changes (`flagsChanged`). A combination
  always includes the key that was pressed.

## Product design

### Where the switch lives

The switch sits with the other recorder choices, below automatic zoom. The
permission explanation and request row appear there whenever the grant is
missing, so the state that disables the switch is always visible next to it.
The appearance controls appear only once the switch is on and the permission
is granted; there is no reason to configure a row that cannot be recorded.

### What the row says

- Modifiers print in the order macOS itself uses: `⌃⌥⇧⌘`.
- The key name is translated from the active keyboard layout with no
  modifiers, so `⇧⌘4` reads as `4` rather than `$`, and Option combinations
  keep the unmodified letter.
- Named keys use the system symbols: `↩`, `⇥`, `⌫`, `⌦`, `⎋`, `←↑→↓`, `⇞`, `⇟`,
  `⌤` for the keypad Enter, and `F1`…`F20`.
- A new press replaces the row instead of queueing behind older ones. A burst
  of typing therefore reads as the newest combination, not a backlog.
- The row fades in and out at the ends of its dwell so it never appears or
  disappears on a single frame.

### Placement

Corners use the same margin and coordinate space as caption anchors, so a key
row in the bottom-right stays in the bottom-right whatever the aspect ratio,
backdrop or export size. **Follow pointer** tracks the pointer through the
same zoom and card fit the composer applies to the picture; if a recording has
no pointer track, it falls back to the bottom-right corner rather than
following a point that was never recorded.

The **live** row is placed against the recorded area, not the display: a
window or area recording shows its row inside that window or area, at a size
relative to the recording's height, so what is seen while recording matches
what the composer draws. The exported corners still use the finished canvas,
which is the recorded card plus any backdrop.

### Pause and secure input

Pausing hides the row at once. Presses during a pause are not recorded, so
resuming does not replay what happened while paused.

Secure Event Input is the password-field state. macOS withholds key events from
every event tap while it is on, which is the primary guarantee. The sampler
also polls the flag every 350 ms and checks it on every event, so the row is
cleared as soon as it turns on, not at the next press that never arrives. When
the flag turns off, recording key display continues without a restart.

## System design

### Capture

`RecorderKeystrokeSampler` is created only for a recording that has the switch
on and the permission granted.

- It installs a **listen-only** `CGEvent` tap for `keyDown` at the HID head.
  A listen-only tap cannot swallow, modify or replay an event.
- It ignores autorepeats, modifier-only presses and Caps Lock.
- Event times go through the same `RecorderPauseClock` as the pointer and
  typing tracks, so the row lands on the recording's own clock, not wall time.
- The tap's run loop source is installed and removed on the main thread, where
  AppKit and the live panel already live.
- If macOS refuses the tap, the recording continues and a HUD explains that
  the keys cannot be shown. Losing the overlay never costs the recording.

### Storage

The only place key content is written is a private sidecar beside the master:

```
<private take folder>/keystrokes.json
```

The file holds the display tokens (`["⌘", "⇧", "4"]`), their times, and the
style that was in use. It is written `0600` inside the recorder's existing
`0700` take folder, created only when at least one press was recorded, and
deleted with the take. It never enters:

- any log or crash report,
- the video or GIF metadata,
- the edit document (`edit.json`),
- the settings backup, or
- settings defaults.

The take store already deletes its folder when the editor closes or the file
is saved, and sweeps orphaned folders from a crash; the sidecar follows that
lifecycle with no separate cleanup path.

### Live row and burned-in row

The live row is a non-activating, mouse-transparent panel excluded from Tina's
capture by window number, exactly like the recording pill. The capture starts
after the panel exists, so the exclusion covers the first frame.

The file gets the row from `RecorderComposer`, not from the screen:

- `RecorderComposerPlan` resolves, for every output frame, which combination
  is on screen, its opacity, and its origin. It uses the pointer track and the
  same zoom and card-fit math as the picture for **Follow pointer**.
- `RecorderKeystrokeRenderer` rasterizes each distinct row once at the canvas
  size, with the same layout and palette as the live panel
  (`RecorderKeystrokeDrawing`), and the composer composites that texture.
- The editor preview and the exporter use the same plan, so what is watched
  while editing is the picture that lands in the file.

Because the row is part of the edit, it follows Tina's existing overlay
semantics: it appears in the editor and in every export from it. A recording
saved straight to a file with **Open the editor after recording** off remains
the untouched master, like the pointer path, captions, images and blurs today.

### Permission

Input Monitoring is checked with `CGPreflightListenEventAccess()` and requested
with `CGRequestListenEventAccess()`. Turning the switch on asks for the grant
immediately, the same way the camera and microphone switches do. The recorder
asks the system directly at the moment a recording starts rather than trusting
a cached status, so a grant made while Tina was running is picked up. If the
grant is still missing then, the recording continues and a HUD says why the
keys are absent instead of silently recording without them. A refused event
tap produces the same notice and a log entry.

## Privacy and security

- Opt-in and off by default.
- Only while a recording runs, only while listening is granted, and never
  while Secure Event Input is on.
- Display tokens only: no raw event stream, no typed text, no application
  identity, no window title and no modifiers that are not part of the shown
  combination.
- Key content never leaves the private take folder and is never logged or
  embedded in file metadata.
- Listen-only tap: the feature cannot affect what other apps receive.
- The live panel ignores the mouse and is excluded from the capture, so it
  cannot intercept clicks or appear twice.

## Verification

- `./build.sh --dev` — compiles the app bundle.
- `./build.sh --test` — 125,243 checks pass, including
  `RecorderKeystrokeTests` for defaults, backup inclusion, normalization,
  active-press lookup, key naming, the rasterizer and the composer plan, the
  live row being placed inside the recorded area, and the recorder harness
  checks that the key tap is installed and removed on the main thread.
- Manual review, in the main session only (subagents must not drive windows or
  `screencapture`):
  1. Grant Input Monitoring, turn the switch on, record a few shortcuts and a
     text entry.
  2. Confirm the live row shows `⌘⇧4`-style combinations inside the recorded
     window or area, hides on pause and returns on resume.
  3. Click into a password field while recording; confirm the row clears at
     once and no keys from that period appear in the editor.
  4. Export a video and a GIF; confirm the row is burned in at the chosen
     position, size, dwell and theme.
  5. Revoke Input Monitoring; confirm the switch stays usable, the settings
     page shows the permission row, and starting a recording says the keys
     cannot be shown instead of silently omitting them.
