# Automatic input source

Automatic input source gives each app the keyboard input source you want when it
launches and whenever you return to it. It replaces remembering to press
⌃Space after every app switch, and the system-wide "automatically switch to an
input source for a document" setting that only remembers one source per app.

## What it does

- **Two moments per app.** The first activation after an app launches can
  differ from every activation after it. A rule is keyed by the app's bundle
  identifier.
- **Four answers.** A rule can follow the global default, use a fixed input
  source, remember the source that app last used, or not switch at all.
- **Global default.** Answers for apps with no rule, with its own launch and
  return behaviors.
- **Never switch.** Apps on this list keep whatever source is active. The list
  wins over a rule and over the global default.
- **Manual switching.** The menu panel shows the current source and lists the
  enabled ones; one click switches now.
- **Rules file.** Export and import the global default, exclusions and rules as
  JSON, so the same file can live in a dotfiles repository.

## How it works

Tina watches which app becomes active and then asks the Text Input Sources
services to select a source. It never installs a keyboard event tap, so it
cannot delay or swallow a keystroke. Because of that, no permission is needed:
watching app activation and selecting an input source are both allowed without
Accessibility.

The order for every activation is:

1. The app is on the Never switch list.
2. The app has a rule; its launch or return behavior applies.
3. The rule follows the global default; the same timing of the global default
   applies.
4. Otherwise the global default for this timing applies.
5. If the chosen source is already active or no longer enabled, nothing
   happens.

"First activation" means the first time Tina sees the app come to the front
since that app process launched. Apps that were already running when Tina
started count as returning apps, so their return behavior applies. The memory
of what has been activated lasts for one Tina session and is never written to
disk.

Switching is skipped while a password field holds secure input. It resumes on
the next activation after secure input ends.

Super Key, Command Bar and the panel's manual buttons switch sources on a
gesture. Automatic switching only acts after an app becomes active, so a manual
choice made afterwards is the last word.

## Rules file

Export writes a file like this:

```json
{
  "format": "tina.auto-input-source",
  "version": 1,
  "global": {
    "firstActivation": { "kind": "noSwitch" },
    "reactivation": { "kind": "fixed", "sourceID": "com.apple.keylayout.US" }
  },
  "excludedBundleIDs": ["com.apple.Terminal"],
  "rules": [
    {
      "bundleID": "com.example.Editor",
      "appName": "Editor",
      "timings": {
        "firstActivation": { "kind": "fixed", "sourceID": "com.apple.keylayout.US" },
        "reactivation": { "kind": "rememberLast" }
      }
    }
  ]
}
```

A hand-written file may leave out `format`; a different value is refused. A
`version` newer than the app refuses rather than half-reads. Bundle identifiers
are limited to letters, digits, dots, hyphens and underscores, duplicate apps
and exclusions are dropped, and the global default cannot follow itself.

Importing replaces the global default, exclusions and rules. The source each
app last used stays on the Mac, because it is habit rather than configuration.

## Limitations

- Only app-level rules. Browser domain rules and terminal program rules are not
  part of this version.
- "Remember last source" records the source that was in effect while the app
  was in front, whether the user or a rule chose it.
- Switching happens on every activation, with no debounce. Very fast ⌘Tab
  cycling can make the source change several times in a row.
- Nothing switches while secure input is on, so a password prompt delays the
  rule until the next activation.
- No caret indicator, statistics or per-input-source global shortcuts.
- A rule for an app that is no longer installed stays in the list and is
  marked, so reinstalling the app restores its behavior.

## Testing notes

The pure half lives in
`Sources/Tina/Services/AutoInputSource/AutoInputSourceSupport.swift`: the rules
model, precedence, stored formats, sanitizing and the rules file. The service
in the same folder adds the activation observer, source selection and last-used
recording.

`Tests/AutoInputSourceTests.swift` pins the decision order, exclusions, fixed
and remembered sources, missing or disabled sources, import failures, storage
round-trips, the defaults and backup boundaries, and the complete set of
localized strings.

Run `./build.sh --dev` and `./build.sh --test` before changing either half.
The build and the test suite were run for this version; the activation timing
with real apps, the visual result in Settings and the menu panel, and the
interaction with hardware input sources still need a manual check on a Mac.
