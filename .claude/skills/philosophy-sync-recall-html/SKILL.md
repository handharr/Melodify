---
name: philosophy-sync-recall-html
description: Syncs docs/deck/system-design-recall.html with the current state of all docs/SystemDesign/**/*.md files and their docs/deck/SystemDesign/*.html counterparts. Detects flow renames, component name drift, endpoint changes, and missing/new app cards.
user-invocable: true
---

Sync the recall page with the current system design docs.

The recall file (`docs/deck/system-design-recall.html`) includes SVG bezier arcs between chips. Chip `id=""` attributes and the `PATHS` connection graph are governed by Section 7 of `docs/conventions/scenario-conventions.md`.

## Parse Arguments

**Accepted names** (case-insensitive):
`music-app` (or `music`), `chat-app` (or `chat`), `core-kit` (or `core`), `melodify-design-system` (or `mds`)

| Invocation | Mode |
|---|---|
| No argument | All 4 cards |
| One or more names | Only those cards |

In single/multi mode, cards not in the target set are never read, diffed, or written.

**App → file mapping:**

| App | .md | HTML deck |
|---|---|---|
| music-app | `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md` | `docs/deck/SystemDesign/MusicAppSystemDesign.html` |
| chat-app | `docs/SystemDesign/ChatApp/ChatAppSystemDesign.md` | `docs/deck/SystemDesign/ChatAppSystemDesign.html` |
| core-kit | `docs/SystemDesign/CoreKit/CoreKitSystemDesign.md` | `docs/deck/SystemDesign/CoreKitSystemDesign.html` |
| melodify-design-system | `docs/SystemDesign/MelodifyDesignSystem/MelodifyDesignSystemSystemDesign.md` | `docs/deck/SystemDesign/MelodifyDesignSystemSystemDesign.html` |

## Phase 1 — Diff (parallel)

Spawn one `philosophy-recall-card-worker` **per target scenario in parallel** — each in `diff` mode:
> **Mode: diff.** Scenario: [name]. Scenario .md: [path]. HTML deck: [path].

Each worker returns: drift findings + the new card HTML block.

Collect all results. Show the drift summary table:

```
| Scenario | Flows | Components | Endpoints | Tag | Overall |
|---|---|---|---|---|---|
```

If all in-scope scenarios are in sync, stop here.

**All-apps:** Ask: **"Apply all updates? Or specify apps."**
**Single/multi:** Ask: **"Apply updates to `<name(s)>`?"**

## Phase 2 — Assemble

After confirmation, spawn `philosophy-recall-card-worker` once in `assemble` mode:
> **Mode: assemble.**
> Approved apps: [list of confirmed app names]
> New card HTML per app: [paste the card HTML blocks returned by the diff workers for approved apps]
> The recall file must be written with cards in order: MusicApp, ChatApp, CoreKit, MelodifyDesignSystem. Unapproved cards must be copied verbatim.

## Report

Relay the worker's final report:

```
## Sync Complete — system-design-recall.html
Mode: all-apps | single: <name> | multi: <name, name>

### Updated cards
| App | Flows | Changes |
|---|---|---|

### In-scope but already in sync
<list>

### Out of scope (not checked)
<list> — skipped per mode.
(omit in all-apps mode)
```
