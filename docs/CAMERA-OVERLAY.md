# Camera overlay while recording

Tina can put a small camera bubble in the corner of a screen recording, so a
tutorial, a demo or a bug report shows the person explaining it as well as the
screen. This document records the research, the product decisions, the system
design and what was verified. It implements
[issue #9](https://github.com/zbl-jerry/tina/issues/9).

## Why

Recording a walkthrough and appearing in it used to take a second tool: record
the screen, record the camera, then composite the two in an editor. macOS 14's
Presenter Overlay only works inside a video call, and the screen-recording apps
that offer the same thing are either paid or a second app to install and keep
out of the recording.

The upstream research for issue #9 looked at
[QuickRecorder](https://github.com/lihaoyun6/QuickRecorder) 1.6.9 (AGPL-3.0),
which lists a presenter overlay as a first-class feature. Tina already owns
every piece of the pipeline the feature needs: screen and window capture, a
camera session for the preview mirror, and a writer that closes one master
file. The missing part is a camera frame drawn into the recorded picture.

The issue's research concluded **MVP**: only the camera bubble, not iOS
device recording, green screen, a separate camera track or moving the bubble
afterwards.

## What it does (MVP)

- A **Camera bubble** switch in **Settings → Utilities → Screen recording**,
  off by default. Turning it on asks for camera access once.
- A camera picker, a **Circle / Rounded** shape choice, **Mirror image** (on by
  default, the way a mirror and every video call show you) and **Shadow** (on
  by default).
- While recording, a live camera bubble floats inside the recorded area. Drag
  it to move it; scroll over it to resize it. Its position and size are kept
  for the next recording.
- The bubble is composited into the recorded frames themselves: the saved
  video, the editor preview, GIF exports and temporary links all show it. It
  cannot be removed after recording. This is the MVP trade-off the issue asked
  for.
- If camera access is denied, no camera is connected or another app holds the
  camera, the screen is recorded as before and a notice says the bubble was
  left out. Recording never fails because of the camera.
- The bubble is one of Tina's own panels and is excluded from the capture, so
  it never appears twice (once floating and once baked in).

Deliberately not in this version:

- Recording an iPhone or iPad as the camera.
- A separate, editable camera track, or removing/moving the bubble after the
  recording has ended.
- Green screen, background replacement, filters or camera audio as its own
  track (the microphone setting still decides whether your voice is recorded).
- Drawing the bubble on screenshots, or in any capture other than screen
  recording.

## How it works

### Capture graph

```text
SCStream (screen) ─────────────┐
                              ├─▶ RecorderSession video path ─▶ RecorderWriter ─▶ take.mov
AVCaptureVideoDataOutput ─────┘        (composite, same PTS)         (encode)
        ▲
        └── AVCaptureVideoPreviewLayer ─▶ floating bubble (excluded from SCStream)

pointer / typing samplers ─────▶ sidecar files (unchanged)
```

`RecorderCameraCapture` owns one `AVCaptureSession` with a
`AVCaptureVideoDataOutput`. The same session feeds the bubble's preview layer,
so the camera is opened once. Video settings are BGRA at the session's `.high`
preset, which is more than enough for a bubble that is at most half of the
recording's shorter side.

The capture engine still writes the screen untouched. Compositing happens on
the writer's serial queue, just before the encoder: the newest camera frame is
drawn over the screen pixel buffer, the sample's timing is preserved, and the
result goes to `AVAssetWriterInput`. Nothing else in the recorder, editor,
exporter, GIF writer or sharing path changes, because they all read the same
master file.

### Geometry

`RecorderCameraLayout` is the one value shared by the bubble, the settings and
the compositor:

- `centerX` / `centerY` — the bubble's centre as a fraction of the recorded
  picture, with a top-left origin (the direction the screen uses).
- `size` — the bubble's side as a fraction of the picture's **shorter** side
  (8% to 50%), so a circle is a circle whatever the recording's aspect is.
- `shape`, `mirrored`, `showsShadow`.

The floating bubble is positioned from the region's `anchorRect` in Cocoa
points; the compositor uses the same normalized centre in recording pixels.
Dragging clamps the bubble inside the recorded area so a bubble can never be
half outside the video. The geometry is unit-tested independently of any
camera.

### Rendering

`RecorderCameraCompositor` uses one `CIContext`. Per frame it:

1. aspect-fills the camera image into a square (cropping the overflow),
2. flips it horizontally when Mirror is on,
3. masks it with a circle or a rounded square,
4. draws a blurred, slightly offset shadow underneath when Shadow is on,
5. composites the result over the screen frame and renders into a pooled,
   IOSurface-backed BGRA buffer.

Masks and shadows are generated once per size/shape and cached, so a steady
recording does no path work per frame. The camera image is already on the GPU
as a `CVPixelBuffer`; the only per-frame CPU work is creating the output buffer
and the sample-buffer wrapper.

### Timing, pause and stop

The composited sample keeps the screen sample's presentation timestamp and
duration, so the writer's pause clock, retiming and audio alignment behave
exactly as before. While a recording is paused the writer drops video anyway,
so the session skips compositing until it resumes; the bubble in the finished
video freezes with the screen, and the floating mirror keeps showing the live
camera. On stop the writer writes the last video sample once more at the stop
time; that sample is the composited one, so the bubble stays in the final held
frame.

### Permissions and failure

- Camera access is requested when the switch is turned on, and again at record
  time if it becomes `notDetermined`. The status comes from
  `Permissions.shared.camera`, the same source the camera mirror uses.
- Denied or restricted: no camera is opened; the HUD says the bubble was left
  out.
- No camera, camera in use, or the session is interrupted while recording:
  the frame store empties, compositing stops, the bubble hides and the HUD
  says the bubble was left out. The recording continues and remains valid.
- Camera is not added to the screen recorder's required permissions in the
  feature catalog: it is optional and must never block recording.

### Performance

The extra work is one camera pipeline (720p, late frames dropped) and one Core
Image composite per delivered screen frame. The screen stream is variable-rate,
so a still screen costs nothing; compositing is skipped while the recording is
paused or the encoder is behind. The composite is GPU work with cached masks
and shadows.

**Not benchmarked:** this change ships without measured frame-rate or CPU
figures. The design keeps the per-frame work bounded, but a 4K/60 recording
with the bubble on still needs manual performance verification.

## Limits

- The bubble is fixed once the recording ends. Removing it means recording
  again.
- The floating panel is anchored to where the region was picked. Recording a
  window and then moving that window during the recording keeps the baked
  bubble in its corner of the video, but the floating panel stays where the
  window was: it is a placement control, not a live follower.
- There is one bubble, one camera and one shape; no separate camera track, no
  camera-only audio and no green screen.
- An interrupted camera (unplugged, taken by another app) hides the panel and
  stops the bubble from that point on; the frames already written keep it.
- Camera access is optional and never blocks recording.

## Settings and backup

The new preferences are ordinary registered defaults, so they travel with
Settings backup:

| Key | Default |
|---|---|
| `recorderCameraOverlay` | `false` |
| `recorderCameraDevice` | `""` (first camera) |
| `recorderCameraCenterX` | `0.86` |
| `recorderCameraCenterY` | `0.82` |
| `recorderCameraSize` | `0.22` |
| `recorderCameraShape` | `circle` |
| `recorderCameraMirror` | `true` |
| `recorderCameraShadow` | `true` |

The camera device's unique ID is a per-machine detail but is harmless in a
backup: an unknown ID falls back to the first available camera.

## Verification

Verified by the implementing session on 2026-11-21:

- `./build.sh --test` — the full suite passes, including the new
  `RecorderCameraOverlayTests`: layout geometry (clamping, aspect, drag/resize
  normalization, corner radius), registered defaults, settings-backup keys and
  the preference round-trip. The suite also drives the real compositor with
  synthetic screen and camera buffers and checks the pixels: the screen
  outside the bubble is untouched, the camera lands in the square, a circle
  leaves its corner showing the screen while a rounded square does not,
  mirroring swaps the camera's halves, and the rebuilt sample buffer keeps its
  presentation time and duration. The `recorder` group alone also passes.
- `./build.sh --dev` — the developer app builds.
- `./build/TinaDeveloper --selftest` — `SELFTEST OK`.

Not verified:

- **Camera capture and the floating panel.** `AVCaptureVideoDataOutput`, the
  preview layer and drag/resize need a real camera, a display and a person
  driving the panel. Manual checks to run: record with the bubble on, drag and
  resize it, pause and resume, save, reopen in the editor, export a video and a
  GIF, then repeat with camera access denied and with another app holding the
  camera. Screenshots are a main-session manual step, per
  `docs/AGENT-GUIDE.md`.
- **Performance.** No measured frame-rate or CPU figures.
- **Color fidelity.** The compositor test asserts channel dominance, not exact
  color values; a manual recording should confirm the camera and screen look
  unchanged.
