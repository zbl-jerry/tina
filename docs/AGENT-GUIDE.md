# Repository guide for coding agents

Operational rules that apply to agent-assisted work in this repository. Product
and contribution rules live in [CONTRIBUTING.md](../CONTRIBUTING.md) and
[AI-CONTRIBUTIONS.md](AI-CONTRIBUTIONS.md).

## Branches and reviews

- `dev` is the default branch and the only branch for ongoing development. Open
  every PR against `dev`.
- `main` mirrors the upstream project and exists only to sync upstream changes.
  Do not open feature PRs against it.
- Keep each PR to one independently useful change. Put unrelated docs or process
  edits on their own branch.
- Before merging, confirm the final CI run on the pushed head is green. A job
  that was cancelled is not a pass: CI cancels in-progress PR runs when a new
  push arrives, so read the newest run, not an earlier one.
- Docs-only PRs may skip CI. Put `[skip ci]` in every commit subject and in the
  merge commit subject.

## Build and verification

- Developer build: `./build.sh --dev` (add `--install` to put it in
  `/Applications`).
- Official build: `./build.sh`; health check: `./build/Tina --selftest`.
- Tests: `./build.sh --test`. Do not treat local results as a replacement for a
  CI run that has not finished.
- Builds are local; there is no automated release pipeline.

## Screenshots

- Do not delegate screenshots to subagents. An agent driving windows or
  `screencapture` can dead-lock the host Mac.
- Take UI captures from the main session only, scoped to a known window
  (`screencapture -l <windowid>`), and treat them as a manual review step.
- Use README, docs, release notes and issues as research evidence. The
  `tina-feature-research` skill no longer asks for screenshots.

## Releases (maintainer action)

- The version lives in `Resources/Info.plist` (`CFBundleShortVersionString` and
  `CFBundleVersion`). Bump it in its own commit.
- Build `./build.sh`, run `./build/Tina --selftest`, then `./Tools/make-dmg.sh`
  for `dist/Tina-<version>.dmg`.
- Tag `v<version>` and create the GitHub release from `dev`; include the
  SHA-256 in the release notes.
- Release builds are not notarized; state that, with the first-launch steps, in
  the notes.

## Layout

- `Sources/Tina/App`, `Core`, `Services`, `UI`, `Support`.
- New features go into the feature catalog with availability and permission
  checks on every entry point.
- User preferences must participate in settings backup.
