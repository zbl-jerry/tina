# Contributing to Tina

Tina aims to stay small, native and readable. Contributions are accepted
under GPL-3.0-or-later unless stated otherwise.

## Getting started

You need macOS 14 or newer, Apple Silicon and the Xcode Command Line Tools.
The project builds with `build.sh`, without an Xcode project or external package
dependencies. `Package.swift` supports editor indexing; it does not assemble or
sign the app bundle.

```sh
git clone https://github.com/zbl-jerry/tina.git
cd tina
./build.sh --dev
./build/TinaDeveloper --selftest
./build.sh --test
```

To install and launch the separate Developer app, use `./build.sh --dev --install`.
It has its own preferences and permissions and does not replace the official app.
A plain `./build.sh` builds the optimized variant used by CI; its health check is
`./build/Tina --selftest`.

### Stable signing

Developer and install builds automatically try to create a stable local signing
identity when none is available. You can also run `./Tools/setup-signing.sh`.
Keep that identity across rebuilds: ad-hoc signatures change with the binary and
can invalidate macOS permission grants. Check the build output for signing
failures. For stale grants, see [troubleshooting](docs/TROUBLESHOOTING.md#resetting-permissions).

There is no automated release pipeline in this fork. Builds are local; use the
Developer variant while developing.

## Scope and implementation

Before a substantial feature, search existing issues and PRs and discuss the
direction in an issue. Explain the user need, required permissions, dependencies
and ongoing maintenance. Prefer existing macOS capabilities and repository code
over a new subsystem. Keep each PR focused on one independently useful change.

If the idea comes from another open-source project, run the repository's
`/tina-feature-research` skill first. It checks macOS 15 support, native
implementation, the 30 MB release budget, complexity and overlap with existing
features, then produces the issue text in the feature-request format.

- App lifecycle lives in `Sources/Tina/App`, shared catalogs and preferences
  in `Core`, behavior in `Services`, views in `UI`, and diagnostics in `Support`.
  Keep reusable decisions outside views where they can be tested.
- Check other callers and the upgrade path when fixing shared behavior.
- New features belong in the feature catalog, with availability and permission
  checks on every entry point. Optional background work should stop when disabled.
- User preferences must participate in settings backup. Machine-specific state
  and private content need an explicit exclusion.
- Update every locale in `AppLanguage.allCases`, including feature-specific
  string catalogs. A new language also needs its locale registration, localized
  permission prompts where applicable, and coverage tests.
- New source files retain the project's SPDX license and copyright headers.

Sensor changes should include a dump from `./build/Tina --sensors` and the
Mac model. Selection logic lives in `TemperatureSensorSelector` and `SystemMonitor`.

## Validation

Documentation-only changes need a diff and link check. For code changes, run the
relevant tests; `./build.sh --list-tests` lists suites and
`./build.sh --test-suite=NAME` selects one. Behavior tests should fail without the
fix and preserve legitimate use, rather than pinning private implementation text.

The test executable compiles a selected set of sources, so passing tests does not
prove the app builds. Build the app and run its selftest for runtime, UI or bundled
resource changes. CI also checks the optimized build, selftest, tests and packaging.
Builds should finish without warnings.

For behavior involving windows, permissions or hardware, describe what you actually
verified and on which Mac and macOS version. Include display, Spaces or language
details when relevant, and state what remains untested. Compilation and static
inspection alone do not demonstrate an interaction on a real Mac.

## Pull requests

Explain the behavior before and after, the scope and validation. Use
`type(scope): lowercase imperative phrase` for the title and reuse an existing
scope where possible. Open unfinished work as a draft and name what is missing.
The [template](.github/PULL_REQUEST_TEMPLATE.md) is a prompt, not a form.

Leave version bumps to the maintainer. Describe the user-visible effect in the PR
so it can become a release note with your credit.

When an issue exists, include one reference per line:

```text
Refs #123
Refs #456
```

Avoid `Closes` or `Fixes` in a PR that is not released yet: those close the issue
at merge, before users receive the fix. If the PR addresses only part of an issue,
say exactly which part.

For agent-assisted work, see [contributing with an agent](docs/AI-CONTRIBUTIONS.md).
Bug reports and feature requests use the [issue forms](https://github.com/zbl-jerry/tina/issues/new/choose).
Report vulnerabilities through [private security reporting](SECURITY.md).

## Branches

`dev` is the default branch and the only branch for ongoing development.
`main` mirrors the upstream project and is used only to sync upstream changes;
do not open feature PRs against it.
