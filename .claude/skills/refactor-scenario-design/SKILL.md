---
name: refactor-scenario-design
description: Refactors a raw iOS system design notes file (from a YouTube video or mock interview) to align with the generic iOS architecture in docs/ios-app-system-design.md. Produces a clean scenario .md doc and a matching HTML deck file.
user-invocable: true
---

The user has raw system design notes from an external source (YouTube video, mock interview, article). The notes may have inconsistent structure, use different naming conventions, or reference architectural patterns that differ from the user's standard approach.

Your job is to refactor those notes into:
1. A clean `.md` scenario doc at `docs/scenarios/`
2. A matching HTML deck file at `docs/deck/`

Both outputs must:
- Align with the user's generic iOS architecture (`docs/ios-app-system-design.md`)
- Open with an explicit delta section (what's the same, what this scenario adds)
- Use the user's naming conventions throughout
- Preserve all domain-specific knowledge and rationale from the original notes

## Inputs

The user will provide a file path as the argument to this skill. The file may have any structure — do not assume a specific format. Read it as-is and extract what's useful.

If no path is provided, ask the user for the file path before proceeding.

## Step 1 — Read all reference files

Read the raw notes file provided by the user.

Also read these reference files:
- `docs/ios-app-system-design.md` — generic architecture (source of truth for naming and patterns)
- `docs/deck/music-streaming-system-design.html` — style reference for the HTML output (CSS, component classes, layout patterns)

If `docs/ios-app-system-design.md` does not exist, check `../docs/ios-app-system-design.md` relative to the notes file, then ask the user for the correct path.

## Step 2 — Vocabulary mapping

Scan the raw notes for every architectural component, layer, or pattern named. Build a translation table:

| Their term | User's term | Notes |
|---|---|---|
| (fill in) | (fill in) | (fill in) |

Use the generic architecture doc as the source of truth for the user's naming conventions:
- Remote access layer → `RemoteDataSource`
- Local/cache layer → `LocalDataSource`
- Business logic objects → `UseCase` (stateless) or `Domain Service` (stateful)
- Data objects that mirror API shape → `DTO`
- Conversion between DTO and Domain → `Mapper`
- Navigation objects → `Coordinator`
- Screen state objects → `ViewModel (@MainActor, @Published)`

Flag any component in the notes that has no clear equivalent in the generic architecture — these are likely scenario-specific additions (delta candidates).

## Step 3 — Layer audit

Check every component in the notes against the dependency rule: **Presentation → Domain ← Data. Domain depends on nothing.**

Flag violations:
- A ViewModel calling a Repository directly (should go via UseCase)
- A UseCase importing networking types (should use Repository protocol)
- A Repository returning DTOs to a UseCase (should map to Domain model first)
- A Domain model importing UIKit or Foundation networking types

Note violations but do not remove them from the output — instead annotate them with a `⚠️` and the correct fix.

## Step 4 — Delta identification

Identify what this scenario requires that the generic architecture does not cover. These become the delta section. Common delta categories:

- **Storage tiers** — does the scenario need file storage, offline saves, or LRU eviction beyond a simple cache?
- **Domain Services** — does the scenario need app-scoped stateful services (player, auth, session)?
- **Streaming / real-time** — WebSocket, HLS, live feed?
- **Pagination strategy** — cursor vs offset, and why?
- **Background processing** — downloads, sync, upload queues?
- **Platform-specific** — push notifications, deep links, background audio, location?

For each delta item, capture:
- What it is
- Why it's needed for this scenario specifically
- How it maps onto the generic architecture (which layer it lives in)

## Step 5 — Produce the output doc

Write a clean `.md` file. Save it at `docs/scenarios/ios-<scenario-name>-system-design.md` relative to the project root. If `docs/scenarios/` does not exist, create it. Use a descriptive kebab-case scenario name derived from the content (e.g. `ios-ride-sharing-system-design.md`).

Structure:

```
# iOS <Scenario> — System Design

**Source:** <source description from notes>

> Scenario extension of [`docs/ios-app-system-design.md`](../../ios-app-system-design.md)
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture
(bullet list)

### What this scenario adds
| Concept | Generic | This Scenario |
|---|---|---|

### Key decisions unique to this scenario
(bullet list — the "why" for each delta item)

---

## Requirements
(from notes)

## API Design
(from notes, translated to user's conventions)

## Data Model
(from notes, translated to user's conventions)

## Architecture
(layer breakdown using user's naming)

## Data Flow
(end-to-end, using user's component names)

## <Scenario-Specific Deep Dives>
(preserve any technical depth from the notes — HLS, pagination, offline, etc.)

## Interviewer Feedback / Key Takeaways
(if present in notes)
```

## Step 6 — Cross-check

Before writing any file, verify:
- No scenario component violates the dependency rule (or is annotated if it does)
- All naming follows the generic architecture conventions
- The delta table is complete — nothing scenario-specific leaked into "same as generic"
- The generic architecture doc does not need updating (if the scenario revealed a gap in the generic doc, call it out explicitly to the user)

## Step 7 — Produce the HTML deck

Using `docs/deck/music-streaming-system-design.html` as the style reference, produce a matching HTML file at `docs/deck/<scenario-name>.html`.

### CSS and styling
Copy the full `<style>` block verbatim from the reference HTML — do not modify or inline different styles. The design system is fixed.

### Available component classes (from the reference HTML)
Use these exactly as they appear in the reference:

| Class | Use for |
|---|---|
| `.stack` + `.stack-row` | Layer breakdowns, ordered steps |
| `.callout` | Blue — "why" decisions, trade-off explanations |
| `.rule` | Green — rules, principles, resolved items |
| `.warn` | Orange — gotchas, common mistakes |
| `.table-wrap` + `table` | Comparison tables |
| `pre` + `code` | Code blocks with syntax highlighting |
| `.toc` | Table of contents |
| `nav` | Breadcrumb at top |
| `.bottom-nav` | Prev/next navigation at bottom |

### Syntax highlighting inside `<pre><code>`
Use these span classes for code:
- `.kw` — keywords (`struct`, `func`, `let`, `class`, `enum`, `case`)
- `.ty` — type names (`TrackRepository`, `FetchPolicy`, `URL`)
- `.st` — strings and values (`"HLS"`, `file://`)
- `.cm` — comments
- `.nm` — method/property names
- `.gr` — HTTP verbs (`GET`, `POST`)

### HTML structure per section
Mirror the section structure of the `.md` output:
1. `<nav>` breadcrumb — link back to `index.html`
2. `<header>` — title, subtitle
3. `.toc` — all section anchors including `#delta` first
4. `<section id="delta">` — delta section with same/adds table and key decision `.rule`/`.callout` divs
5. Remaining sections matching the `.md` structure
6. `<section id="feedback">` — key takeaways as `.rule` divs
7. `.bottom-nav` — link back to `index.html` on the left; leave right side empty or link to a related deck if obvious

### Nav breadcrumb
```html
<nav>
  <a href="index.html">Home</a>
  <span class="sep">›</span>
  <span class="current"><Scenario Title></span>
</nav>
```

Write the HTML file after the `.md` file is complete — use the `.md` as the content source so both outputs stay in sync.

## Output to user

After writing both files:
1. State both output file paths (`.md` and `.html`)
2. Show the delta table (most useful thing to scan quickly before an interview)
3. List any violations found in step 3 with their fixes
4. List any gaps found in the generic architecture doc (step 6)
