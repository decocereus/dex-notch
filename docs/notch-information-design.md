# T3 Notch Information Design

Status: active product direction, revised 2026-08-17

Source baseline: T3 Code `5a84614809b6e853b872f9e57ff4b97e9df5df02` and the running Dex UI shown in `Screenshot 2026-08-14 at 1.48.45 PM.png`.

## 2026-08-17 redesign thesis

**Visual thesis:** Dex is a compact flight strip for live agent work: matte
black, one quiet cyan/attention accent, and equal dense rows. It is not a task
history, card dashboard, or celebration surface.

**Content plan:** the compact line names the live-work count and explicitly
labels the Codex seven-day allowance. One small pace strip explains whether
consumption is ahead of or behind the ideal weekly burn and when the allowance
resets. The list contains only unresolved work, with task title followed by
repository, branch, and worktree identity. Ordinary context percentages are
hidden; only pressure near the context limit earns space.

**Interaction thesis:** the revealed surface is a stable inspection strip.
Live rows update in place while open, settled rows disappear, and no row gets
arbitrary “hero card” treatment. Expansion uses only the existing short morph
and fade, with the established reduced-motion behavior.

The product now has one job: **show the work that is still in flight, and make
the capacity required to keep doing it understandable.**

## Product promise

Know whether T3 work is moving and check its important state without switching
apps; forget that Dex exists when not checking it.

## Decision

The notch should be a **quiet, optional ambient entry point**, not a permanently
visible activity dashboard. The physical notch can remain the interaction
anchor without requiring persistent text, counters, rings, or animation around
it.

When intentionally revealed, it should answer, in this order:

1. Does anything need me?
2. Did anything fail?
3. What is still moving, and where?
4. Is a thread approaching a context limit?

The current design answers only “how many threads are active?” and “what is the
highest context percentage?”. Those measurements can be useful during a check,
but they do not justify occupying the user's peripheral vision all day.

## Does this need to be a notch app?

It does not need to be an always-rendered notch widget. It does need a fast,
low-friction place to check T3 without opening T3 Code.

On a MacBook with a camera housing, the notch is a good spatial anchor because
it occupies otherwise unusable space. On a display without one, Dex should
fall back to a quiet menu-bar entry rather than drawing a fake notch. If Dex
cannot disappear into the hardware while resting, the notch treatment has not
earned its place.

## What “usage” means

There are two different products hiding behind that word:

- **Thread context usage** is the percentage shown today. T3 exposes used and
  maximum context tokens per thread.
- **Provider/account usage** means plan limits, quota, reset time, or spend. T3's
  current orchestration contract does not expose this as a durable read model,
  but the local Codex app-server does expose the Codex rate-limit windows.

Dex must label the first one `context`, not imply it is account quota. The
weekly Codex allowance should be labeled `weekly usage` or `weekly remaining`.

## Supported Codex usage source

The installed `codex-cli 0.146.0` exposes the documented Codex app-server
JSON-RPC interface. After its normal initialization handshake, Dex can call:

```text
codex app-server
  initialize
  account/rateLimits/read
    rateLimitsByLimitId
      primary.usedPercent
      primary.windowDurationMins
      primary.resetsAt
```

A live read on 2026-08-14 returned populated seven-day windows (`10080`
minutes) for the main Codex allowance and a separate model-specific allowance.
This proves the weekly limit is available locally without scraping terminal
text or reading Codex authentication files directly.

The endpoint uses the user's existing ChatGPT-backed Codex login. API-key-only
authentication does not provide ChatGPT subscription rate limits. The CLI marks
app-server as experimental, so Dex must feature-detect the method and degrade
quietly after incompatible Codex upgrades.

Do not automate the interactive `/status` or `/usage weekly` screens. They are
useful for a person in the terminal, but parsing their rendered output would be
brittle and unnecessary.

## What is wrong with the current screen

- The large first card gives arbitrary prominence to one working thread even when nothing about it is more urgent.
- Completed rows turn a live-work companion into a tiny task history.
- A bare `47% left` does not name the allowance window, reset, or burn pace.
- Project title alone does not disambiguate related repositories and worktrees.
- Repeated `Working` labels consume space without explaining what the agent is doing or how long it has been doing it.
- Context usage is visually dominant at ordinary values such as 18–48%, even though it does not require action.
- Approval, input, plan-ready, failure, and completion states do not dominate the hierarchy strongly enough.
- Secondary rows lose the project name and current plan step, which are usually more useful than another percentage.
- The expanded panel appears visually substantial enough to become a distraction
  if hover alone can reveal it accidentally.

## What T3 Code gives us

### Available in Dex today

| Signal | T3 source | Glance value | Recommended treatment |
| --- | --- | --- | --- |
| Thread and project title | Shell snapshot | High | Always identify the leading thread; show project as secondary text. |
| Pending approval | `hasPendingApprovals` | Highest | Promote to the compact notch and first expanded row. |
| Pending user input | `hasPendingUserInput` | Highest | Promote to the compact notch and first expanded row. |
| Actionable plan | `hasActionableProposedPlan` | Highest when the turn is settled | Present as `Plan ready`, not generic input. |
| Working or starting | Session status | Medium | Use one quiet aggregate at peek level; show details only after expansion. |
| Background work | `backgroundLiveness: working` | Medium | Treat as working after the foreground turn settles. |
| Monitoring | `backgroundLiveness: monitoring` | Low | Keep visible but quiet; it is not equivalent to active execution. |
| Failure | Latest-turn/session error state | Highest | Promote above working and monitoring; offer the T3 deep link. |
| Current plan step | `planProgress.step` | Medium | Use as optional second-line detail in the expanded view. |
| Context used and maximum tokens | `context-window.updated` activity | Conditional | Show only as a secondary warning when usage is high. |
| Latest update time | Thread timestamp | Medium | Use for stable sorting and freshness; do not print a full timestamp. |

### Available from the same shell contract with a small decoder expansion

| Signal | Why it helps | Treatment |
| --- | --- | --- |
| Plan steps completed and total | Gives concrete progress without pretending to know an ETA | Keep optional in the expanded view; label it as steps, not percent complete. |
| Turn requested/started/completed times | Distinguishes a fresh task from one that may be stuck | Keep optional in the expanded view rather than adding a continuously changing resting metric. |
| Session `lastError` | Explains a failure | Use a short, sanitized summary only in the expanded view. Never show a raw payload in the notch. |
| Model/provider | Useful when a thread differs from the normal setup | Hide by default; reveal only when exceptional or in a detail affordance. |
| Repository identity | Disambiguates projects with similar titles | Show the repository display name, falling back to project title. |
| Branch/worktree | Identifies the exact checkout doing the work | Show compact path components after repository identity. |
| Pinned, snoozed, archived, and settled state | Useful for filtering | Do not display; use it to decide which threads belong in the list. |

### Available only from a thread-detail subscription

T3 also exposes messages, activity summaries, proposed plans, and
checkpoint/file-change summaries. These are useful after the user opens T3,
but they are too verbose, potentially sensitive, and too unstable for a
glanceable notch. Dex should continue subscribing only to the few visible
threads needed for context usage rather than mirroring the whole conversation.

### Not available, or unsafe to infer

- A trustworthy completion percentage or ETA. Plan-step counts are not an estimate of remaining effort.
- A pull request identifier in the orchestration shell. PR metadata requires a
  separate change-request projection; never infer a PR number from a branch.
- Provider account quota, reset time, or cost from the current T3 orchestration
  shell. Codex weekly rate-limit windows are available separately through
  `codex app-server`.
- A quality or success prediction.
- System CPU or memory use as part of the T3 thread contract.

Do not manufacture these values from activity volume or elapsed time.

## Information priority

Use one shared priority ladder for the resting signal, revealed summary,
expanded ordering, color, and accessibility:

1. Approval required
2. User input required
3. Plan ready
4. Failed
5. Starting or working
6. Background working
7. Monitoring
8. Quiet/ready

Within the same state, keep the order stable while the notch is open. Reorder only after it closes, except when a new approval, input request, or failure arrives.

T3’s own mobile activity surface already uses the same broad rule: human
blockers first, then failures, live work, and finished work. Its web sidebar
also makes session failure outrank lingering background liveness. Dex should
match that behavior.

## Three levels of disclosure

### 1. Rest

Rest is the state the user sees almost all day. It should blend into the camera
housing:

- No panel background, border, glow, text, number, or usage ring.
- No pulse or continuously changing value.
- Show nothing when T3 is idle or everything has completed normally.
- When work is live, allow one small, static, low-contrast activity mark.
- When the user is needed or work failed, that same mark may become clearer and
  change state. It should not expand, bounce, or notify by itself.
- Only the highest-priority state is represented; never accumulate badges
  around the hardware.

The mark is a hint, not the information itself. Its hover/accessibility label
must state the meaning in words.

### 2. Peek

After a short intentional hover, reveal only the compact wings. Do not open the
thread panel yet.

- Show one aggregate, such as `3 working`, `1 needs you`, or `1 failed`.
- Use the other wing for the primary goal: `71% weekly left`. Thread context or
  the leading project can replace it only when more urgent.
- Reveal after a brief dwell so the UI does not flash when the pointer crosses
  the menu bar.
- Fade out promptly when the pointer leaves.
- Do not animate counters as live events arrive; update the next time the peek
  appears.

### 3. Inspect

Open the thread list only after an intentional click. Attention and failure
must never auto-expand it.

- Show at most four unresolved threads. Never fill spare space with settled or
  completed history.
- Keep each row to title, repository/branch/worktree, and a plain state such as `Working`,
  `Waiting for input`, or `Failed`.
- Add a current plan step, elapsed time, or context value only when it helps
  distinguish the row; never show all three by default.
- Use equal-height rows. A larger action row is justified only when the user
  needs to approve, answer, or inspect a failure.
- Preserve the order while open so live updates do not make rows jump.

## Context visibility

Initial context policy:

- Below 70%: hidden.
- 70–84%: muted in the expanded row only.
- 85% and above: a warning in the expanded state. Rest may change its
  single status mark but should not show a number.

These are product thresholds, not T3 contract semantics. They should be tuned after observing real thread behavior.

## Expanded notch

The expanded view is the `Inspect` level: a small inbox ordered by consequence.
It exists for deliberate check-ins, so it can carry more information than the
resting notch without becoming ambient noise.

### Header

- Lead with the attention count when non-zero.
- Otherwise show the working count or a quiet connected state.
- Keep connection health and environment available but visually secondary.
- Lead with weekly account usage in a quiet secondary position. Show thread
  context only when it is in the warning band.

### Rows

- Use equal-height rows by default. Promote a row into a larger action card only for approval, input, plan-ready, or failure.
- First line: state glyph, thread title, and plain status.
- Second line: repository, branch, and shortened worktree path. Context appears only when
  relevant.
- Clicking a row should open the exact thread once T3's desktop app honors an
  external thread route. Until then, Dex may activate T3 Code but must not
  imply that it navigated to the selected thread.
- Show at most four threads, ordered by the shared priority ladder.
- If more urgent threads exist than fit, show `+N more needing attention` rather than silently hiding them.

### Visual semantics

- Amber: approval.
- Violet: input or plan ready.
- Red: failure.
- Cyan: live work.
- Muted blue/gray: monitoring.
- Green is not used in the live-work list because completed history is absent.

Every revealed state also needs an icon and text label; color alone is not
sufficient. Rest uses no motion, including when Reduce Motion is off.

## Recommended first version

Build the focused version around three disclosure levels:

1. Rest: no UI when quiet; at most one static state mark otherwise.
2. Peek: one thread aggregate plus weekly account allowance remaining.
3. Inspect: up to four unresolved thread rows with task and checkout identity,
   plus one weekly pace strip.

Defer plan-step counts, elapsed timers, model names, raw activity logs, message
previews, file-change summaries, and PR display until a truthful PR projection
is available.
Reintroduce one only after observing that users need it to make the next
decision.

## Contract corrections needed before UI work

- Decode session error state and make failure outrank background work, matching T3’s web status logic.
- Represent `Plan ready` as its own user-facing state instead of collapsing it into generic input.
- Derive one presentation model that both compact and expanded views consume, so their counts, ordering, labels, and accessibility never disagree.
- Separate rest, peek, and inspect state so hover cannot accidentally open the
  full panel.

Plan progress and elapsed-time decoding are explicitly deferred until the
simpler hierarchy is proven insufficient.

## Usage integration recommendation

For the first version, add a small read-only Codex usage client in Dex that:

1. Locates a compatible `codex` executable explicitly rather than assuming a
   GUI app inherited the user's shell `PATH`.
2. Starts `codex app-server`, performs the initialize handshake, and calls
   `account/rateLimits/read`.
3. Selects the `codex` bucket by `limitId`, then checks both `primary` and
   `secondary` for `windowDurationMins == 10080`. It must not assume window or
   array order or confuse a model-specific bucket with the main allowance.
4. Converts `usedPercent` to remaining percentage and preserves `resetsAt`.
5. Caches the last good result, refreshes infrequently, and shows no resting
   error chrome when Codex is absent, signed out, or incompatible.
6. Terminates the helper after the read unless measurement proves that a
   persistent process is cheaper and reliable.

Longer term, T3 can expose a provider-usage read projection from the Codex
app-server it already owns. T3 already generates typed protocol support for
`account/rateLimits/read`; adding that projection would let Dex return to a
single T3 data source. It is cleaner, but it should not block proving the Dex
experience first.

## Evidence

### Live verification, 2026-08-17

The rebuilt, development-signed app was inspected against the paired local T3
Code and current Codex account. Compact rendered `2 live` and `Wk 46%` without
clipping. Expanded rendered only the two unresolved threads, with repository,
branch, and shortened worktree identity, plus `3% in reserve` and `Resets in 2
days`. The panel contracted to the two live rows instead of leaving room for
settled history. The current shell feed supplied no pull-request identity, so
none was displayed.

- [T3 orchestration shell contract](https://github.com/decocereus/t3code/blob/5a84614809b6e853b872f9e57ff4b97e9df5df02/packages/contracts/src/orchestration.ts#L419-L527)
- [T3 web sidebar status resolution](https://github.com/decocereus/t3code/blob/5a84614809b6e853b872f9e57ff4b97e9df5df02/apps/web/src/components/Sidebar.logic.ts#L437-L481)
- [T3 mobile attention-first activity ordering](https://github.com/decocereus/t3code/blob/5a84614809b6e853b872f9e57ff4b97e9df5df02/apps/mobile/src/widgets/AgentActivity.tsx#L95-L147)
- [Official Codex App Server documentation](https://learn.chatgpt.com/docs/app-server)
- [CodexBar Codex usage source](https://github.com/steipete/CodexBar/blob/main/docs/codex.md)
- [CodexBar usage pace model](https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/UsagePace.swift)
- [Codex usage dashboard](https://chatgpt.com/codex/settings/usage)
- Dex’s current decoding and presentation: `Sources/Dex/T3Client/T3DTO.swift`, `Sources/Dex/T3Client/T3ConnectionController.swift`, `Sources/Dex/Views/CompactNotchView.swift`, and `Sources/Dex/Views/ExpandedThreadsView.swift`.
