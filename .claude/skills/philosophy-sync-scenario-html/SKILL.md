---
name: philosophy-sync-scenario-html
description: Regenerates the HTML deck for a scenario doc from its .md source. Run after any manual edit to a docs/scenarios/*.md file.
user-invocable: true
---

A scenario `.md` file was updated and its HTML deck at `docs/deck/` is now out of sync. Your job is to regenerate the HTML to match the current `.md` content exactly.

## Inputs

The user provides a path to a scenario `.md` file. If no path is provided, list all files in `docs/scenarios/` and ask which one to sync.

## Step 1 — Read source files

Read:
1. The scenario `.md` file provided by the user
2. The existing HTML at `docs/deck/<scenario-name>.html` — derive the filename from the `.md` filename (e.g. `ios-music-streaming-system-design.md` → `music-streaming-system-design.html`)
3. `docs/deck/music-streaming-system-design.html` — style reference if the existing HTML doesn't exist yet

## Step 2 — Identify what changed

Compare the `.md` content against the existing HTML section by section. List the sections that differ — this tells the user exactly what will be regenerated and avoids confusion.

If the HTML does not exist yet, note that this is a full creation, not an update.

## Step 3 — Regenerate the HTML

Produce the full HTML file. Rules:

### CSS
Copy the `<style>` block verbatim from the style reference. Never modify or abbreviate it.

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
Save the HTML at `docs/deck/<scenario-name>.html`.
Derive the filename from the `.md` filename — strip the `ios-` prefix:
- `ios-music-streaming-system-design.md` → `music-streaming-system-design.html`
- `ios-ride-sharing-system-design.md` → `ride-sharing-system-design.html`

## Step 4 — Report to user

State:
1. Output file path
2. Sections that were updated (from step 2)
3. Any `.md` content that could not be cleanly mapped to an HTML component (flag for manual review)
