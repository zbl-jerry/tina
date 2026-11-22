# Changelog

All notable changes to Tina are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

The build copies this file into the app bundle. The post-update "What's New"
window reads the entries between the version a person updated from and the
version they are running, so every release needs a dated `## [version]` section
here before the version in `Resources/Info.plist` is bumped.

## [3.7.1] - 2026-11-22

### Added
- Dynamic Island AI Agents count Cursor token usage from a dated response with usage counts in a local transcript. Cursor plan credits are still not read from the network.

### Fixed
- Cleaner keeps preferences, support files and caches it can match to audio plugins installed in the standard plugin folders, and checks again before moving a selected item to the Trash.

## [3.7.0] - 2026-11-22

### Added
- Window pinning: keep any window visible above other apps as a live, resizable mirror. Pinned windows follow their source, pause while minimized, on another Space or fully covered, and hand control back to the real window on click or hover. The feature is installed from the Hub, uses Screen Recording and Accessibility, and its settings join Settings backup.
- Live captions: turn the sound your Mac is playing into on-screen captions with on-device Speech recognition, a draggable click-through caption bar, a menu bar indicator and a global shortcut. Sessions are saved locally and can be exported as SRT, Markdown or plain text, copied, or removed, and captions stop cleanly when a screen recording starts because the two cannot share the system audio tap.
- Quick toggles can restart the Dock, the Finder, the menu bar or the third-party input method in use. Each row confirms first, explains what disappears for a moment, and reports whether the component came back. The input method row stays disabled with a reason when no third-party input method is running, and every action follows the Kill Process protection rules with no new permission or helper.
- Dynamic Island AI Agents now follow Cursor's live turns, project names and completion notices by reading its local agent transcripts, with no network requests and no plan credits read.

### Changed
- Tina no longer builds services for features that are turned off when it launches, so startup does less work without changing what is available. Display recovery for screens a previous run left off still runs before the rest of launch.
- Window gestures and edge snapping share one pointer tap, so a drag that needs both keeps an in-progress gesture and cancels a pending snap correctly when the drag is handed to macOS.
- Microphone mute can follow an unmute made from a call app when the opt-in option in Settings → Quick panel is turned on. Mute enforcement stays the default.

### Fixed
- Update checks ask the repository the app is built from, so they no longer fail against a renamed repository. A response GitHub rejects now reports its HTTP status instead of a placeholder.
- The post-update What's New window reads the changelog bundled with the app again, so it lists the changes made in every version between the previous install and the current one.
- Screen recording keeps the camera bubble in the editor preview and in every video, GIF and shared export by drawing it after the automatic zoom instead of baking it into the recording.
- The live key row stays inside the recorded window or area, the key switch asks for Input Monitoring when it is turned on, and a missing grant is reported when recording starts instead of silently omitting the keys.
- The screen-capture chooser offers full-screen recording, and a shortcut's recorder row is hidden while that shortcut is turned off.
- Fan control keeps a verified curve through a GPU power-down, retries a refused fan write while every fan still holds its target, and returns all fans to system control when a safe configuration cannot be verified. The panel reports a curve it could not restore.
- Clipboard history prefers the text in a copy that also carries rich text, so copied spreadsheet cells keep their text and separators instead of becoming a preview image. Image and file copies are unchanged.
- Low disk space alerts repeat at most once every six hours per volume, with one earlier alert when free space drops below half the limit.
- Super Key waits for a keyboard after login or wake instead of treating the missing mapping as refused, and captures F18 only once the mapping is written and read back.
- The window switcher hands ⌘Tab back to macOS while an exclusive full-screen game covers the display, and resumes suppression when the game leaves full screen.

## [3.6.0] - 2026-11-21

### Added
- Auto input source: assign an input method per app, with separate choices for the first activation after launch and later returns. Rules can be exported and imported as JSON, and a "never switch" list takes precedence over every rule.
- Battery charge limit: Apple Silicon MacBooks can stop charging at a chosen level between 60% and 100%, resume 5 points below it and charge to full once on demand. Turning the feature off, quitting or a helper crash restores normal charging.
- Per-app scrolling: choose follow-global, off, or a custom step and speed for each app, invert scrolling for one app only, and return to the raw wheel while a chosen key is held.
- Verification codes: standard TOTP codes in the menu bar panel and Quick panel, copied with one click, masked until the pointer rests on them and stored in the Keychain only.
- Window tiling: arrange every normal window on the current display as a balanced grid, by rows or by columns. Repeating the same action cycles to the next layout, and each row or column can hold 1–6 windows.
- Displays presets: save resolution, brightness, display volume and mute, and the main display, then restore them from the panel, a shortcut, or automatically when a display connects or disconnects, with a report of anything that could not be restored.
- Keystroke overlay for screen recording: show the keys being pressed in a corner or beside the pointer, with three sizes, a dwell time and light or dark appearance, included in the editor preview and in video and GIF exports.
- Camera bubble for screen recording: composite the camera into the recording as a round or rounded bubble with mirroring and a shadow, switch cameras during the recording, and skip a second app afterwards.

## [3.5.0] - 2026-11-21

### Added
- Hosts profiles: keep several hosts configurations in Utilities, enable only the combinations you need and apply them at once. Only Tina's marked block in `/etc/hosts` is replaced, each write is backed up and the last ten are kept, and lines are validated before an admin prompt applies them.

## [3.4.5] - 2026-11-21

### Added
- Night warmth: overlay a schedule-driven colour temperature on every display, warmer at sunset and warmer still before bed, with pause by the hour or until sunrise, presets and warmer/cooler nudges. The original gamma tables are restored when the feature is turned off, when Tina quits or after a crash.

### Changed
- Tina is an independent project: the license is MIT throughout and no fork or upstream references remain.
- Documentation now explains how night warmth works and its limits, and records the repository rules for coding agents.
