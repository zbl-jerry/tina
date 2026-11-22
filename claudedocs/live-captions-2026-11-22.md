# Live captions — research, product and system design (issues #38–#41)

Date: 2026-11-22. Branch: `feature/live-captions` (worktree
`.claude/worktrees/feature+live-captions`). Target: `dev`.

## Scope decision

| Issue | Decision | Delivered in this change |
|---|---|---|
| #38 Live captions from the Mac's own audio | MVP | Yes: feature, tap, on-device recognition, caption bar, permissions, menu panel, Settings, shortcut, menu bar badge |
| #39 Bilingual captions with on-device translation | Defer | No code. Design and reopen conditions recorded below |
| #40 Session save and export (SRT/Markdown/plain text) | Pursue | Yes: local session store, exports, copy, reveal, delete, history |
| #41 AI meeting notes | Reject | No code. Rationale recorded below; Markdown export is the escape hatch |

The four issues describe one product arc. #40 is the natural second half of
#38, so they ship together; #39 depends on #38 and its own issue says to
reassess after captions land; #41 is explicitly rejected and implementing it
would contradict the repository's no-account, no-hosted-service position.

## Requirement research

Evidence used:

- The issue bodies in `zbl-jerry/tina` (#38, #39, #40, #41), which already
  contain the `tina-feature-research` output: JTBD, hard constraints, upstream
  product signals (BeMyEars, Cicada), costs and risks.
- The existing implementation surface in this repository: the recorder's
  system-audio tap, the feature catalog and hub, the permissions portal, the
  floating-panel patterns, the settings backup and the test harness.
- No new network research was needed; the product claims in the issues were
  already sourced and dated.

Key findings that shaped the design:

1. **The tap already exists.** `RecorderSystemAudioTap` reads the whole Mac's
   mix through a Core Audio process tap, excluding Tina itself, and already
   handles output-device changes and sample-rate changes. Reusing it avoids a
   second audio stack and keeps the new code to capture hand-off, recognition
   and presentation.
2. **Speech is the only new system permission.** The repository already asks
   for System Audio Recording for the recorder and mixer. Speech Recognition is
   a separate per-app TCC grant with an Info.plist usage description.
3. **The recognition request has a lifetime.** `SFSpeechAudioBufferRecognitionRequest`
   is designed around bounded requests. A captions session can run for an hour,
   so the pipeline rotates requests before the engine's own limit and commits
   the partial line first.
4. **The caption bar and the app's normal panels have opposite input rules.**
   A caption must not take focus or swallow clicks; a position control must
   accept a drag. That is a small but real windowing problem, solved with a
   click-through panel plus a pointer-over grab-strip interaction.
5. **Privacy is a product requirement, not a setting.** The issue forbids cloud
   recognition, accounts and API keys. The design therefore refuses a locale
   without an on-device model instead of silently falling back.

## Product design

### Personas and jobs

- A Deaf or hard-of-hearing user watching a meeting, class or stream needs the
  Mac's output as text without installing a second menu bar app.
- A non-native speaker needs a readable line for content that has no captions.
- Anyone in a noisy room needs the same text to follow along.

### User journey

1. Install **Live captions** from Features hub → Sound. The first install turns
   the master switch on but does not listen.
2. Start from the menu panel, Settings, or ⌃⌥S. The first run asks for Speech
   Recognition if needed; the system audio grant is requested by the tap.
3. A caption bar appears on the pointer's display. Speech appears as partial
   text and settles into final lines.
4. Silence fades the bar; new speech brings it back. The menu bar carries a
   captions badge while listening.
5. Stop from the same control. The session is saved locally and appears in
   Recent sessions.
6. Export SRT/Markdown/plain text, copy all text, reveal the export, delete a
   session, or clear history.

### MVP boundaries

In: system output mix only, on-device recognition, one caption bar, start/stop,
language choice among on-device locales, local sessions, three exports, copy,
delete, global shortcut, menu bar badge, permission explanations.

Out: microphone/room capture, per-app audio selection, translation, speaker
diarisation, meeting summaries, virtual microphone, cloud services, audio
export, transcript search/replay, Word/PDF export, folder auto-sync.

## System design

### Components

```
CaptionService (main thread, ObservableObject)
├─ RecorderSystemAudioTap (audio thread → copied AVAudioPCMBuffer)
├─ CaptionRecognizer (serial queue, SFSpeechRecognizer)
├─ CaptionOverlayController (borderless panel + SwiftUI bar)
├─ CaptionSessionStore (Application Support or chosen folder)
└─ Carbon hotkey + menu bar badge + protocol observation
```

Files:

- `Sources/Tina/Core/CaptionStrings.swift` — all localized copy.
- `Sources/Tina/Services/Captions/CaptionSupport.swift` — pure model, timeline,
  dedupe, SRT/Markdown/text export, session store.
- `Sources/Tina/Services/Captions/CaptionRecognizer.swift` — PCM copy, Speech
  requests, rotation and failure classification.
- `Sources/Tina/Services/Captions/CaptionService.swift` — lifecycle, state,
  sessions, permissions, shortcut, folder access.
- `Sources/Tina/Services/Captions/CaptionOverlayController.swift` — panel,
  interaction and placement.
- `Sources/Tina/UI/MenuPanel/CaptionSection.swift` — panel surface.
- `Sources/Tina/UI/Settings/CaptionSettingsCard.swift` — settings surface.

### Audio path

`RecorderSystemAudioTap.make(hearing: nil)` builds a private tap over every
process except Tina. Its `onSample` runs on the audio system's thread; the
service copies the interleaved float PCM into an `AVAudioPCMBuffer` before the
callback returns (the tap reuses its memory), then hands the buffer to the
recognizer's serial queue. The tap also applies the recorder's level
compensation so quiet outputs remain usable.

The recording and caption features both need the same tap. They are explicitly
mutually exclusive: `CaptionService.start()` refuses while
`ScreenRecorderService.isRecording`, and a subscription stops captions if a
recording starts. This is the issue's allowed alternative to a shared tap and
avoids two consumers racing over the same output.

### Recognition path

- `requiresOnDeviceRecognition = true`; a locale whose recognizer does not
  report `supportsOnDeviceRecognition` is refused before audio starts.
- One request runs for at most 50 seconds. On rotation the partial line is
  committed as a final segment, the request is closed, and a fresh request
  starts on the same session clock.
- Finals use `SFTranscriptionSegment` timestamps, rebased onto the session's
  elapsed time. A result without timing becomes one fallback line.
- Duplicate finals and a partial followed by a fuller final are merged by a
  punctuation- and case-insensitive key, so a rotation does not print a line
  twice.
- Benign engine errors (no speech, retry, cancellation) restart the request;
  authorization/unavailability errors stop with an explanation. Three
  consecutive unknown failures stop rather than loop.
- Silence is measured from the tap's own peak probe (an atomic host-time stamp)
  to avoid touching UI state from the audio thread.

### Presentation

The caption panel is a borderless `.nonactivatingPanel` at `.floating`, joining
every Space and appearing over full-screen apps. It never becomes key.

`ignoresMouseEvents` is true except while the pointer rests on the 22-point
strip at the top, checked by a 150 ms timer that runs only while the bar is
visible. That gives real click-through for the body and a draggable handle for
position. The body's `hitTest` also returns nil outside the strip as a second
guard. Position is stored as normalized screen fractions per display and
restored on the pointer's current display. Font size and line count are read
from defaults, and a defaults observer resizes the panel when they change.

The SwiftUI bar draws a rounded translucent surface, the drag capsule, and
either the listening state or the newest line. It uses the feature's localized
copy and supports accessibility labels.

### Sessions

`CaptionSession` is JSON: id, start/end, locale and timed segments. The store
writes to `~/Library/Application Support/Tina/Captions/` by default, or to a
user-chosen folder accessed through a security-scoped bookmark. A session with
no finalized line is never written. Incremental saves rewrite the same file
every five finalized lines to survive a crash. Export filenames use the session
start time plus a short id, so two sessions started in one second cannot
overwrite each other. SRT uses comma milliseconds; Markdown uses timestamped
bullets; plain text is one line per cue.

### Permissions, settings and backup

- New `AppPermission.speechRecognition` in the hub portal, with status read
  from `SFSpeechRecognizer.authorizationStatus()` and request/open-settings
  actions. The feature declares `.audioCapture` and `.speechRecognition`.
- New Info.plist key `NSSpeechRecognitionUsageDescription`.
- New defaults: master switch, shortcut switch and value, language, font size,
  line count, auto-save, overlay position, panel visibility. All are registered
  defaults and travel in settings backups.
- The chosen folder path and bookmark are deliberately excluded from backups:
  a security-scoped bookmark is machine-local and would be stale elsewhere.
- The feature is opt-in (`installedByDefault == false`), in the Sound group,
  with a `.captions` settings anchor and a `.captions` menu-panel section.
- The default shortcut is ⌃⌥S. ⌃⌥C was rejected because Window Layout's centre
  action already owns it; a duplicate default would make one feature dead.

## Issue #39 — translated captions (deferred)

Why defer:

- #38 had to exist first; the issue itself says to reassess after captions
  land.
- The issue's own analysis gates the work on macOS 15+ and Apple's Translation
  framework, while Tina supports macOS 14.
- Translation adds language-pack download UX, failure/partial states and
  latency on top of recognition. It is a coherent next step, not a silent
  extra in this PR.

Reopen conditions: #38 is stable in a release; the team accepts a macOS 15+
sub-feature; a design exists for downloading and reporting language packs
without blocking the original captions. The implementation seam is
`CaptionSession`/`CaptionSegment`: a translation provider can add a translated
string per segment and the bar can render one or two lines, with the original
kept on failure. No online translation API is permitted.

## Issue #41 — AI meeting notes (rejected)

Why reject:

- It requires a model service, key management, prompt maintenance and failure
  handling, and the issue's own hard-constraint table fails complexity and
  fit.
- Sending meeting content off-device contradicts the no-account, no-hosted-
  backend promise.
- The value is already reachable: export Markdown/plain text and hand it to the
  user's own AI tool. That path is shipped in #40.

If the decision is ever revisited, the minimum shape is opt-in, local-only
output, a user-supplied endpoint with the key in Keychain, text-only input, and
no hosted service or subscription. That is a separate product decision, not a
follow-up commit here.

## Verification

Commands run in the worktree:

```sh
./build.sh --dev
./build.sh --test --test-suite=captions
./build.sh --test
```

Results at the time of writing:

- Developer build: succeeds, bundle signed.
- Captions suite: `TESTS OK (620 checks)`.
- Full suite: all suites pass after the catalog/localization contract updates
  (feature count 88, permission list, typography, shortcut conflict).
- `Tests/CaptionTests.swift` covers timeline math, SRT/Markdown/text output,
  repeated-line merging, session round-trip, corrupt-file tolerance, export
  names, delete/clear behavior, catalog/permissions, every localized field and
  the backup key set.

Not verified here: real speech recognition and system-audio capture need an
interactive audio session and TCC grants, which a headless test run cannot
provide. The local build's `--selftest` is run separately; the manual checks
below remain for the reviewer.

Manual review checklist:

1. Install the feature from Features hub → Sound; confirm the panel section and
   Settings page appear, and the permissions portal lists Speech Recognition.
2. Grant permissions; play speech audio; confirm partial and final lines, the
   listening badge, and the six-second fade.
3. Drag the bar by its top strip; confirm clicks on the body pass through and
   the position returns on the next start.
4. Stop; export SRT, Markdown and plain text; confirm Finder reveals each file
   and the SRT plays in a video player.
5. Start captions, then start a screen recording; confirm captions stop with
   the conflict message.

## Risks and follow-ups

- **Recognition rotation still loses the tail** of a request if the engine
  never reports the partial; the design commits what it has before rotating.
- **Protected audio** (DRM) is unavailable to taps by design; the documentation
  says so rather than promising it.
- **Power use** is inherent to continuous recognition; the feature is explicit
  start/stop and fades only presentation, not the tap.
- **Speech locale enumeration** is deferred until Settings/Start, so an
  installed-but-unused feature does not initialize Speech at launch.
- **Shared tap vs. mutual exclusion** may be revisited if users routinely want
  captions over a recording; that needs one owner for the tap and a recorded
  output that includes caption timing.
