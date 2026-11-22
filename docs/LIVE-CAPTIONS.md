# Live captions

Live captions turn the sound your Mac is playing into text on screen. It is
meant for meetings, classes, streams and local videos: anything you can hear,
without opening a second app or sending audio to a server.

The feature is part of the **Sound** group in the Features hub. Install it
there, then start listening from the menu panel, the Settings page or the
global shortcut.

## Start and stop

- **Menu panel → Live captions → Start listening.** The same switch stops a
  running session; the panel names the state and shows the line being spoken.
- **Global shortcut (⌃⌥S by default),** configurable in the caption settings
  and on the central Keyboard shortcuts page.
- The menu bar icon shows a small captions badge while the Mac is being
  listened to, even when the panel is closed.

Starting turns the feature's master switch on if it was off. The master switch
in Settings stops listening and releases the audio tap when you turn it off.

## What appears on screen

A floating caption bar appears near the bottom of the display under the
pointer. It:

- does not take focus from the app you are using;
- passes clicks through everywhere except the 22-point grab strip at its top,
  which you can drag to move it (the position is remembered per screen);
- fades after about six seconds without sound and returns with the next line;
- follows the size and line-count settings live;
- stays on every Space and over full-screen apps.

The bar shows the newest partial line while speech is recognized, then the
final line. Lines are also appended to the session transcript.

## Languages and macOS

Captions require **macOS 14.4 or later** on Apple Silicon, because the system
audio tap arrived in 14.4. The feature is hidden on 14.0–14.3.

Recognition uses Apple's **on-device** Speech recognition. The language picker
lists only locales that have an on-device model on this Mac, defaulting to the
system language. A language without an on-device model can be added in System
Settings; Tina does not fall back to a server.

On macOS 14 and 15 the system **Dictation** setting must be on. If recognition
is unavailable, Tina names the reason in the panel and Settings instead of
listening silently.

## Permissions

Two permissions are involved:

- **System Audio Recording** — the same grant the recorder and mixer use, so
  Tina can hear the mix of every app. Tina does not capture the screen.
- **Speech Recognition** — the per-app grant that lets Tina turn audio into
  text.

Both appear in the Features hub's permissions portal and in the caption
settings when missing. Declining either leaves the feature installed but
stopped, with the reason shown.

## Privacy

Recognition runs on this Mac. Audio is not recorded to disk, is not sent to a
server, and no account, API key or network request is involved. The session
transcript is written only to the local captions folder and is deleted when
you delete the session.

## Sessions and export

While listening, Tina builds a local session containing each finalized line
with its start and end time, the recognition language and the session start.

- Sessions are saved automatically in
  `~/Library/Application Support/Tina/Captions/` unless you turn auto-save off.
- **Settings → Live captions → Save folder** can point at another folder. The
  access is remembered with a security-scoped bookmark; the folder location is
  not included in settings backups because the bookmark belongs to one Mac.
- The menu panel lists recent sessions. Each row can export:
  - **SRT subtitles** (`.srt`), with `HH:MM:SS,mmm` cue timing;
  - **Markdown** (`.md`), with a timestamped bullet per line;
  - **plain text** (`.txt`), one line per caption.
- Exported files are named from the session start time, written beside the
  session, and revealed in Finder after export.
- **Copy all text** puts the whole transcript on the clipboard.
- **Delete session** removes its JSON file after confirmation. **Clear history**
  in Settings removes all session JSON files; exported files you created are
  left alone.
- A session that never produced a finalized line writes no file, and a failed
  recognition run never leaves an empty or half-written session.

The transcript is plain local data. There is no sharing link, cloud backup or
account.

## Limits

- **Screen recording conflicts.** Live captions and screen recording both read
  the system audio tap. They are mutually exclusive: starting a recording stops
  captions with an explanation, and starting captions while recording is
  refused. This avoids two taps fighting over one output.
- **Protected audio.** Audio that macOS itself withholds from taps (some DRM
  playback) cannot be captioned.
- **Network and mic audio** are not sources in this version; only the Mac's own
  output mix is heard.
- **No translation or meeting summary.** Bilingual captions are tracked
  separately in issue #39 and deliberately deferred. AI meeting notes are
  rejected in issue #41; export Markdown and use the AI tool of your choice.
- **Recognition quality** is the system model's. Punctuation and proper nouns
  vary by language and audio quality.
- **Battery.** Continuous recognition and an audio tap use power. Stop
  listening when the meeting or video ends.

## Troubleshooting

| Symptom | What to check |
|---|---|
| "Speech Recognition is turned off" | System Settings → Privacy & Security → Speech Recognition → enable Tina. |
| "On-device recognition is not available" | Pick another language, or add the language's Dictation/voice model in System Settings → Keyboard → Dictation. |
| "Could not read your Mac's sound" | System Settings → Privacy & Security → Screen & System Audio Recording → enable Tina, then try again. |
| No text but the bar says listening | Check that the app is actually playing audio, that the output is not muted, and that Dictation is on (macOS 14–15). |
| A recording refuses to start captions | Stop the screen recording first; the two cannot share the tap. |
| Export fails | Check that the chosen save folder still exists and is writable, then choose it again. |

## Related

- [#38 — live captions](https://github.com/zbl-jerry/tina/issues/38)
- [#40 — session save and export](https://github.com/zbl-jerry/tina/issues/40)
- [#39 — translated captions (deferred)](https://github.com/zbl-jerry/tina/issues/39)
- [#41 — AI meeting notes (rejected)](https://github.com/zbl-jerry/tina/issues/41)
