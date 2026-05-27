---
name: philosophy-sync-scenario-html
description: Regenerates the HTML deck(s) for scenario doc(s) from their .md source. Pass a scenario name, .md path, or .html path to sync one file; pass multiple to sync a subset; pass nothing to sync all 6.
user-invocable: true
---

A scenario `.md` file was updated and its HTML deck at `docs/deck/` is now out of sync. Your job is to regenerate the HTML to match the current `.md` content exactly.

---

## Inputs

**Optional:** a scenario identifier — name, `.md` path, or `.html` path. Accepts one or more.

| Invocation | Behaviour |
|---|---|
| `/philosophy-sync-scenario-html` | **All-scenarios mode** — regenerates all 6 HTML decks |
| `/philosophy-sync-scenario-html uber-eats` | **Single-scenario mode** — only that deck is synced |
| `/philosophy-sync-scenario-html uber-eats messenger` | **Multi-scenario mode** — only those decks are synced |
| `/philosophy-sync-scenario-html docs/scenarios/ios-uber-eats-system-design.md` | Same as single — resolves from `.md` path |
| `/philosophy-sync-scenario-html docs/deck/scenarios/uber-eats-system-design.html` | Same as single — resolves from `.html` path |

**Accepted name aliases** (case-insensitive, hyphens optional):
`uber-eats`, `messenger`, `music-streaming`, `instagram-news-feed` (or `instagram`), `hotel-booking` (or `hotel`), `story-viewer` (or `story`).

**Scenario → file mapping:**

| Name | Source .md | HTML deck |
|---|---|---|
| uber-eats | `docs/scenarios/ios-uber-eats-system-design.md` | `docs/deck/scenarios/uber-eats-system-design.html` |
| messenger | `docs/scenarios/ios-messenger-system-design.md` | `docs/deck/scenarios/messenger-system-design.html` |
| music-streaming | `docs/scenarios/ios-music-streaming-system-design.md` | `docs/deck/scenarios/music-streaming-system-design.html` |
| instagram-news-feed | `docs/scenarios/ios-instagram-news-feed-system-design.md` | `docs/deck/scenarios/instagram-news-feed-system-design.html` |
| hotel-booking | `docs/scenarios/ios-hotel-booking-system-design.md` | `docs/deck/scenarios/hotel-booking-system-design.html` |
| story-viewer | `docs/scenarios/ios-story-viewer-system-design.md` | `docs/deck/scenarios/story-viewer-system-design.html` |

**Filename derivation rule** (for paths or names not in the table above):
strip the `ios-` prefix from the `.md` filename and change the extension to `.html`:
- `ios-ride-sharing-system-design.md` → `ride-sharing-system-design.html`

---

## Step 1 — Read source files

**All-scenarios mode:** read every `.md` in `docs/scenarios/` and every corresponding HTML deck. Also read `docs/deck/scenarios/music-streaming-system-design.html` as the CSS/style reference.

**Single/multi-scenario mode:** read only:
1. The `.md` file(s) for the target scenario(s)
2. The existing HTML deck(s) at `docs/deck/scenarios/<scenario-name>.html` — to diff against; note if a deck doesn't exist yet (full creation)
3. `docs/deck/scenarios/music-streaming-system-design.html` — CSS/style reference (always required)

Skip reading all other scenario files not in the target set.

---

## Step 2 — Identify what changed

**Per target scenario:** compare the `.md` content against its existing HTML section by section. List the sections that differ — this tells the user exactly what will be regenerated.

If the HTML does not exist yet, note that this is a **full creation**, not an update.

**All-scenarios mode:** run this comparison for every scenario and produce a summary table before proceeding:

```
| Scenario | HTML exists? | Sections changed | Action |
|---|---|---|---|
| uber-eats | ✅ | Delta table, Data Flow | Regenerate |
| messenger | ✅ | None | Skip |
| music-streaming | ✅ | None | Skip |
| instagram-news-feed | ❌ | — | Full creation |
| hotel-booking | ✅ | Architecture | Regenerate |
| story-viewer | ✅ | None | Skip |
```

Ask the user: **"Proceed with regenerating the marked files?"** before writing anything.

**Single/multi-scenario mode:** show the section diff for the target(s) only, then ask: **"Regenerate `<name(s)>`?"**

---

## Step 3 — Regenerate the HTML

For each approved target, produce the full HTML file. Rules:

### CSS

Copy the `<style>` block verbatim from `docs/deck/scenarios/music-streaming-system-design.html`. Never modify or abbreviate it.

### Component classes

| Class | Use for |
|---|---|
| `.stack` + `.stack-row` | Layer breakdowns, ordered steps |
| `.callout` | Blue — "why" decisions, trade-off explanations |
| `.rule` | Green — rules, principles, confirmed patterns |
| `.warn` | Orange — gotchas, common mistakes |
| `.table-wrap` + `table` | Comparison tables |
| `pre` + `code` | Code blocks |
| `.toc` | Table of contents — `#delta` must be first entry |
| `nav` | Breadcrumb — always links back to `index.html` |
| `.bottom-nav` | Fixed bottom nav — left: `← Home`, right: empty or adjacent deck |

### Syntax highlighting inside `<pre><code>`

| Span class | Use for |
|---|---|
| `.kw` | Keywords: `struct`, `func`, `let`, `class`, `enum`, `case` |
| `.ty` | Type names: `TrackRepository`, `FetchPolicy`, `URL` |
| `.st` | String values: `"HLS"`, `file://` |
| `.cm` | Comments |
| `.nm` | Method and property names |
| `.gr` | HTTP verbs: `GET`, `POST`, `PUT` |

### Section mapping (.md → HTML)

Every `##` heading in the `.md` becomes a `<section id="...">` with an `<h2>` and a matching entry in `.toc`.
Every `###` heading becomes an `<h3>`.
Blockquotes (`>`) become `.callout` divs — **only if the reasoning is scenario-specific** (see below).
Bold decision rationale (`**Why X over Y?**`) becomes `.callout` divs — **only if unique to this scenario**.
Rules and principles become `.rule` divs.
Warnings and gotchas become `.warn` divs.
The delta "Key decisions unique to this scenario" bullets become `.rule` or `.callout` divs depending on tone.

**Do NOT render the following as callouts** — these are generic architecture rationale that belong only in `ios-app-system-design-philosophy.html`, not in scenario decks:
- "Why MVVM over MVP?"
- "Why MVVM over VIPER?"
- "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- "UseCase vs Domain Service" comparison table
- "Domain Service vs Gateway" comparison table

If these appear in the source `.md`, skip them during HTML generation and flag them in your step 2 diff report as content to remove from the `.md`.

### File path

Save the HTML at `docs/deck/scenarios/<scenario-name>.html`.
Derive the filename from the `.md` filename — strip the `ios-` prefix:
- `ios-music-streaming-system-design.md` → `scenarios/music-streaming-system-design.html`
- `ios-ride-sharing-system-design.md` → `ride-sharing-system-design.html`

---

## Step 4 — Report

**Per file:** state:
1. Output file path
2. Sections that were updated (from step 2)
3. Any `.md` content that could not be cleanly mapped to an HTML component (flag for manual review)

**All-scenarios mode:** finish with a summary table:

```
## Sync Complete

| Scenario | Action | Sections updated |
|---|---|---|
| uber-eats | ✅ Regenerated | Delta table, Data Flow |
| messenger | ⏭️ Skipped | Already in sync |
| instagram-news-feed | ✅ Created | Full creation |
| hotel-booking | ✅ Regenerated | Architecture |
| music-streaming | ⏭️ Skipped | Already in sync |
| story-viewer | ⏭️ Skipped | Already in sync |
```

**Single/multi-scenario mode:** report only the target(s). Add at the end:
> To sync all HTML decks at once: `/philosophy-sync-scenario-html` (no argument)
