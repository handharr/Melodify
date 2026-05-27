---
name: philosophy-sync-scenarios
description: Propagates changes from docs/ios-app-system-design-philosophy.md into all docs/scenarios/ files, and fixes any standing naming/layer/content violations found during the same pass. Proposes all changes per scenario before writing, then regenerates HTML for any changed scenario.
user-invocable: true
---

The generic architecture doc was updated. Propagate changes into all scenario docs, fix standing violations, and regenerate HTML for changed scenarios.

This skill proposes changes per scenario before writing — it never silently overwrites.

## Phase 1 — Analyze (parallel)

Spawn one `philosophy-scenario-sync-worker` **per scenario in parallel** — all 6 simultaneously. Each worker receives:
> **Mode: analyze.** Scenario .md: [path]. Philosophy doc: `docs/ios-app-system-design-philosophy.md`.
> Run Pass A (delta propagation from philosophy doc changes) + Pass B (standing-rules audit: 5-layer completeness, naming conventions, redundant generic content, SDK wrapper compliance, "same as generic" accuracy, layer dependency rule). Return a merged per-scenario proposal.

Collect all proposals. Present to the user:
1. A brief summary of what changed in the philosophy doc (derived from the proposals' Pass A items)
2. The per-scenario proposals

Ask: **"Apply all? Or select specific scenarios?"**

## Phase 2 — Apply (parallel)

For each approved scenario, spawn `philosophy-scenario-sync-worker` **in parallel** with:
> **Mode: apply.** Scenario .md: [path]. Approved changes: [the approved proposal items for this scenario].

After all scenario `.md` files are written:

1. **Regenerate the philosophy HTML** — spawn `philosophy-scenario-html-worker` with:
   > **Mode: generate.** Scenario .md: `docs/ios-app-system-design-philosophy.md`. HTML deck path: `docs/deck/ios-app-system-design-philosophy.html`. Style reference: `docs/deck/scenarios/music-streaming-system-design.html`.
   Always regenerate this file, even if the philosophy doc itself wasn't changed.

2. **Regenerate scenario HTMLs** — for each scenario whose `.md` was updated, spawn `philosophy-scenario-html-worker` **in parallel** with:
   > **Mode: generate.** Scenario .md: [path]. HTML deck path: [path]. Style reference: `docs/deck/scenarios/music-streaming-system-design.html`.

## Report

Collect all results and show the final report:

```
## Sync Complete

### Generic doc changes
<summary of Pass A items across scenarios>

### Scenarios updated
| Scenario | .md updated | HTML regenerated | Delta changes | Standing fixes |
|---|---|---|---|---|

### Skipped scenarios
<list any that were skipped and why>

### Remaining manual review items
<any B6 layer dependency violations flagged but not auto-fixed due to ambiguity>
```
