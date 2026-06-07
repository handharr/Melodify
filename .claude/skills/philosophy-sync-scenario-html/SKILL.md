---
name: philosophy-sync-scenario-html
description: Regenerates the HTML deck(s) for system design doc(s) from their .md source. Pass an app name, .md path, or .html path to sync one file; pass multiple to sync a subset; pass nothing to sync all 4.
user-invocable: true
---

Regenerate HTML deck(s) from their `.md` source to fix out-of-sync content.

## Parse Arguments

**Accepted name aliases** (case-insensitive):
`music-app` (or `music`), `chat-app` (or `chat`), `core-kit` (or `core`), `melodify-design-system` (or `mds`)

Arguments may also be `.md` or `.html` paths — resolve them to an app name using the filename.

**App → file mapping:**

| App | .md | HTML deck |
|---|---|---|
| music-app | `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md` | `docs/deck/SystemDesign/MusicAppSystemDesign.html` |
| chat-app | `docs/SystemDesign/ChatApp/ChatAppSystemDesign.md` | `docs/deck/SystemDesign/ChatAppSystemDesign.html` |
| core-kit | `docs/SystemDesign/CoreKit/CoreKitSystemDesign.md` | `docs/deck/SystemDesign/CoreKitSystemDesign.html` |
| melodify-design-system | `docs/SystemDesign/MelodifyDesignSystem/MelodifyDesignSystemSystemDesign.md` | `docs/deck/SystemDesign/MelodifyDesignSystemSystemDesign.html` |

| Invocation | Mode |
|---|---|
| No argument | All 4 apps |
| One or more names / paths | Only those apps |

## Phase 1 — Diff

Spawn one `philosophy-scenario-html-worker` **per target app in parallel** with:
> **Mode: diff.** Scenario .md: [path]. HTML deck: [path]. Style reference: `docs/deck/SystemDesign/MusicAppSystemDesign.html`.

Collect all diff results. Show a summary table:

```
| App | HTML exists? | Sections changed | Action |
|---|---|---|---|
```

**All-apps:** Ask: **"Proceed with regenerating the marked files?"**
**Single/multi:** Ask: **"Regenerate `<name(s)>`?"**

If all targets are already in sync, stop here.

## Phase 2 — Generate

For each approved app, spawn `philosophy-scenario-html-worker` **in parallel** with:
> **Mode: generate.** Scenario .md: [path]. HTML deck path: [current path]. Style reference: `docs/deck/SystemDesign/MusicAppSystemDesign.html`.

## Report

Collect all results. Show final summary:

```
## Sync Complete

| App | Action | Sections updated |
|---|---|---|
| music-app | ✅ Regenerated | Delta table, Data Flow |
| chat-app | ⏭️ Skipped | Already in sync |
```

Add at the end if single/multi mode:
> To sync all HTML decks at once: `/philosophy-sync-scenario-html` (no argument)
