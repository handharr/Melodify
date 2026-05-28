---
name: philosophy-sync-recall-html
description: Syncs docs/deck/system-design-recall.html with the current state of all docs/scenarios/*.md files and their docs/deck/*.html counterparts. Detects flow renames, component name drift, endpoint changes, and missing/new scenario cards.
user-invocable: true
---

Sync the recall pages with the current scenario docs.

Two files are always co-maintained:
- `docs/deck/system-design-recall.html` — table layout (source of truth for structure)
- `docs/deck/system-design-recall-diagram.html` — same content + SVG connection arcs

The assembler writes both. Chip `id=""` attributes and the `PATHS` array in the diagram file are governed by Section 7 of `docs/conventions/scenario-conventions.md`.

## Parse Arguments

**Accepted names** (case-insensitive, hyphens optional):
`uber-eats`, `messenger`, `music-streaming`, `instagram-news-feed` (or `instagram`), `hotel-booking` (or `hotel`), `story-viewer` (or `story`)

| Invocation | Mode |
|---|---|
| No argument | All 6 cards |
| One or more names | Only those cards |

In single/multi mode, cards not in the target set are never read, diffed, or written.

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

**All-scenarios:** Ask: **"Apply all updates? Or specify scenarios."**
**Single/multi:** Ask: **"Apply updates to `<name(s)>`?"**

## Phase 2 — Assemble

After confirmation, spawn `philosophy-recall-card-worker` once in `assemble` mode:
> **Mode: assemble.**
> Approved scenarios: [list of confirmed scenario names]
> New card HTML per scenario: [paste the card HTML blocks returned by the diff workers for approved scenarios]
> The recall file must be written with cards in order: Uber Eats, Messenger, Music Streaming, Instagram News Feed, Hotel Booking, Story Viewer. Unapproved cards must be copied verbatim.

## Report

Relay the worker's final report:

```
## Sync Complete — system-design-recall.html
Mode: all-scenarios | single: <name> | multi: <name, name>

### Updated cards
| Scenario | Flows | Changes |
|---|---|---|

### In-scope but already in sync
<list>

### Out of scope (not checked)
<list> — skipped per mode.
(omit in all-scenarios mode)
```
