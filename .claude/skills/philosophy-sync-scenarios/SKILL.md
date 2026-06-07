---
name: philosophy-sync-scenarios
description: Propagates changes from docs/ios-app-system-design-philosophy.md into all docs/SystemDesign/ files, and fixes any standing naming/layer/content violations found during the same pass. Proposes all changes per app before writing, then regenerates HTML for any changed app.
user-invocable: true
---

The generic architecture doc was updated. Propagate changes into all system design docs, fix standing violations, and regenerate HTML for changed docs.

This skill proposes changes per app before writing — it never silently overwrites.

**App → file mapping:**

| App | .md | HTML deck |
|---|---|---|
| MusicApp | `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md` | `docs/deck/SystemDesign/MusicAppSystemDesign.html` |
| ChatApp | `docs/SystemDesign/ChatApp/ChatAppSystemDesign.md` | `docs/deck/SystemDesign/ChatAppSystemDesign.html` |
| CoreKit | `docs/SystemDesign/CoreKit/CoreKitSystemDesign.md` | `docs/deck/SystemDesign/CoreKitSystemDesign.html` |
| MelodifyDesignSystem | `docs/SystemDesign/MelodifyDesignSystem/MelodifyDesignSystemSystemDesign.md` | `docs/deck/SystemDesign/MelodifyDesignSystemSystemDesign.html` |

## Phase 1 — Analyze (parallel)

Spawn one `philosophy-scenario-sync-worker` **per app in parallel** — all 4 simultaneously. Each worker receives:
> **Mode: analyze.** Scenario .md: [path]. Philosophy doc: `docs/ios-app-system-design-philosophy.md`.
> Run Pass A (delta propagation from philosophy doc changes) + Pass B (standing-rules audit: 5-layer completeness, naming conventions, redundant generic content, SDK wrapper compliance, "same as generic" accuracy, layer dependency rule). Return a merged per-app proposal.

Collect all proposals. Present to the user:
1. A brief summary of what changed in the philosophy doc (derived from the proposals' Pass A items)
2. The per-app proposals

Ask: **"Apply all? Or select specific apps?"**

## Phase 2 — Apply (parallel)

For each approved app, spawn `philosophy-scenario-sync-worker` **in parallel** with:
> **Mode: apply.** Scenario .md: [path]. Approved changes: [the approved proposal items for this app].

After all system design `.md` files are written:

1. **Regenerate the philosophy HTML** — spawn `philosophy-scenario-html-worker` with:
   > **Mode: generate.** Scenario .md: `docs/ios-app-system-design-philosophy.md`. HTML deck path: `docs/deck/ios-app-system-design-philosophy.html`. Style reference: `docs/deck/SystemDesign/MusicAppSystemDesign.html`.
   Always regenerate this file, even if the philosophy doc itself wasn't changed.

2. **Regenerate system design HTMLs** — for each app whose `.md` was updated, spawn `philosophy-scenario-html-worker` **in parallel** with:
   > **Mode: generate.** Scenario .md: [path]. HTML deck path: [path]. Style reference: `docs/deck/SystemDesign/MusicAppSystemDesign.html`. Before generating, read `docs/conventions/scenario-conventions.md` — Section 9 defines the required `#delta` section structure (`.delta-grid` / `.delta-card` / `.delta-topic` / `.delta-decision` / `.delta-rationale`). Do not use `.rule` or `.callout` classes for the delta section.

## Report

Collect all results and show the final report:

```
## Sync Complete

### Generic doc changes
<summary of Pass A items across scenarios>

### Apps updated
| App | .md updated | HTML regenerated | Delta changes | Standing fixes |
|---|---|---|---|---|

### Skipped apps
<list any that were skipped and why>

### Remaining manual review items
<any B6 layer dependency violations flagged but not auto-fixed due to ambiguity>
```
