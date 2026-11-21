# Hosts profiles

Hosts profiles keep several named sets of hosts entries and switch between
them without editing `/etc/hosts` by hand. It replaces the usual
`sudo vim /etc/hosts` loop and the dedicated app that used to be installed for
it.

## What it does

- **Profiles.** Each profile has a name, a hosts fragment and an enabled
  switch. The list order is the write order, so a host name repeated across two
  profiles resolves to the first enabled one.
- **Apply.** One button writes the enabled profiles into `/etc/hosts` and asks
  macOS for an administrator password once. The menu panel offers the same
  switches and the same button.
- **Backups.** Before every write, the whole current file is saved under the
  app's Application Support folder. The last ten backups are kept, and any of
  them can be restored from Settings or the panel.
- **Validation.** Lines are checked as they are typed. Only an IP address
  followed by host names, a comment, or a blank line is accepted. Invalid
  entries block the apply button and say which line and why.
- **Status.** The page and the panel report whether the enabled set matches the
  file, how many mapping lines are active, and when the last apply ran.

## How it works

Tina owns one delimited block in the file:

```text
# >>> Tina hosts profiles >>>
# === Local development ===
127.0.0.1 api.example.com
# <<< Tina hosts profiles <<<
```

Applying removes any previous Tina block, appends the new one, and keeps every
other line exactly as it was. Clearing every profile removes the block and
leaves the rest of the file untouched. `localhost` and any entries maintained
by the system or other tools are therefore never rewritten by a profile.

The write itself is a one-time elevation through the same `AdminShell` helper
the closed-lid setting uses: `/usr/bin/install` runs once as root with a temp
file prepared by Tina. There is no resident helper, no launch agent and no
sudoers rule, so the password is requested only when a write is actually
needed. The temp file is removed whichever way the prompt ends.

Validation runs before the prompt. Addresses are read with `inet_pton`, so only
real IPv4 or IPv6 values (with an optional `%zone`) pass; host names are
restricted to ASCII letters, digits, dots, hyphens and underscores and may not
begin or end with a hyphen or dot. This is what keeps shell metacharacters,
redirection, paths and newline injection out of the generated file. The comment
lines that delimit the block are reserved and refused inside a profile.

State is read back from `/etc/hosts` rather than remembered, so the page cannot
claim an apply that did not land. A previous block with an unmatched marker is
treated as damage: Tina refuses to overwrite it and points at the backups
instead.

## Limitations

- **One administrator prompt per write.** Saving profile edits does not ask for
  a password; applying or restoring does. A write that changes nothing does not
  ask.
- **No DNS flush.** New name lookups see the change. Connections that are
  already open keep using their address until the app reconnects.
- **No remote subscriptions.** Profiles are local. Fetching and refreshing
  hosts lists from a URL is not part of this version.
- **No grouping or syntax highlighting.** The editor is plain text with
  validation.
- **Only Tina's block is managed.** Lines outside it are preserved, not
  switched, and manually removing the markers makes the apply refuse.
- **Restore writes the whole file.** Restoring a backup puts that exact file
  back, so entries added after the backup are replaced. Tina backs up the
  current file first, which makes that reversible too.

## Testing notes

The pure half lives in `Sources/Tina/Services/HostsProfiles/HostsProfilesSupport.swift`:
line validation, the managed block, its removal, the change signature and
backup retention. `Tests/HostsProfilesTests.swift` pins valid and invalid
entries, injection attempts, replacement and clearing, unbalanced markers,
CRLF normalization, retention and the stored format.

The privileged half is verified on a real Mac: apply a profile, confirm name
resolution, add a line by hand, apply again and confirm the hand-written line
survives, clear every profile and confirm only Tina's block disappears, then
restore a backup and confirm the file matches it. Cancelling the password
prompt must leave the file unchanged.
