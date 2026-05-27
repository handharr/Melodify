---
name: philosophy-sync-recall-html
description: Syncs docs/deck/system-design-recall.html with the current state of all docs/scenarios/*.md files and their docs/deck/*.html counterparts. Detects flow renames, component name drift, endpoint changes, and missing/new scenario cards.
user-invocable: true
---

The `system-design-recall.html` is a condensed one-page reference that shows all scenario flows side-by-side in layer columns. It is **manually maintained** and can drift from the scenario docs. This skill re-derives it from the authoritative sources and proposes targeted updates before writing.

---

## Inputs

**Optional:** a scenario name or comma-separated list of names.

| Invocation | Behaviour |
|---|---|
| `/philosophy-sync-recall-html` | **All-scenarios mode** — checks and proposes updates for all 6 cards |
| `/philosophy-sync-recall-html uber-eats` | **Single-scenario mode** — only that card is read, diffed, and updated |
| `/philosophy-sync-recall-html uber-eats messenger` | **Multi-scenario mode** — only those cards are read, diffed, and updated |

Accepted names (case-insensitive, hyphens optional): `uber-eats`, `messenger`, `music-streaming`, `instagram-news-feed` (or `instagram`), `hotel-booking` (or `hotel`), `story-viewer` (or `story`).

In single/multi-scenario mode the skill **skips reading, diffing, and writing** all cards not in the target set. The rest of the file is never touched.

---

## Step 1 — Read source files

**All-scenarios mode:** read every file listed in the mapping table below.

**Single/multi-scenario mode:** read only:
1. `docs/deck/system-design-recall.html` — always required (to preserve the rest of the file on write)
2. The `.md` file(s) for the target scenario(s)
3. The HTML deck(s) for the target scenario(s)

Skip reading all other scenario `.md` and deck files entirely.

**Scenario → file mapping:**

| Scenario card in recall | Source .md | HTML deck |
|---|---|---|
| Uber Eats | `ios-uber-eats-system-design.md` | `docs/deck/scenarios/uber-eats-system-design.html` |
| Messenger | `ios-messenger-system-design.md` | `docs/deck/scenarios/messenger-system-design.html` |
| Music Streaming | `ios-music-streaming-system-design.md` | `docs/deck/scenarios/music-streaming-system-design.html` |
| Instagram News Feed | `ios-instagram-news-feed-system-design.md` | `docs/deck/scenarios/instagram-news-feed-system-design.html` |
| Hotel Booking | `ios-hotel-booking-system-design.md` | `docs/deck/scenarios/hotel-booking-system-design.html` |
| Story Viewer | `ios-story-viewer-system-design.md` | `docs/deck/scenarios/story-viewer-system-design.html` |

---

## Column philosophy — layers only

The table columns represent **Clean Architecture layers** exclusively. Storage and Network are external concerns (they sit outside the app's layered architecture) and are therefore merged into a single **External** column — they do not get individual columns.

| Column | Layer | What it contains |
|---|---|---|
| **External** | External | Local store tech + endpoint/transport, both stacked in one cell |
| **Infrastructure** | Infrastructure | Gateway / SDK wrapper — bridges External to Domain |
| **Data** | Data | Repository (solid chip) + DataSource (dashed chip) |
| **Domain** | Domain | Stateless UseCase (solid) or stateful Service (dashed) |
| **Presentation** | Presentation | ViewModel or ViewController |

**Never add separate Storage or Network columns.** If both apply to a flow, show them stacked in the External cell — storage chip first, then network chip.

### Chip type rules

| Component type | Column | CSS class | Border |
|---|---|---|---|
| UseCase, Repository | Data / Domain | `.chip` | solid |
| Service (Domain), DataSource | Data / Domain | `.chip.svc` / `.chip.ds` | dashed |
| Infrastructure Gateway / SDK | Infrastructure | `.chip.infra` | solid, purple tint |
| Network endpoint | External | `.chip.ep` | solid, neutral |
| Storage / DB | External | `.chip.st` | dashed, neutral |
| Shared (spans multiple flows) | any | `.chip.shared` | neutral + flow dots |

### Flow color classes

| Class | Color | When to use |
|---|---|---|
| `f1` | Blue (accent) | Read / Load — initial page loads, cache reads, library fetches |
| `f2` | Orange | Write / Mutation — POST, PATCH, user-initiated writes |
| `f3` | Green | Real-time / Streaming — WebSocket receive, SSE, live updates |
| `f4` | Red | Offline / Background — sync queues, offline playback, retry on foreground |
| `f5` | Purple | Special / Infrastructure — payment gateway, timers, auth, system-level |

### Component uniqueness

Each named component appears **at most once** per layer column per scenario card. Showing the same chip twice in two differently-colored rows creates a false signal — the color implies the component belongs to that flow exclusively, when it participates in multiple.

### Consecutive reuse — rowspan + flow dots

When the same component participates in N **consecutive** flows:

1. Merge the N cells with `rowspan="N"`.
2. Render the chip with `.chip.shared` (neutral `var(--text)` color — no flow color).
3. Add a `<div class="flow-dots">` beneath the chip — one `<span class="flow-dot">` per participating flow, tinted with that flow's CSS variable.

This preserves "which flows use this component" without claiming the component is owned by any single flow.

### Non-consecutive reuse — ref badge

When the same component appears in non-consecutive rows (e.g. rows 1 and 4 with a different component in rows 2–3), rowspan is not possible. Show the chip normally in the first row; in each later non-consecutive row show the chip again followed by `<span class="ref-badge">↑</span>` to signal reuse.

### Rowspan decision criteria

**Rowspan when:**
- The chip is the sole or primary component in the cell (no two distinct components mixed in one cell)
- It appears in 2+ consecutive rows

**Do not rowspan:**
- DataSource cells — per-flow sub-notes carry distinct recall details (upsert strategy, FetchPolicy, retry behavior)
- External (network) cells — endpoints are always unique per flow
- Mixed-component cells (e.g. `APIClient + NWPathMonitor`)

### Flow color on unspanned rows

Chips in non-rowspanned cells inherit `currentColor` from `tr.f1–f5`. Only rowspanned chips use `.chip.shared` neutral color.

---

## Step 2 — Extract the recall data from each scenario `.md`

For each scenario, derive the data that maps into the recall card. Extract from three sections:

### 2a. Scenario tag (subtitle)

The `.scenario-tag` line in the recall card is a comma-separated list of the most distinctive concepts for that scenario — e.g. `"Food Delivery · SSE · Server-hosted Basket"`. Derive this from:

- The `## Delta — What This Scenario Adds` table: take the scenario-unique concepts (not the generic ones)
- The "Key decisions unique to this scenario" bullets: take the nouns that distinguish this scenario from others

Keep it under 6 concepts. Prefer nouns over verbs. Separate with ` · `.

### 2b. Key flows (table rows)

Each row in the recall table represents one named end-to-end flow. Extract flows from the `## Data Flow` section of the `.md`. One `###` heading = one flow = one row.

If `## Data Flow` is absent or too sparse, fall back to the key flows visible in the scenario's HTML deck (look for `<tr class="f*">` rows).

**Flow color assignment** — map each flow to a row class based on its nature:

| Class | Color | When to use |
|---|---|---|
| `f1` | Blue (accent) | Read / Load — initial page loads, cache reads, library fetches |
| `f2` | Orange | Write / Mutation — POST, PATCH, user-initiated writes |
| `f3` | Green | Real-time / Streaming — WebSocket receive, SSE, live updates |
| `f4` | Red | Offline / Background — sync queues, offline playback, retry on foreground |
| `f5` | Purple | Special / Infrastructure — payment gateway, timers, auth, system-level |

Use the same color as the current recall card if the flow already exists and the color is appropriate. Only reassign if the current color is wrong for the flow type.

### 2c. Per-flow layer data (table cells)

For each flow, extract the component at each layer column. Use this mapping:

**External column** — What external resources (local store + network) does this flow touch?
- This single column merges Storage and Network — columns represent layers, and neither storage nor network is an app layer.
- Show storage chip first (if any), then network chip (if any), stacked vertically in the same `<td>`.
- Storage values: `CoreData`, `Realm`, `GRDB`, `disk file://`, `SDWebImage disk cache`, `Keychain`, `UserDefaults`
- Network values: `GET /path`, `POST /path`, `PATCH /path`, `WS /path`, `SSE /path`, `S3 CDN image URLs`, `Stripe SDK → token → POST /path`
- Sub-labels go immediately after the chip they annotate (e.g. `"cache · offline restore"`, `"idempotencyKey = UUID() at Param call site"`, `"cursor stable on insertions"`)
- Use `—` only if neither storage nor network is involved in this flow.
- Use `&amp;` for `&` in HTML.

**Infrastructure column** — What Infrastructure-layer component handles the transport?
- Source: Infrastructure section in Architecture, or the `Gateway`/SDK mentions in the data flow
- Values: `APIClient`, `WebSocket client`, `OrderSSEGateway`, `AVPlayer`, `SDWebImage`, `StripePaymentGateway`, `NWPathMonitor`, `Timer (Foundation)` — always wrapped in `.chip.infra`
- Sub-label: the protocol it implements or the key constraint (e.g. `"implements OrderSSEGatewayProtocol"`)
- Use `—` (empty cell) only if no infrastructure component is involved

**Data column** — Which Repository and DataSource(s) serve this flow?
- Source: Architecture section, data flow pseudocode
- Repository: `.chip` (solid border) — always domain-prefixed (`RestaurantRepo`, `MessageRepo`)
- DataSource(s): `.chip.ds` (dashed border) — always domain-prefixed (`RestaurantRemoteDS`, `MessageLocalDS`)
- Sub-label under DataSource: secondary DS if both local and remote are used
- Use `—` (empty cell) if this flow bypasses the Repo/DS layer (e.g. pure-infrastructure flows like `Load Images`)

**Domain column** — Which UseCase or Domain Service drives this flow?
- Source: Domain section in Architecture
- UseCase: `.chip` (solid) — stateless, one-shot
- Service: `.chip.svc` (dashed) — stateful, long-lived
- Sub-label: key behaviour note (e.g. `"app-scoped · AnyPublisher<Order, AppError>"`)
- Use `—` if a flow is presentation-only (e.g. pure UI timer, view recycling)

**Presentation column** — Which ViewModel or ViewController handles this flow?
- Source: Presentation section in Architecture
- Use the named ViewModel (e.g. `LibraryVM`, `ChatThreadVM`, `FeedVM`) as `.chip`
- Sub-label: key pattern if recall-worthy (e.g. `"implements UICollectionViewDataSource"`, `"← observes Realm live query"`)
- Use `—` only for flows that are explicitly infrastructure-only (no presentation component involved at all)

---

## Step 3 — Compare extracted data against current recall HTML

**Single/multi-scenario mode:** only diff the target card(s). Skip all others — do not report on them at all.

**All-scenarios mode:** diff every card and include the summary table at the end.

For each scenario card **in scope**, diff the extracted data (step 2) against what's currently in `system-design-recall.html`.

Report findings in this format:

```
### Scenario: <name>
**Drift:** None / Minor / Significant

Changes:
- Flow "<name>": Network cell: `GET /restaurants/<addressID>` → `GET /restaurants/:addressID`  ← endpoint path style
- Flow "<name>": Domain cell: UseCase renamed `FetchRestaurantsUseCase` → `FetchRestaurantsUC`
- Scenario tag: missing `"Two-tier LRU"` — present in delta table
- Flow "Sync Offline Queue": missing from recall card — present in .md Data Flow section
- (none)
```

**Only flag real drift** — do not flag stylistic differences that are intentional abbreviations in the recall format (e.g. `FetchRestaurantsUC` vs the full `FetchRestaurantsUseCase` — the recall uses the short form). The recall card is intentionally condensed.

**Intentional abbreviation rules** (do NOT flag these as drift):
- UseCase names may be shortened: `FetchRestaurantsUseCase` → `FetchRestaurantsUC`
- Service names may be shortened: `MessageStreamService` → `MessageStreamService` (keep full)
- Repository names may be shortened: `RestaurantRepository` → `RestaurantRepo`
- DataSource names may be shortened: `RestaurantRemoteDataSource` → `RestaurantRemoteDS`, `RestaurantLocalDataSource` → `RestaurantLocalDS`
- Sub-labels are curated — their absence from the recall card is not drift unless the corresponding `.md` added a new critical constraint

**Flag as drift:**
- A component name changed (rename, not abbreviation)
- An endpoint path changed
- A flow was added to the `.md` but is absent from the recall card
- The scenario tag is missing a concept that's in the `.md` delta table
- A chip type is wrong (solid vs dashed, wrong color class)
- A layer cell has `—` in the recall but has a real component in the `.md` (or vice versa)
- The recall card has separate **Storage** and **Network** columns instead of a single **External** column — this is always drift; the columns must represent layers only

After the per-scenario reports, show a summary table:

```
| Scenario | Flows | Components | Endpoints | Tag | Overall |
|---|---|---|---|---|---|
| Uber Eats | ✅ | ✅ | ✅ | ✅ | ✅ In sync |
| Messenger | ✅ | ⚠️ | ✅ | ✅ | ⚠️ Minor drift |
| Music Streaming | ... | ... | ... | ... | ... |
```

If all scenarios are in sync, state that and stop — do not write the file.

---

## Step 4 — Propose and confirm updates

**Single/multi-scenario mode:** the target set is already known — skip asking "which scenarios?". Only ask:

> "Apply updates to `<scenario name(s)>`?"

**All-scenarios mode:** present a summary of all cards that have drift and ask:

> "Apply all updates? Or specify scenarios: e.g. `uber-eats messenger`"

Do not write anything until the user confirms.

Only proceed with cards the user approved. All other cards are never touched.

---

## Step 5 — Regenerate the approved scenario cards

For each approved scenario card, produce the full `<div class="scenario-card">...</div>` block.

### Card structure rules

```html
<div class="scenario-card">
  <div class="scenario-head">
    <div>
      <div class="scenario-tag" style="color:var(--<color>)"><tag text></div>
      <h2><Scenario Name></h2>
    </div>
    <a href="scenarios/<scenario-name>-system-design.html" class="deck-link">Full deck →</a>
  </div>
  <div class="arch-wrap">
    <table class="arch-table">
      <thead><tr>
        <th></th>
        <th class="col-external">External</th>
        <th class="col-infra">Infrastructure</th>
        <th>Data</th>
        <th>Domain</th>
        <th>Presentation</th>
      </tr></thead>
      <tbody>
        <!-- one <tr class="f*"> per flow -->
      </tbody>
    </table>
  </div>
</div>
```

**Column count is always 5 + the flow label** = 6 `<th>` cells total. Never split External back into Storage and Network.

**Scenario tag color** — assign `var(--color)` based on the dominant scenario type:
- Orange `--orange`: write-heavy or booking (Uber Eats, Hotel Booking)
- Accent `--accent`: read-heavy or real-time read (Messenger, Story Viewer)
- Purple `--purple`: media / infrastructure-heavy (Music Streaming)
- Green `--green`: social / feed (Instagram News Feed)

**Chip rules:**

| Component type | Column | Class | Border |
|---|---|---|---|
| UseCase, Repository | Data / Domain | `.chip` | solid |
| Service (Domain), DataSource | Data / Domain | `.chip.svc` / `.chip.ds` | dashed |
| Infrastructure Gateway/SDK | Infrastructure | `.chip.infra` | solid, purple tint |
| Network endpoint | External | `.chip.ep` | solid, neutral |
| Storage / DB | External | `.chip.st` | dashed, neutral |
| Shared (spans multiple flows) | any | `.chip.shared` | neutral + flow dots |

**Sub-labels** use `<div class="sub">` immediately after the chip they annotate.

**Entity groups** (multiple chips in one cell) use `<div class="eg">` with `<div class="type-lbl">` inside:

```html
<div class="eg">
  <div class="type-lbl">Repository</div>
  <span class="chip">RestaurantRepo</span>
</div>
<div class="eg">
  <div class="type-lbl">DataSource</div>
  <span class="chip ds">RestaurantRemoteDS</span>
  <div class="sub">RestaurantLocalDS — FetchPolicy.cached</div>
</div>
```

**Empty cells** use `<td class="col-external empty">—</td>` for the External column and `<td class="col-infra empty">—</td>` for Infrastructure; plain `<td class="empty">` for Data / Domain / Presentation.

**Flow label cell** always uses:
```html
<td class="lbl"><div class="flow-name"><Flow Name></div></td>
```

The flow label text inherits its color from the row's `tr.f*` class — do not add inline color to it.

### CSS and head — never modify

Do not touch the `<style>` block, `<head>`, `<nav>`, `<header>`, `<div class="legend">`, or `<div class="chip-legend">` sections. Replace only the `<div class="scenarios">` inner content for the approved cards.

---

## Step 6 — Write the updated file

Write the full updated `docs/deck/system-design-recall.html`.

**All cards not in the approved set must be written back verbatim** — copy their `<div class="scenario-card">` blocks unchanged from the file read in step 1. Never regenerate a card that wasn't approved.

Preserve the exact order of scenario cards:
1. Uber Eats
2. Messenger
3. Music Streaming
4. Instagram News Feed
5. Hotel Booking
6. Story Viewer

Do not reorder cards regardless of which subset was approved.

---

## Step 7 — Report

```
## Sync Complete — system-design-recall.html
Mode: all-scenarios | single: <name> | multi: <name, name>

### Updated cards
| Scenario | Flows | Changes |
|---|---|---|
| Messenger | 4 | Domain cell: renamed MessageStreamService → correct; tag updated |

### In-scope but already in sync
Music Streaming — no drift found, not written.

### Out of scope (not checked)
Uber Eats, Instagram News Feed, Hotel Booking, Story Viewer — skipped per mode.
(omit this section in all-scenarios mode)

### Recommended follow-up
- If a scenario .md was updated, run /philosophy-sync-scenario-html to regenerate its full deck.
- If the generic arch changed, run /philosophy-sync-scenarios first, then re-run this skill.
- To check all scenarios at once: /philosophy-sync-recall-html (no argument)
```
