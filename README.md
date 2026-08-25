# Dex

Dex is a native macOS companion surface for T3 Code. It sits around the
built-in camera housing, shows agent activity and context usage at a glance,
and expands into a Liquid Glass thread overview.

Dex is under active development. It connects to T3 Code through explicit,
read-only pairing and reads the signed-in Codex account's weekly allowance
through the local Codex app server.

## Requirements

- macOS 14 or later
- Xcode 26 or a compatible Swift 6 toolchain
- Liquid Glass requires macOS 26; earlier supported systems use a native
  material fallback

## Run

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --expanded
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

`--expanded` launches directly into the disconnected expanded state for visual checks.
Run tests directly with `swift test`.

## Install and update

Public builds are distributed as signed and notarized universal DMGs on
[GitHub Releases](https://github.com/decocereus/dex-notch/releases). Drag
`Dex.app` to the Applications shortcut in the DMG, then open Dex from Spotlight
or Launchpad.

Dex uses Sparkle's signed update feed. Expand the notch and choose the circular
arrow button to check for an update; Sparkle also offers automatic update
checks after the first launch.

Release maintainers should follow [`docs/releasing.md`](docs/releasing.md).

## Current scope

- one non-activating AppKit panel across Spaces and full-screen apps;
- live notch geometry from `NSScreen`;
- compact, expanded, disconnected, and no-notch fallback layouts;
- Liquid Glass expansion on macOS 26;
- read-only T3 activity and context usage;
- weekly Codex allowance and signed Sparkle updates.

See [`docs/architecture-plan.md`](docs/architecture-plan.md) for the remaining
compatibility, accessibility, and public-release proof gates.
