---
name: philosophy-refactor-scenario-design
description: Refactors a raw iOS system design notes file (from a YouTube video or mock interview) to align with the generic iOS architecture in docs/ios-app-system-design-philosophy.md. Produces a clean scenario .md doc and a matching HTML deck file.
user-invocable: true
---

The user provides a file path as the argument. Your job depends on where that path lives:

| Input path | Mode | What happens |
|---|---|---|
| Inside `docs/scenarios/` | **Refactor mode** | Update the existing scenario `.md` in place, then regenerate its HTML deck |
| Outside `docs/scenarios/` | **Create mode** | Treat as raw notes; produce a new scenario `.md` + HTML deck from scratch |

Both modes must produce output that:
- Aligns with the user's generic iOS architecture (`docs/ios-app-system-design-philosophy.md`)
- Opens with an explicit delta section (what's the same, what this scenario adds)
- Uses the user's naming conventions throughout
- Preserves all domain-specific knowledge and rationale

---

## Inputs

The user provides a file path as the argument to this skill.

**If no path is provided:** list all files in `docs/scenarios/` and ask: "Which scenario do you want to refactor, or provide a path to raw notes for a new scenario?"

**Mode detection:**
- Path starts with `docs/scenarios/` or resolves to a file inside that directory → **Refactor mode**
- Any other path → **Create mode**

---

## REFACTOR MODE — updating an existing scenario doc

Use this mode when the input file is already a clean scenario `.md` inside `docs/scenarios/`.

### R-Step 1 — Read source files

Read:
1. The existing scenario `.md` at the provided path
2. `docs/ios-app-system-design-philosophy.md` — source of truth for current naming and patterns
3. The existing HTML deck at `docs/deck/<scenario-name>.html` — to understand what the current HTML looks like
4. `docs/deck/music-streaming-system-design.html` — CSS/style reference

### R-Step 2 — Identify what needs updating

Compare the existing scenario `.md` against the current generic architecture doc. Find:

**Naming drift** — components whose names no longer match current conventions:
- DataSources not domain-prefixed (bare `RemoteDataSource` / `LocalDataSource` as class names)
- Gateways not vendor-prefixed
- Repositories, UseCases, or Services using old naming patterns

**Content drift** — sections that are stale or incomplete:
- "Same as generic architecture" list missing patterns that are now in the generic doc
- Delta table "Generic" column descriptions that no longer match the generic doc
- Architecture section missing one or more of the four required layers
- DataSources listed without domain prefix in layer breakdowns or data flow pseudocode

**Redundant generic content** — explanations that belong only in the philosophy doc, not here:
- "Why MVVM over MVP?" / "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding?"
- "UseCase vs Domain Service" or "Domain Service vs Gateway" comparison tables

**Structural gaps** — missing required sections or subsections:
- No `## Delta` section
- Architecture section missing required four-layer structure
- No `## Data Flow` section

Present the full findings to the user before making any changes:

```
### Refactor plan — <scenario name>

#### Naming drift
- [ ] `RemoteDataSource` → `RestaurantRemoteDataSource` (3 occurrences in Architecture + Data Flow)
- [ ] `LocalDataSource` → `MessageLocalDataSource` (2 occurrences)

#### Content drift
- [ ] Delta "Same as generic" list: add `ThirdPartyDataSource facade pattern` (added to generic doc)
- [ ] Architecture section: Infrastructure layer missing — add `None` or fill in Gateway

#### Redundant content to remove
- [ ] "Why MVVM over MVP?" section (lines ~120–135) — belongs only in philosophy doc

#### Structural gaps
- [ ] None
```

Ask: **"Apply all changes? Or select specific items?"**

### R-Step 3 — Apply approved changes

For each approved item:
- Apply naming renames throughout (Architecture, Data Flow, code examples, all sections)
- Update the "Same as generic architecture" list to match the current generic doc
- Update delta table rows where the "Generic" column description changed
- Remove redundant generic content
- Add missing layers/sections with `None` where appropriate
- Do NOT remove or alter scenario-specific content — only fix alignment issues

### R-Step 4 — Cross-check

Verify the updated doc:
- All four layers present in Architecture section (Presentation / Domain / Data / Infrastructure)
- All DataSources are domain-prefixed in every section
- No generic "Why" explanations remain
- Delta section accurately reflects what's same vs scenario-specific
- No dependency rule violations (or annotated with `⚠️` if present)

### R-Step 5 — Regenerate the HTML deck

Using `docs/deck/music-streaming-system-design.html` as the style reference, regenerate the full HTML deck at `docs/deck/<scenario-name>.html` from the updated `.md`.

Follow the same HTML generation rules as the Create mode (see below) — CSS verbatim, `.callout`/`.rule`/`.warn` mapping, four-layer architecture rendering, syntax highlighting.

### R-Step 6 — Report

```
## Refactor Complete — <scenario name>

### Files updated
- `docs/scenarios/<filename>.md`
- `docs/deck/<filename>.html`

### Changes applied
- Renamed: `RemoteDataSource` → `RestaurantRemoteDataSource` (5 occurrences)
- Delta "same" list: added ThirdPartyDataSource facade pattern
- Removed: "Why MVVM over MVP?" section
- Architecture: added Infrastructure layer (None — no Gateways in this scenario)

### Skipped
- <item> — skipped per user selection

### Recommended follow-up
- Run /philosophy-sync-recall-html <scenario-name> to update the recall card for this scenario
```

---

## CREATE MODE — producing a new scenario from raw notes

Use this mode when the input file is raw notes from a YouTube video, mock interview, or article — located anywhere outside `docs/scenarios/`.

### C-Step 1 — Read source files

Read:
1. The raw notes file provided by the user
2. `docs/ios-app-system-design-philosophy.md` — generic architecture (source of truth for naming and patterns)
3. `docs/deck/music-streaming-system-design.html` — style reference for the HTML output (CSS, component classes, layout patterns)

If `docs/ios-app-system-design-philosophy.md` does not exist, check `../docs/ios-app-system-design-philosophy.md` relative to the notes file, then ask the user for the correct path.

### C-Step 2 — Vocabulary mapping

Scan the raw notes for every architectural component, layer, or pattern named. Build a translation table:

| Their term | User's term | Notes |
|---|---|---|
| (fill in) | (fill in) | (fill in) |

Use the generic architecture doc as the source of truth for the user's naming conventions:
- Remote access layer → `<Domain>RemoteDataSource` (e.g. `RestaurantRemoteDataSource`) — always domain-prefixed, never bare `RemoteDataSource`
- Local/cache layer → `<Domain>LocalDataSource` (e.g. `MessageLocalDataSource`) — always domain-prefixed, never bare `LocalDataSource`
- Business logic objects → `UseCase` (stateless) or `Domain Service` (stateful)
- Data objects that mirror API shape → `DTO`
- Conversion between DTO and Domain → `Mapper`
- Navigation objects → `Coordinator`
- Screen state objects → `ViewModel (@MainActor, @Published)`
- Infrastructure SDK wrappers → `<Vendor><Domain>Gateway` (e.g. `StripePaymentGateway`) — conforms to a `<Domain>GatewayProtocol` defined in Domain

Flag any component in the notes that has no clear equivalent in the generic architecture — these are likely scenario-specific additions (delta candidates).

### C-Step 3 — Layer audit

Check every component in the notes against the dependency rule: **Presentation → Domain ← Data. Infrastructure conforms to Domain protocols. Domain depends on nothing.**

Flag violations:
- A ViewModel calling a Repository directly (should go via UseCase)
- A UseCase importing networking types (should use Repository protocol)
- A Repository returning DTOs to a UseCase (should map to Domain model first)
- A Domain model importing UIKit or Foundation networking types

Note violations but do not remove them from the output — instead annotate them with a `⚠️` and the correct fix.

### C-Step 4 — Delta identification

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

### C-Step 5 — Produce the `.md` doc

Write a clean `.md` file. Save it at `docs/scenarios/ios-<scenario-name>-system-design.md` relative to the project root. Use a descriptive kebab-case scenario name derived from the content (e.g. `ios-ride-sharing-system-design.md`).

Structure:

```
# iOS <Scenario> — System Design

**Source:** <source description from notes>

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)
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

## API Design

## Data Model

## Architecture

Presentation
  <named ViewControllers and ViewModels>

Domain
  UseCases: <named, one per user action or screen load>
  Services: <named Domain Services, or None>
  Models: <named Domain Models and Param structs>

Data
  Repositories: <named, one per aggregate>
  DataSources: <named domain-prefixed RemoteDataSource and LocalDataSource per Repository>
  DTOs / Mappers: <named>

Infrastructure
  Gateways: <named vendor-prefixed Gateways, or None>

## Data Flow

## <Scenario-Specific Deep Dives>

## Interviewer Feedback / Key Takeaways
```

All four layers must always appear in Architecture — write `None` for unused sublists. Never omit a layer.

### C-Step 6 — Cross-check

Before writing any file, verify:
- No scenario component violates the dependency rule (or annotated with `⚠️` if it does)
- All naming follows the generic architecture conventions; all DataSources are domain-prefixed
- The delta table is complete — nothing scenario-specific leaked into "same as generic"
- The generic architecture doc does not need updating (if the scenario revealed a gap in the generic doc, call it out explicitly to the user)
- **No generic "Why" explanations are in the output.** Strip:
  - "Why MVVM over MVP?" / "Why MVVM over VIPER?" / "Why Clean Architecture over MVC?"
  - "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
  - "UseCase vs Domain Service" comparison table
  - "Domain Service vs Gateway" comparison table
  - Keep only reasoning that is unique to this specific scenario

### C-Step 7 — Produce the HTML deck

Using `docs/deck/music-streaming-system-design.html` as the style reference, produce a matching HTML file at `docs/deck/<scenario-name>.html`.

**CSS and styling:** copy the full `<style>` block verbatim — do not modify or abbreviate it.

**Component classes:**

| Class | Use for |
|---|---|
| `.stack` + `.stack-row` | Layer breakdowns, ordered steps |
| `.callout` | Blue — "why" decisions, trade-off explanations |
| `.rule` | Green — rules, principles, resolved items |
| `.warn` | Orange — gotchas, common mistakes |
| `.table-wrap` + `table` | Comparison tables |
| `pre` + `code` | Code blocks with syntax highlighting |
| `.toc` | Table of contents — `#delta` must be first entry |
| `nav` | Breadcrumb at top |
| `.bottom-nav` | Prev/next navigation at bottom |

**Syntax highlighting inside `<pre><code>`:**
- `.kw` — keywords (`struct`, `func`, `let`, `class`, `enum`, `case`)
- `.ty` — type names (`TrackRepository`, `FetchPolicy`, `URL`)
- `.st` — strings and values (`"HLS"`, `file://`)
- `.cm` — comments
- `.nm` — method/property names
- `.gr` — HTTP verbs (`GET`, `POST`)

**HTML structure:**
1. `<nav>` breadcrumb — link back to `index.html`
2. `<header>` — title, subtitle
3. `.toc` — all section anchors, `#delta` first
4. `<section id="delta">` — delta section with `.rule`/`.callout` divs for key decisions
5. Remaining sections matching the `.md` structure
6. `<section id="feedback">` — key takeaways as `.rule` divs
7. `.bottom-nav` — `← Home` on the left; right side empty or link to a related deck

Write the HTML file after the `.md` is complete — use the `.md` as the content source.

### C-Step 8 — Report

After writing both files:

```
## Created — <scenario name>

### Files created
- `docs/scenarios/<filename>.md`
- `docs/deck/<filename>.html`

### Delta table
<paste the delta table here — most useful pre-interview scan>

### Layer violations (annotated in the doc)
- <violation> → <correct fix>

### Gaps found in the generic architecture doc
- <gap> — recommend adding to docs/ios-app-system-design-philosophy.md

### Recommended follow-up
- Run /philosophy-sync-recall-html <scenario-name> to add this scenario to the recall page
```
