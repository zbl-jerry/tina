# Night warmth

Night warmth lowers the colour temperature of every display on a schedule:
the screens warm up around sunset, can go warmer still at bedtime, and return
to the daytime temperature in the morning. It is an alternative to f.lux and
Luz that lives under Tina's existing brightness controls.

## What it does

- **Schedule.** Two modes: sunset to sunrise from coordinates, or two clock
  times. Solar times are calculated on the Mac from the time zone's anchor
  city, or from coordinates typed into Settings. Nothing is requested from the
  network and no location permission is used.
- **Bedtime.** An optional second, warmer temperature between bedtime and wake
  time. The window may wrap midnight.
- **Transitions.** Slow fades over an hour, fast over twenty seconds. Fades
  interpolate in mireds, not kelvin, so the change reads as even across the
  whole range.
- **Presets.** 6500, 5500, 4200, 3400, 2700, 1900 and 1200 K. Warmer, Cooler
  and the presets apply to the current phase only; the next scheduled change
  clears them.
- **Pause.** For an hour or until the next sunrise (or wake time while Bedtime
  is on). A pause removes the tint; resuming restores the schedule.
- **Panel and Settings.** The menu panel's brightness section shows the phase
  and the temperature, with the same presets and pause control. The Energy
  page holds the full schedule.

## How it works

The warmth is a gamma table per active display, applied through the public
`CGSetDisplayTransferByTable` API. Each table scales the red, green and blue
channels toward the white point of a Planckian radiator at the chosen
temperature, normalised against 6500 K so the neutral end is exactly the
identity. That means:

- **No permission.** Gamma tables are a public CoreGraphics call. The feature
  asks for nothing in the Permissions page.
- **No helper, no system files, no network.** The tables live in the session.
- **Restores on disable, quit and after a crash.** Turning the feature off, or
  quitting Tina, writes the identity table back to every active display. A
  marker in preferences asks the next launch to repair a tint left behind if
  the process died unexpectedly.

The service runs a one-second timer only while the feature is switched on. When
it is off, no timer, observer or gamma write exists.

## Limitations

- **It tints, it does not dim.** The gamma tables preserve the brightest channel
  and the display's own brightness controls are untouched. Dimmer and Brighter
  are left to the existing brightness feature rather than duplicated here.
- **Night Shift is not detected.** If the system's Night Shift is also on, the
  two tints stack. Tina does not change Night Shift settings and does not read
  them through private APIs; turn one of them off if the result is too warm.
- **Other gamma tools conflict.** Two apps that both write transfer tables
  overwrite each other; whichever wrote last wins.
- **Global shortcuts are not included in this version.** Warmer, Cooler and
  pause are available from the panel. The f.lux key layout can be added later
  without changing the schedule model.
- **Solar times are approximate.** The calculation is the standard NOAA
  approximation (within a few minutes at mid latitudes). It reports no sunrise
  or sunset during a polar day or night, and the schedule then falls back to
  18:00 and 06:00 local.

## Testing notes

The schedule, solar maths and gamma ramp are pure functions in
`Sources/Tina/Services/Display/NightWarmthSupport.swift`; `Tests/NightWarmthTests.swift`
pins them (mired interpolation, white point, table shape, Shanghai solstices,
polar night, custom windows that wrap midnight, bedtime and pause). The display
side writes gamma tables, so it is verified by eye on a real Mac: switch the
feature on, confirm the tint, quit, and confirm the colours return.
