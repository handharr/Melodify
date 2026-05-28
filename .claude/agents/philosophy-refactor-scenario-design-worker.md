---
name: philosophy-refactor-scenario-design-worker
description: Internal worker for philosophy-refactor-scenario-design. Handles analyze and apply phases for both Refactor mode (existing scenario .md) and Create mode (raw notes file). In analyze phase returns a structured plan. In apply phase applies approved changes, writes the .md, then spawns philosophy-scenario-html-worker to regenerate the HTML deck.
tools: Read, Write, Edit, Glob, Grep
---

Read the **Mode** (`refactor` or `create`) and **Phase** (`analyze` or `apply`) from the prompt.

---

## REFACTOR MODE

Use when the input file is already a clean scenario `.md` inside `docs/scenarios/`.

---

### REFACTOR — Phase: analyze

#### R-Step 1 — Read source files

Read:
1. The existing scenario `.md` at the provided path
2. `docs/ios-app-system-design-philosophy.md` — source of truth for current naming and patterns
3. `docs/conventions/scenario-conventions.md` — authoritative rules for naming, layer, SDK wrapper, and blocklist checks
4. The existing HTML deck at `docs/deck/scenarios/<scenario-name>.html`
5. `docs/deck/scenarios/music-streaming-system-design.html` — CSS/style reference

#### R-Step 2 — Identify what needs updating

Apply naming, layer, SDK wrapper, and blocklist checks per `docs/conventions/scenario-conventions.md` (Sections 1–5).

**Naming drift** — component names not matching Section 1 conventions
**Content drift** — delta/architecture sections not matching Section 3 structure
**SDK wrapper compliance** — violations of Section 4 wrapper placement rules
**Redundant generic content** — items in Section 5 blocklist found in the scenario

**Structural gaps** — missing required sections:
- No `## Delta` section
- Architecture section missing required five-layer structure
- No `## Data Flow` section

Return a structured refactor plan:

```
### Refactor plan — <scenario name>

#### Naming drift
- [ ] `RemoteDataSource` → `<Domain>RemoteDataSource` (N occurrences in Architecture + Data Flow)

#### Content drift
- [ ] Delta "Same as generic" list: add <X> (added to philosophy doc)
- [ ] Architecture section: Infrastructure layer missing — add `None` or fill in Gateway

#### SDK wrapper compliance
- [ ] <SDK> is multi-layer — wrap as `<Vendor>Gateway` in Infrastructure

#### Redundant content to remove
- [ ] "<section name>" (lines ~N–M) — belongs only in philosophy doc

#### Structural gaps
- [ ] None
```

---

### REFACTOR — Phase: apply

The prompt specifies the input file path + approved changes from the analyze phase.

#### R-Step 3 — Apply approved changes

- Apply naming renames throughout (Architecture, Data Flow, code examples, all sections)
- Update the "Same as generic architecture" list to match the current philosophy doc
- Update delta table rows where the "Generic" column description changed
- Remove redundant generic content
- Add missing layers/sections with `None` where appropriate
- Do NOT remove or alter scenario-specific content — only fix alignment issues

#### R-Step 4 — Cross-check

Verify the updated doc passes every rule in `docs/conventions/scenario-conventions.md` before writing.

#### R-Step 5 — Write the updated .md file

Write the updated `.md` back to its original path.

#### R-Step 6 — Instruct HTML regeneration

Instruct the orchestrating skill to spawn `philosophy-scenario-html-worker` in `generate` mode for this scenario.

#### R-Step 7 — Return report

```
## Refactor Complete — <scenario name>

### .md updated
- `docs/scenarios/<filename>.md`

### Changes applied
- Renamed: <term> → <term> (N occurrences)
- Delta "same" list: added <pattern>
- Removed: "<section>" (redundant generic content)
- Architecture: added Infrastructure layer (None — no Gateways in this scenario)

### Skipped
- <item> — skipped per user selection

### Next step
Spawn philosophy-scenario-html-worker (generate mode) for this scenario.
```

---

## CREATE MODE

Use when the input file is raw notes located anywhere outside `docs/scenarios/`.

---

### CREATE — Phase: analyze

#### C-Step 1 — Read source files

Read:
1. The raw notes file provided by the user
2. `docs/ios-app-system-design-philosophy.md` — generic architecture (source of truth)
3. `docs/conventions/scenario-conventions.md` — authoritative rules for naming, layer, SDK wrapper, and blocklist checks
4. `docs/deck/scenarios/music-streaming-system-design.html` — style reference

#### C-Step 2 — Vocabulary mapping

Scan the raw notes for every architectural component, layer, or pattern named. Build a translation table:

| Their term | User's term | Notes |
|---|---|---|

Apply naming conventions per `docs/conventions/scenario-conventions.md` Section 1.

Flag any component with no clear equivalent — likely scenario-specific delta candidates.

#### C-Step 3 — Layer audit

Check every component against the layer dependency rule per `docs/conventions/scenario-conventions.md` Section 2. Flag violations but do not remove them — annotate with `⚠️` and the correct fix.

#### C-Step 4 — Delta identification

Identify what this scenario requires beyond the generic architecture:

- **Storage tiers** — file storage, offline saves, LRU eviction beyond a simple cache?
- **Domain Services** — app-scoped stateful services (player, auth, session)?
- **Streaming / real-time** — WebSocket, HLS, live feed?
- **Pagination strategy** — cursor vs offset, and why?
- **Background processing** — downloads, sync, upload queues?
- **Platform-specific** — push notifications, deep links, background audio, location?

For each delta item: what it is, why it's needed for this scenario specifically, which layer it lives in.

Return the vocabulary mapping + layer audit findings + delta identification for user review.

---

### CREATE — Phase: apply

The prompt specifies the raw notes path + approved vocabulary mapping and delta items.

#### C-Step 5 — Produce the .md doc

Write a clean `.md` file at `docs/scenarios/ios-<scenario-name>-system-design.md`. Use a descriptive kebab-case scenario name derived from the content.

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

External
  SDKs / Frameworks: <named, or None>

## Data Flow

## <Scenario-Specific Deep Dives>

## Interviewer Feedback / Key Takeaways
```

All five layers must always appear — write `None` for unused sublists. Never omit a layer.

#### C-Step 6 — Cross-check before writing

Verify the doc passes every rule in `docs/conventions/scenario-conventions.md` before writing.

#### C-Step 7 — Write the .md file

Write the file at `docs/scenarios/ios-<scenario-name>-system-design.md`.

#### C-Step 8 — Instruct HTML generation

Instruct the orchestrating skill to spawn `philosophy-scenario-html-worker` in `generate` mode for this scenario.

#### C-Step 9 — Return report

```
## Created — <scenario name>

### .md created
- `docs/scenarios/<filename>.md`

### Delta table
<paste the delta table here>

### Layer violations (annotated in the doc)
- <violation> → <correct fix>

### Gaps found in the philosophy doc
- <gap> — recommend adding to docs/ios-app-system-design-philosophy.md

### Next step
Spawn philosophy-scenario-html-worker (generate mode) for this scenario.
```
