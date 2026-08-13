# Dex

Dex is a native macOS companion surface for T3 Code. It sits around the
built-in camera housing, shows agent activity and context usage at a glance,
and expands into a Liquid Glass thread overview.

Dex is under active development. The rejected Phase 0 fixture prototype has
been removed from the production launch path; the app currently reports an
honest disconnected state until read-only T3 pairing is implemented.

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

## Current scope

- one non-activating AppKit panel across Spaces and full-screen apps;
- live notch geometry from `NSScreen`;
- compact, expanded, disconnected, and no-notch fallback layouts;
- Liquid Glass expansion on macOS 26.

The read-only T3 Code connection and final morphing visual treatment are the next phase. See
[`docs/architecture-plan.md`](docs/architecture-plan.md) for the integration
and release plan.
