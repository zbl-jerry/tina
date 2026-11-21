# Verification codes

Verification codes bring standard time-based one-time passwords (TOTP) to the
menu bar. They replace reaching for a phone, unlocking it, finding the right
authenticator entry and typing six digits into the Mac. Tina already sits in the
menu bar, so the code is one click away, and no account, sync service or browser
extension is involved.

The feature follows issue #7 and the local-first part of the upstream
[TOTPBar](https://github.com/jerry-pond/TOTPBar) idea. Only the standard TOTP
core is implemented; the optional HTTP API and global fill shortcuts are not.

## What it does

- **Menu bar list.** Utilities gains a Verification Codes tile. The panel lists
  every account with a live code and the seconds left in the step. Clicking a
  row copies the code.
- **Quick panel.** The same tile is available in the floating quick panel, where
  it opens the list inside the launcher instead of the menu bar popover.
- **Masked by default.** A code shows dots until the pointer rests on it, so a
  passing glance or a screenshot of the list does not carry a working code. The
  panel window and the Settings window are excluded from screen capture while
  the list is visible; the codes return when the view leaves the screen.
- **Add from a setup link.** Paste the `otpauth://totp/...` link a service shows
  next to its QR code. The label, issuer, algorithm, digit count and period are
  filled into the same form a manual entry uses.
- **Add from a QR code on screen.** The existing screen text tool selects an
  area, reads matrix codes offline with Vision, and returns the first `otpauth`
  payload to the add form. Nothing is uploaded.
- **Add manually.** Enter a name, optional issuer and Base32 key. Advanced
  controls choose SHA1, SHA256 or SHA512, 6 or 8 digits, and a period from 1 to
  3600 seconds (30 by default).
- **Edit and order.** Rename an account, change its issuer, move it up or down,
  and delete it. Changing the key itself means adding the account again, so a
  typo cannot silently replace a working secret.
- **Clipboard hygiene.** A copied code is written with the nspasteboard.org
  concealed mark, so clipboard history skips it. The existing auto-clear rules
  still see the copy and apply. The copy is signed as Tina's own.

## Product decisions

The MVP from issue #7 was kept deliberately small:

- **Standard TOTP only.** SHA1, SHA256 and SHA512, 6 or 8 digits, a custom
  period. Counter-based HOTP links are refused with an explanation.
- **Local only.** No account, no cloud sync, no local HTTP API, no passkey or
  WebAuthn, and no password-manager features.
- **One setup path at a time.** A setup link fills the manual form rather than
  creating a parallel import model. Every add therefore runs the same validation
  and the same Keychain write.
- **Codes are read-only after save.** Algorithm, digits, period and secret
  cannot be edited in place. Renaming is safe; replacing a secret requires a
  fresh add.
- **The panel lists and copies.** Adding and editing live on the Settings page,
  where the setup form and QR selection have room and do not dismiss the menu
  panel.
- **Not in this version.** Camera scanning, importing Google Authenticator's
  export file, global shortcuts that type into the focused field, and the
  upstream HTTP API.

These choices keep the feature small, avoid new permissions for the core, and
leave the riskiest surfaces, the Keychain and the on-screen code, with fewer
moving parts.

## How it works

| Part | Responsibility |
|---|---|
| `Services/TOTPAuthenticator/TOTPSupport.swift` | Pure logic: Base32, the `otpauth` grammar, RFC 6238 code generation, counters, grouping and masking. |
| `Services/TOTPAuthenticator/TOTPKeychainStore.swift` | One Keychain generic-password item per account. |
| `Services/TOTPAuthenticator/TOTPAuthenticatorService.swift` | Account metadata, ordering, Keychain reads, code generation and the concealed pasteboard copy. |
| `UI/Settings/TOTPAuthenticatorSettings.swift` | Settings page, add sheet and rename sheet. |
| `UI/MenuPanel/PanelTOTPAuthenticatorView.swift` | Panel list, hover reveal, copy and capture exclusion. |
| `Services/QuickTools/ScreenTextService.swift` | One-shot QR payload read for the add form, reusing the screen text capture. |

### Adding an account

1. A setup link is parsed by `TOTPSupport.parse`: scheme and type are checked,
   the secret is decoded as Base32, and the label, issuer, algorithm, digits and
   period are validated. Duplicated parameters are refused rather than resolved
   silently.
2. The parsed values fill the manual form, with the secret re-encoded to Base32
   so the person can review exactly what will be saved.
3. Saving writes the secret to the Keychain first. Only when that succeeds is
   the account appended and the metadata string persisted. A failed Keychain
   write leaves no half-saved row.
4. Manual entries go through the same path; the Base32 decoder is the single
   rule for both.

### Producing a code

Each visible list is wrapped in a one-second `TimelineView`. For every row the
service computes the current counter from the Mac clock, HMACs the counter with
the account's algorithm, applies dynamic truncation and pads to the requested
digit count. The Keychain is read once per account and the secret is cached in
memory for the rest of the session.

There is no timer while the list is not visible. Closing the panel or leaving
the Settings page stops the redraw.

### Storage and backups

- **Secrets.** Keychain generic-password items under the service
  `<bundle id>.totp`, account name equal to the account's UUID. The item is
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and not synchronizable, so it
  never travels through iCloud, is not readable while the Mac is locked, and is
  separate between the Developer and official builds.
- **Metadata.** The account labels, issuer and TOTP parameters are one JSON
  string in `totpAccountsData`. The key is deliberately not registered as a
  preference, and it is named in the settings backup's machine-state exclusions:
  a settings file cannot carry Keychain items, and restoring labels without
  their secrets would leave rows that cannot produce a code.
- **Deletion.** Deleting an account deletes its Keychain item and then the
  metadata. Uninstalling the feature or the app does not remove Keychain items;
  remove accounts first if that matters.

### Security boundaries

- Neither the key nor the setup link is put into an error message, a log, the
  preferences file or a backup.
- Error messages are chosen texts from the string catalog, not echoes of input.
- Labels are stripped of control characters and capped in length. Setup links
  are capped at 4 KB, secrets at 128 bytes, and Base32 padding is only accepted
  at the end.
- The core asks for no permission. Reading a QR code on screen is optional and
  uses the existing Screen Recording permission and Screen OCR feature; the add
  form says so when that feature is unavailable and asks for the permission when
  it is missing.
- While a code list is visible, the hosting window's `sharingType` is `.none`.
  This is the same public CoreGraphics/AppKit switch Tina's brightness overlay
  uses; it keeps the window out of screen recordings and screenshots. The
  previous value is restored when the view disappears.
- Secrets stay in memory while Tina runs, as they must to redraw codes without
  prompting the Keychain every second.

## Setup link support

`otpauth://totp/LABEL?secret=...` with these parameters:

| Parameter | Values | Default |
|---|---|---|
| `secret` | Base32; spaces, hyphens and trailing `=` tolerated; 5 to 128 decoded bytes | required |
| `issuer` | free text; overrides the label's `Issuer:` prefix | label prefix |
| `algorithm` | `SHA1`, `SHA256`, `SHA512` (also `SHA-1` etc.) | `SHA1` |
| `digits` | `6` or `8` | `6` |
| `period` | `1` to `3600` seconds | `30` |

Unknown parameters such as `image` are ignored. A duplicated recognised
parameter, a `hotp` link, a missing or invalid secret, an out-of-range value or
an empty label is refused with a message that names the problem but not the
input.

## Limitations

- **No sync or accounts.** Entries are local to this Mac and do not follow the
  user through iCloud or a settings backup.
- **No HOTP.** Only time-based codes are supported.
- **No camera scan or export-file import.** A QR code is read from the screen
  through Screen OCR; a phone-camera scan and Google Authenticator's export are
  not implemented.
- **The key cannot be edited.** Delete and add the account again to replace a
  key.
- **The period is capped at an hour.** Values outside 1 to 3600 seconds are
  refused, and only 6 or 8 digit codes are accepted.
- **The Mac clock is the only clock.** If it is wrong, services reject the
  codes; Tina does not contact a time service.
- **Keychain items survive uninstalling.** They are device-only, but deleting
  Tina or the feature does not purge them.
- **The whole window is excluded from capture while a list is visible.** This is
  intentional; a screenshot of the panel or the verification page shows neither
  the codes nor the rest of that window.
- **No global fill shortcuts.** The code is copied, not typed into the focused
  field.

## Testing notes

The pure half lives in
`Sources/Tina/Services/TOTPAuthenticator/TOTPSupport.swift`.
`Tests/TOTPAuthenticatorTests.swift` pins:

- the RFC 6238 Appendix B vectors for SHA1, SHA256 and SHA512, all six times,
  plus six-digit truncation and leading zeros;
- Base32 decode/encode examples, case and separator tolerance, invalid
  alphabets, mid-string padding and an all-bytes round trip;
- counter and countdown boundaries, including the first second of a step and
  times before the epoch;
- setup-link parsing for percent-encoded labels, issuer precedence, unknown
  parameters, hyphenated algorithm names and every refusal case;
- the service through an in-memory secret store and an isolated preferences
  domain: add, reload, rename, reorder, delete, failed Keychain writes, missing
  Keychain items, damaged metadata and duplicate ids;
- grouping, masking, the stable algorithm list and JSON round trips that contain
  no secret.

Commands used locally:

```sh
./build.sh --test          # TESTS OK, 124457 checks
./build.sh --dev           # Developer bundle assembles and signs
./build/TinaDeveloper --selftest
```

The window behaviour, the Keychain write and the Vision QR read are not
exercised by that harness. They need a real Mac and a manual pass: add an
account from a setup link and compare its code with the service, add one from a
QR code on screen, hover and copy a code, confirm clipboard history does not keep
it, confirm a screen recording of the panel does not show the window, and check
in Keychain Access that deleting an account removes its `<uuid>` item under the
`<bundle id>.totp` service.
