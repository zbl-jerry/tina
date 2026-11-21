# Per-app scrolling and the hold key

Smooth scrolling has one speed for every app. Per-app overrides and a hold key
let one mouse feel right everywhere: precision tools keep the raw wheel, apps
you read in keep the glide, and a key held for a moment returns to raw input
without opening Settings.

Both live in **Mouse & keyboard → Smooth scrolling** and need Smooth scrolling
to be on. Neither adds a permission, a background helper or a second event tap.

## Per-app overrides

Each listed app has one of three smoothing modes:

- **Follow global** uses the slider above. This is also what an app that is not
  listed uses.
- **Off** delivers the wheel to that app exactly as macOS produced it, with no
  glide. Direction inversion still follows the settings below.
- **Custom** uses its own step (distance per notch) and speed (a percentage of
  the global speed) for that app.

A row can also **invert the vertical direction** for that app alone, whatever
the global direction setting says. Horizontal inversion, linear scrolling and
modifier-held speed remain global settings.

The app picker is the same one the mouse exclusion lists use. An app on a
feature's **apps to leave alone** list still wins: the feature stays away
entirely, and a per-app override for it does nothing.

Changes apply to the next wheel event; no restart and no new Accessibility
grant are needed.

## The hold key

Hold a modifier while scrolling to correct the current app for a moment:

- **Pause smoothing** sends the raw wheel while the key is held. The glide in
  flight is dropped, and the next tick after releasing glides again.
- **Slower** and **Faster** scale the glide distance by the configured amount.

The key is removed from the event, so the receiving app does not see it. Shift
is not offered: Shift + wheel already means sideways scrolling, and that
redirect happens before the hold key. A key also used by sideways scrolling or
Pinch Zoom keeps that shortcut's meaning; a key also used by modifier-held
speed is claimed by the hold setting while smoothing is on.

## Precedence

1. Feature off, or the app is on the feature's **apps to leave alone** list.
2. The hold key.
3. The app's override.
4. The global Smooth scrolling settings.

## Settings and backup

The override table and the hold-key settings are ordinary Tina preferences:
they travel with Settings backup, and they stay in place when Smooth scrolling
is uninstalled and installed again.

## Limits

- Overrides apply to whole apps, not to a mouse model or a window.
- Only vertical direction can be inverted per app.
- Linear scrolling, modifier-held speed, sideways scrolling and Pinch Zoom stay
  global.
- Logitech HID++ events and vendor-specific buttons are outside this feature.

## How it works

The smooth scrolling tap resolves the receiving app from the event target
(`eventTargetUnixProcessID`) against a `pid → bundle id` map built from the
running applications that appear in the override table. The map is refreshed on
launch, termination and preference changes, and the tap only reads it under a
lock, so the pointer thread never waits on the main thread.

An override of `off`, or the hold key in **Pause smoothing**, stops the glide
and passes the original event through. Otherwise the tap computes

```text
distance = ticks × step × app speed × hold speed × modifier speed
```

where `step` and `speed` come from the override when it is `custom` and from
the sliders otherwise. The vertical flip is applied in the smooth tap when it
produces the glide; the scroll-direction tap applies the same per-app flip to
raw wheels, including when it runs only for linear scrolling.

The settings are stored as a JSON array in `scrollPerAppOverrides`, with
`scrollHoldEnabled`, `scrollHoldModifier`, `scrollHoldAction` and
`scrollHoldFactor` beside the existing smooth scrolling keys. Malformed entries
are ignored, numbers are clamped to their ranges, and an empty table behaves
exactly like never opening the feature.
