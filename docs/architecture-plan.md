# Dex — architecture and delivery plan

## Outcome

Build an open-source, native macOS companion for T3 Code that:

- sits around the built-in camera housing as compact left and right “wings”;
- expands downward into a glanceable thread-activity surface;
- shows which threads are working, monitoring, waiting for approval/input, completed, or failed;
- shows accurate per-thread context/token usage;
- opens the corresponding thread in the installed T3 Code app;
- detects the installed T3 Code build and sends users to <https://t3.codes> when it is absent;
- remains useful on a Mac or display without a camera housing through a top-center fallback.

This document is the planning source of truth. It was based on the local fork at
T3 Code commit `5a84614809b6e853b872f9e57ff4b97e9df5df02`, checked against the
official upstream contracts on 2026-08-13, and the locally installed T3 Code
Nightly `0.0.34-nightly.20260813.1082`.

## Prototype reset — 2026-08-13

The first fixture-driven visual spike was rejected after on-device testing. It
had four fundamental defects: fabricated activity and usage, a global pointer
monitor that treated the whole panel frame as a target, unreliable window
ordering, and separate compact/expanded views rendered as a stack instead of
one morphing surface. The process was stopped and the fixture model was removed
from the production launch path.

No later phase may call the product usable until all four gates below pass:

1. **Truth:** only authenticated T3 projections are displayed; unavailable
   values render as unavailable.
2. **Targeting:** collapsed hover tracking exists only on the two visible wings;
   the physical camera gap is never a hit target.
3. **Windowing:** expansion is ordered front deterministically across activation
   and Space changes without taking application focus.
4. **Morph:** compact content is replaced by one expanded surface; it is never
   retained as a second header above the expanded layout.

## Scope and limits

### First public slice

- macOS 14 or later, Apple silicon first; validate Intel before the first public release.
- Native Liquid Glass on macOS 26 or later, with a restrained material fallback
  on macOS 14 and 15.
- One local T3 Code environment.
- Read-only connection to T3 Code.
- Compact, expanded, disconnected, no-notch, and T3-not-installed states.
- Thread activity and per-thread context-window usage.
- Manual launch at login toggle.
- GitHub-source build plus signed and notarized DMG release.

### Explicitly deferred

- Acting on approvals or prompts from the companion.
- Starting, stopping, or mutating T3 threads.
- Multiple remote T3 environments.
- Mac App Store distribution.
- Provider billing estimates.
- Provider quota/rate-limit percentages until T3 exposes them through a typed,
  durable read contract.
- A WidgetKit desktop widget. This product is a persistent overlay application,
  not a system widget.

## Decisions

### 1. Swift 6 language mode, SwiftUI, and a small AppKit window layer

Use Swift 6 language mode and SwiftUI for the view hierarchy, with AppKit owning
the actual overlay window. The initial toolchain is Xcode 26.6 with Apple Swift
6.3.3; record the Xcode version in CI rather than treating “Swift 6” as a precise
compiler version. The overlay should be a borderless, transparent,
non-activating `NSPanel` at the status-window level. It should join all Spaces,
behave as a full-screen auxiliary window, avoid the normal window cycle, and
never take focus for ordinary clicks.

This is preferable to Electron because the difficult parts are native window
placement and behavior, not web rendering. It also gives the companion a much
smaller idle memory and energy footprint.

Apple exposes the camera-housing geometry through `NSScreen.safeAreaInsets`,
`auxiliaryTopLeftArea`, and `auxiliaryTopRightArea`. The panel should derive the
housing gap from those values rather than hard-code a Mac model or notch width.

References:

- <https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets>
- <https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc>
- <https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel>
- <https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct>
- <https://www.swift.org/blog/swift-6.3-released/>

### 2. `NSPanel` for behavior, Liquid Glass for the expanded surface

Use one transparent panel spanning the housing and both wings. Draw a single
black compact bridge behind the physical camera housing so the idle shape reads
as one notch. When the surface expands, render the thread card and interactive
controls with SwiftUI Liquid Glass on macOS 26 or later. On older supported
systems, use a tuned `Material`/`NSVisualEffectView` fallback with the same
geometry and contrast.

`NSPanel` and Liquid Glass are complementary, not alternatives:

```text
NSPanel                         window behavior
└── transparent SwiftUI root    precise notch geometry
    ├── compact black bridge    visually joins the camera housing
    └── expanded card           Liquid Glass on macOS 26+
        └── fallback            system material on macOS 14–15
```

Apply glass to the expanded functional layer, not indiscriminately to every
pixel. Apple positions Liquid Glass as a floating control/navigation layer; an
always-translucent compact bridge would weaken the illusion that the UI belongs
to the physical black housing. Use `glassEffect(_:in:)` for the custom expanded
shape. Place the related compact and expanded glass elements in one
`GlassEffectContainer`, and use stable `glassEffectID`s with a local namespace
when they should morph into one another.

Do not coordinate two independent windows; their animation, hit testing, Space
transitions, and screen changes would drift.

References:

- <https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views>
- <https://developer.apple.com/videos/play/wwdc2025/219/>

The main presentation states are:

1. `unavailable` — T3 Code is not installed; show a quiet install affordance.
2. `disconnected` — T3 is installed but its local server is unavailable.
3. `compactIdle` — connected with no active or attention-needing work.
4. `compactActive` — activity count and usage are visible in the wings.
5. `peek` — a short, non-focus-stealing status reveal after a meaningful change.
6. `expanded` — user-requested thread list and usage detail.

Hovering either visible wing expands the surface. Each wing owns its own local
tracking area; do not use a process-wide `mouseMoved` monitor or the containing
window rectangle as hover truth. Pointer exit waits briefly
before collapsing so the transition can be crossed without flicker; clicking a
wing remains an explicit fallback. AppKit owns pointer tracking across the
non-activating panel while SwiftUI owns the presentation state.
Attention should change color and may trigger a brief peek, but must not steal
focus. Respect Reduce Motion by replacing spring geometry with a short fade and
scale transition.

### 3. Reuse T3’s activity semantics

Do not create a new meaning for “working” or “done.” Subscribe to T3’s
`orchestration.subscribeShell` read stream and map its existing shell fields in
the same priority order as the T3 sidebar and mobile Agent Activity:

1. pending approval;
2. awaiting input;
3. running or starting;
4. plan ready;
5. background working;
6. monitoring;
7. unseen completion;
8. idle.

The shell already contains thread title, project relationship, latest turn,
session state, pending approval/input flags, background liveness, and plan
progress. This is the authoritative low-bandwidth surface for the notch list.

### 4. Treat usage as two separate products

For v0.1, “usage” means the active thread’s context window: used tokens, maximum
tokens when known, and the most recent turn token counts. T3 already persists
`thread.token-usage.updated` as `context-window.updated` activity in the thread
projection. Subscribe to details only for the few visible/active threads, not
every historical thread.

Provider account rate limits currently arrive as
`account.rate-limits.updated`, but their payload is untyped and is not exposed
as a durable shell/read projection. Add a small provider-neutral read model to
T3 before showing account quota. Until that exists, display “Unavailable,” not
an inferred or stale percentage.

The desired later contract is conceptually:

```text
ProviderUsageSnapshot
  providerInstanceId
  windows[]
    kind
    usedFraction
    resetsAt
  observedAt
```

Its parser stays at each provider adapter boundary; the companion consumes only
the provider-neutral result.

### 5. Pair once, then use least privilege

Discover the local endpoint from T3’s `server-runtime.json`, but never read its
SQLite database, logs, or secret files. Complete T3’s normal pairing flow once
with only `orchestration:read`, then store the resulting credential in the
macOS Keychain.

The first connected build may accept a pasted pairing URL. The polished flow should
add a small “Connect notch companion” action in T3 Code that opens the
companion’s URL scheme with a one-time, read-only pairing credential. This keeps
authentication explicit and avoids copying T3’s private desktop state.

Use `URLSessionWebSocketTask` with reconnect backoff and resume the shell stream
from its last sequence. Cache only the last non-sensitive projection required
to avoid an empty launch.

### 6. Make stable and nightly compatibility capability-driven

The companion must work with official stable and nightly builds without taking
a source dependency on the local fork. Treat the official Effect RPC wire
contract as an external protocol and implement only the narrow read client we
need in Swift.

```text
Installed T3 Code (stable or nightly)
  └── runtime discovery + read-only authentication
      └── capability/protocol probe
          ├── shell stream available  -> activity UI
          ├── thread detail available -> context usage
          └── field unavailable       -> honest unavailable state
```

Compatibility rules:

- use the server probe and advertised capabilities as truth, never a nightly
  version-number comparison;
- tolerate additive JSON fields and treat optional fields as absent capabilities;
- support only documented read RPCs: `orchestration.subscribeShell` and bounded
  `orchestration.subscribeThread` detail;
- keep fork-only API additions behind explicit capability flags so official
  builds continue to work without them;
- maintain sanitized wire fixtures from the latest official stable and nightly,
  and run both through decoder tests in CI;
- show an incompatible/disconnected state instead of falling back to SQLite,
  Electron storage, or logs.

The current official upstream contract exposes the shell and thread streams and
already marks newer shell fields optional for version skew. That is enough for
v0.1 activity and context usage, but it is not a promise that every future
nightly will remain wire-compatible. The fixture matrix and capability checks
are release gates.

References:

- <https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/orchestration.ts>
- <https://github.com/pingdotgg/t3code/blob/main/docs/internals/overview.md>

### 7. Detect the app by identity, not filename

Ask `NSWorkspace` for bundle identifier `com.t3tools.t3code`, then read
`CFBundleShortVersionString` from that bundle. Do not assume the application is
named “T3 Code (Alpha)” or installed in `/Applications`; Nightly and local builds
may have different names or locations.

When installed, open `t3code://threads/<environmentId>/<threadId>`. When absent,
open <https://t3.codes>. Treat the server handshake and feature availability as
the compatibility authority; use the bundle version only for display and
diagnostics, not brittle semver branching.

The currently installed Nightly confirms bundle identifier
`com.t3tools.t3code` and URL schemes `t3code` and `t3code-dev`. Before release,
the compatibility fixture job must verify those identities against both the
latest official stable and nightly artifacts.

References:

- <https://developer.apple.com/documentation/appkit/nsworkspace>
- <https://developer.apple.com/documentation/foundation/urlsessionwebsockettask>

### 8. Keep the code direct

Start with four focused modules rather than a framework-heavy architecture:

```text
T3NotchApp
├── Domain       activity, usage, presentation state, pure mapping rules
├── T3Client     discovery, pairing, WebSocket stream, compatibility
├── NotchUI      SwiftUI compact/peek/expanded views, glass, fallback, motion
└── Platform     NSPanel, screen geometry, app discovery, Keychain, login item
```

Use a single `@MainActor` observable app model, a single connection actor, and
small pure functions for status priority and geometry. Introduce protocols only
at real boundaries that need substitution in tests: T3 transport, credential
store, installed-app lookup, and screen geometry. Avoid a dependency injection
container, generic repository layer, or duplicated client runtime.

SwiftUI owns presentation state and content. A small, explicit AppKit bridge
owns the long-lived `NSPanel` and exposes only the window operations SwiftUI
cannot express; views must not retain or mutate the panel directly.

## Verified T3 read path

The source audit at commit `5a84614809b6e853b872f9e57ff4b97e9df5df02`
confirmed the official bearer-authenticated snapshot and streaming path:

```text
server-runtime.json                 endpoint discovery only
/.well-known/t3/environment        capability and auth probe
/oauth/token                       explicit one-time pairing exchange
/api/orchestration/shell           reconnect activity snapshot
/api/orchestration/threads/:id     reconnect context snapshot
/api/auth/websocket-ticket         short-lived stream credential
/ws
  orchestration.subscribeShell     incremental activity state
  orchestration.subscribeThread    visible-thread context activity
```

Both snapshot endpoints require `orchestration:read`. The shell contains
session status, latest-turn state, approval/input flags, background liveness,
and plan progress. Per-thread detail contains durable `context-window.updated`
activities with `usedTokens` and optional `maxTokens`. Missing `maxTokens` must
render as unavailable rather than zero percent. Dex bootstraps and recovers with
HTTP snapshots, then consumes T3's JSON Effect RPC stream, acknowledges every
chunk, sends the protocol heartbeat, and resumes shell delivery from the last
snapshot sequence. If the socket is unavailable, the next bounded HTTP refresh
keeps older compatible builds functional while Dex retries the official stream.

Dex must never consume T3's private desktop bootstrap credential. The user
explicitly supplies a one-time pairing credential, Dex requests only
`orchestration:read`, and the resulting bearer session is stored in Keychain.
Dex reads that item once per app launch and keeps it in process memory; API
refreshes must not repeatedly invoke Keychain access.

## Build workflow

Start package-first with SwiftPM because this repository was empty and the
first slice has one executable target plus focused unit tests. Following the
Build macOS Apps plugin workflow, keep one project-local
`script/build_and_run.sh` entrypoint that stops the existing app, builds, stages
a real `dist/Dex.app`, and launches it. `.codex/environments/environment.toml`
adds a single `Run` action pointing to that script. The repository remains
buildable without Codex; the environment file is only a convenient Run button.

Move to an Xcode project when signing, assets, UI tests, or archive settings
make it useful; do not maintain SwiftPM and Xcode project metadata in parallel.

```bash
# Canonical local loop
./script/build_and_run.sh

# Optional verification and diagnostics
./script/build_and_run.sh --verify
./script/build_and_run.sh --expanded
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug

# Underlying package commands remain directly usable
swift build
swift test
swift format lint --recursive Sources Tests Package.swift
```

Signed distribution uses a separate Release archive with Developer ID signing
and notarization credentials supplied only by protected CI. Never put signing
identities or secrets in the project file.

## Delivery steps and status

### Phase 0 — product spike (`in progress`)

- [x] Create the macOS app target and repository baseline.
- [x] Add the plugin-guided `script/build_and_run.sh` and Codex Run action.
- [x] Build a fixture-driven notch panel with compact and expanded states.
- [x] Apply Liquid Glass to the expanded surface on macOS 26.
- [ ] Verify the macOS 14–15 material fallback from the same state model.
- [x] Verify notch geometry on this Mac.
- [ ] Verify the no-notch fallback on an external display.
- [ ] Measure idle CPU, memory, animation frame pacing, and focus behavior.
- [ ] Decide exact compact dimensions and interaction timing from real use.

Verified on 2026-08-13: Swift 6 compilation and four model/geometry tests pass;
the staged accessory app remains running; live display geometry resolves a
185-point camera housing; and the actual compact and expanded panel frames are
top-centered at `281 x 32` and `344 x 218` points after on-device visual
correction. The no-notch display,
macOS 14–15 material appearance, focus/Space behavior, and sustained resource
measurements remain open Phase 0 evidence. A short settled compact-state sample
reported `0.0%` CPU and about `45 MB` RSS after removing perpetual pulse
animation; this is directional only, not the sustained measurement gate.

Exit proof: the app can run for an hour without stealing focus, survives Space
and display changes, and looks physically attached to the camera housing.

### Phase 1 — read-only T3 integration

- [x] Detect the T3 app and installed version through Launch Services.
- [x] Discover the current local server without exposing secrets.
- [x] Implement read-only pairing and Keychain persistence.
- [x] Decode the shell snapshot and incremental stream.
- [ ] Add official stable and nightly compatibility fixtures and capability probes.
- [x] Map T3 shell state into the compact and expanded UI.
- [ ] Deep-link each row back into T3 Code.
- [x] Implement offline, incompatible, and T3-not-installed states.

Exit proof: fixture tests cover every status and a real local T3 session moves a
thread through starting, working, attention, completion, and reconnect without a
stale or lying state.

### Phase 2 — context usage

- [x] Subscribe to detail only for active or visible threads.
- [x] Extract the latest durable context-window snapshot.
- [x] Show used/max percentage when max is known and exact token counts otherwise.
- [x] Bound subscriptions and memory as thread counts grow.

Exit proof: displayed values match the corresponding T3 thread UI across Codex
and Claude sessions, including unknown maximums and compaction.

### Phase 3 — polish and release

- [ ] Accessibility labels, keyboard navigation, Reduce Motion, high contrast.
- [ ] Launch-at-login control and a minimal settings surface.
- [ ] Focused unit tests plus UI smoke tests on notch and non-notch displays.
- [ ] CI for build, test, formatting, and release artifact checks.
- [ ] Code signing, notarization, DMG, privacy statement, contribution guide, and license.
- [ ] Record compact/expanded behavior for the release README.

Exit proof: a clean machine can install, pair, observe live activity, open a
thread, relaunch, reconnect, update displays, and uninstall without manual file
repair.

### Phase 4 — account quota and remote environments

- [ ] Add the typed, durable provider-usage read projection in T3 Code.
- [ ] Capability-negotiate it from the companion.
- [ ] Add multiple saved environments only after the local flow is stable.

## Proof of completion

The product is complete for v0.1 when all of these are demonstrated:

- exact placement using live `NSScreen` geometry on a notched Mac;
- a usable top-center fallback on a non-notched display;
- no Dock icon and no focus theft during normal use;
- correct activity priority for simultaneous threads;
- reconnect/resume without duplicate or stale activity;
- context usage matching T3’s durable projection;
- installed-app version detection and working T3 deep links;
- safe absent-app fallback to the T3 website;
- low, measured idle energy impact;
- signed and notarized artifact installable on a clean Mac.

## Risks and mitigations

- **Menu bar collisions:** start with conservative wing widths and collapse when
  available auxiliary space is insufficient.
- **Full-screen and Stage Manager differences:** exercise all Spaces behaviors
  in the product spike before building the data layer.
- **Private T3 coupling:** capability-negotiate RPC contracts, test official
  stable and nightly fixtures, and never read the database directly.
- **Unclear account quota:** keep it visibly unavailable until the server owns a
  typed durable answer.
- **Animation energy cost:** animate only geometry/opacity, stop all repeating
  animation when settled, and profile rather than assume.
- **Open-source signing:** keep builds reproducible without signing; inject
  signing and notarization only in protected release CI.

## Open decisions

These should be answered by the Phase 0 prototype rather than by speculation:

1. Should a new approval/input event briefly expand the panel, or only light the wings?
2. Should the compact left wing prioritize context usage or active-thread count?
3. Should the expanded panel show three rows or five before scrolling?
4. Should the fallback island appear on every display or only the active display?

## Next action

Build Phase 0 with fixture data only. The first implementation should prove the
window, geometry, interaction, and visual feel before any authentication or T3
transport code is added.
