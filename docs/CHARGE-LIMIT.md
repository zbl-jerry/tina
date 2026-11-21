# Charge limit

Tina can stop a plugged-in MacBook from charging at a chosen level. It is the
one feature that writes battery-facing SMC state, so this document records the
research, the product decisions, the system design and exactly what was
verified.

## Why

People who use a MacBook on the adapter all day want the battery held around
80% rather than sitting at 100%. macOS "Optimised Battery Charging" is opaque
and only acts at the top of the range; macOS 26.4 added a native adjustable
limit. The upstream project investigated for issue #5, `batt`
(<https://github.com/charlie0129/batt>), solves this for macOS 11 through 26.

The issue's original research concluded **defer**: the feature needs a
privileged process writing SMC keys, and the issue's author did not want to
enlarge the fan helper's responsibility. This implementation revisits that
decision because two facts changed the cost:

- Tina already ships a signed, `SMAppService`-registered root daemon
  (`FanControlHelper`) and an SMC client with a narrowly scoped write API. No
  new installer, approval flow or signing identity is required.
- The charge control is a pair of documented boolean SMC keys, not a fan
  control loop with per-model firmware curves. The hardware surface is small
  and can be probed at runtime.

The trade-off is explicit: the daemon now has two independently owned
capabilities. They share the process, code-signing requirement and approval,
but have separate controllers, owner sessions, lock/marker files and teardown
paths. Uninstalling Fan Control no longer unregisters the daemon while the
charge limit is switched on.

## What it does (MVP)

- A card on **Settings → Energy** for Apple Silicon MacBooks with a battery and
  a charge-control SMC key. Other Macs get one row explaining that the feature
  is unavailable; the hub entry is greyed with the same reason.
- An upper limit slider from **60% to 100%** (default 80%).
- Charging stops at the upper limit and resumes **5 points lower**, so a Mac at
  the limit does not toggle the SMC key every few seconds.
- **Charge to full once** releases the limit until the battery reports full or
  100%. The next evaluation puts the limit back if the Mac stays plugged in.
- Switching the feature off, uninstalling it, quitting Tina, a helper crash or
  a complete uninstall all put normal charging back.

Deliberately not in this version, matching the issue's MVP:

- Running from the battery, or cutting wall power (batt's "adapter mode").
- Bypassing the system's own charge policy, calibration, MagSafe LED control.
- Automatic lower-limit deltas, schedules or CLI/daemon control.
- The firmware-managed limit keys (`bfF0`/`bfD0`/`bfE0`) used by newer
  firmware; see limitations.

## How it works

### Which keys

`batt` documents two layouts for Apple Silicon:

| Layout | Keys | Allowed | Inhibited |
|---|---|---|---|
| Tahoe-era state key | `CHTE` (ui32) | `00 00 00 00` | `01 00 00 00` |
| Older flag pair | `CH0B`, `CH0C` (ui8) | `00` | `02` |

Tina probes `CHTE` first, then the pair. A Mac that exposes neither is treated
as unsupported. The probe is read-only and runs once per process.

The investigation Mac (Mac16,1, macOS 15.7.7, firmware `mBoot-18000.120.36`)
exposes `CHTE` but **not** `bfF0`/`bfE0`, so the firmware-managed path is not
used. `CH0B`/`CH0C` are absent there, and `CH0J`/`CHIE` (adapter keys) are
present but intentionally unused because this version never runs the Mac from
the battery.

### Enforcement

1. The app registers the existing daemon and sends a policy:
   `{ upperPercent, chargeToFull }`.
2. The helper reads the battery through `IOPSCopyPowerSourcesInfo` (percentage,
   charging, adapter, charged flag) and reads the SMC inhibit byte.
3. `ChargeLimitPolicy.decision` returns one of:
   - **inhibit** — at or above the upper limit,
   - **allow** — at or below `upper − 5` (or charge-to-full is active),
   - **hold** — inside the band; write nothing.
4. The helper writes the key, reads it back byte-for-byte, and reports failure
   if the state did not stick (in which case it immediately restores charging).
5. The helper re-evaluates every 30 seconds on its own queue, so the limit holds
   while the app is idle or the display is asleep. The app also refreshes every
   30 seconds for the card, and applies immediately on a slider move or wake.

### Safety and restoration

The helper only acts while a client session is open. Charging is put back when:

- the owning XPC connection drops (app quit, crash, logout),
- the app asks to switch the feature off,
- the helper receives `SIGTERM`/`SIGINT`,
- the helper restarts and finds its own marker `/var/run/tina-charge-limit.active`,
- the app is uninstalled (`--uninstall` and the in-app uninstall both call the
  same synchronous restore before unregistering the daemon).

The marker is what makes "put it back" safe: Tina only writes "allow charging"
when its own marker says Tina stopped it, so another tool that holds the same
key is left alone. The marker is root-owned, mode 0600, and created only after
a successful inhibit. If it cannot be created, charging is restored immediately
and the request fails.

The normal state is **not inhibited**: when Tina is not running, the adapter
charges the battery as macOS would.

## Limitations

- **macOS 27 gating.** Starting with macOS 27 Developer Beta 4 (firmware
  `20457+`), Apple gates the charge keys behind a private entitlement; `batt`
  falls back to PowerUIAgent's native limit. Tina's legacy-key path will fail
  on that firmware; the feature reports an error and restores charging rather
  than pretending to hold a limit. **Unverified here:** the development Mac runs
  macOS 15.7.7.
- **Firmware-managed keys are not implemented.** On firmware that exposes
  `bfF0`/`bfD0`/`bfE0`, Apple could enforce the limit even while Tina is not
  running. That is a better long-term backend but cannot be exercised on the
  investigation Mac, so it is left for a follow-up with the appropriate
  hardware.
- **No drain.** Above the limit, the battery simply stays where it is while
  plugged in; macOS may still report "not charging". Tina does not cut wall
  power, so the level cannot fall on its own.
- **Only while Tina runs.** Quitting Tina restores normal charging. Persisting
  a limit across app launches would need the daemon to own the policy and is
  out of scope for a beta MVP.
- **Shared daemon.** Fan Control and the charge limit share one root process.
  The helper version stamp covers both, so an update re-registers the daemon
  once. If Fan Control is uninstalled while the charge limit is enabled, the
  daemon stays registered.
- **No menu panel row yet.** The control lives on Settings → Energy. The menu
  panel's Power card keeps its current readings; a status row there, next to
  battery health, is a natural follow-up once the feature leaves beta.
- **Beta.** The hub marks the feature as beta; a wrong write is recoverable,
  but the firmware matrix is large and the maintainer has only one Mac.

## Testing notes

Verified locally on the Mac16,1 above:

- The helper compiles standalone and `--selftest` passes, including charge
  policy and key-payload checks.
- `Tests/ChargeLimitTests.swift` pins clamping, hysteresis, charge-to-full,
  key detection, byte payloads and IPC validation.
- The Developer app builds and its `--selftest` passes.

**Not verified in this change:** an actual SMC write on hardware. Reading the
keys is verified (`CHTE` present, `CH0B`/`CH0C` absent); writing requires the
root helper to be registered, and the investigation deliberately did not
install or drive it on the development Mac. A reviewer with a spare MacBook, or
the maintainer on their own machine, should switch the feature on, watch the
battery stop at the limit, turn it off, and confirm charging resumes. The
helper's `log stream --predicate 'subsystem == "com.tina.utils.fan-control"'`
entries name each failure.
