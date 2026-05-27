---
name: philosophy-sync-scenario-html
description: Regenerates the HTML deck(s) for scenario doc(s) from their .md source. Pass a scenario name, .md path, or .html path to sync one file; pass multiple to sync a subset; pass nothing to sync all 6.
user-invocable: true
---

Regenerate HTML deck(s) from their `.md` source to fix out-of-sync content.

## Parse Arguments

**Accepted name aliases** (case-insensitive, hyphens optional):
`uber-eats`, `messenger`, `music-streaming`, `instagram-news-feed` (or `instagram`), `hotel-booking` (or `hotel`), `story-viewer` (or `story`)

Arguments may also be `.md` or `.html` paths — resolve them to a scenario name using the filename.

| Invocation | Mode |
|---|---|
| No argument | All 6 scenarios |
| One or more names / paths | Only those scenarios |

## Phase 1 — Diff

Spawn one `philosophy-scenario-html-worker` **per target scenario in parallel** with:
> **Mode: diff.** Scenario .md: [path]. HTML deck: [path]. Style reference: `docs/deck/scenarios/music-streaming-system-design.html`.

Collect all diff results. Show a summary table:

```
| Scenario | HTML exists? | Sections changed | Action |
|---|---|---|---|
```

**All-scenarios:** Ask: **"Proceed with regenerating the marked files?"**
**Single/multi:** Ask: **"Regenerate `<name(s)>`?"**

If all targets are already in sync, stop here.

## Phase 2 — Generate

For each approved scenario, spawn `philosophy-scenario-html-worker` **in parallel** with:
> **Mode: generate.** Scenario .md: [path]. HTML deck path: [current path]. Style reference: `docs/deck/scenarios/music-streaming-system-design.html`.

## Report

Collect all results. Show final summary:

```
## Sync Complete

| Scenario | Action | Sections updated |
|---|---|---|
| uber-eats | ✅ Regenerated | Delta table, Data Flow |
| messenger | ⏭️ Skipped | Already in sync |
```

Add at the end if single/multi mode:
> To sync all HTML decks at once: `/philosophy-sync-scenario-html` (no argument)
