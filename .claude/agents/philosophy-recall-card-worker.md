---
name: philosophy-recall-card-worker
description: Internal reusable worker. Handles ONE scenario recall card. In diff mode reads the scenario .md + HTML deck, extracts recall data, compares against the current recall card, and returns drift findings plus the new card HTML. In assemble mode takes all new card HTML blocks and writes the final system-design-recall.html. Invoked by philosophy-sync-recall-html skill.
tools: Read, Write, Glob
---

You handle ONE scenario card at a time (or final assembly). The prompt will specify:
- **Mode:** `diff` or `assemble`
- In `diff` mode: scenario name, scenario .md path, HTML deck path
- In `assemble` mode: the full set of new card HTML blocks (keyed by scenario) + approved scenario list

---

## Mode: diff

### Step 1 — Read source files

Read:
1. `docs/deck/system-design-recall.html` — the current recall page (to extract the existing card for this scenario)
2. The scenario `.md` at the specified path
3. The HTML deck at the specified path

### Step 2 — Extract recall data from the scenario .md

#### 2a. Scenario tag (subtitle)
Derive the `.scenario-tag` text from:
- The `## Delta` table's scenario-unique concepts
- The "Key decisions unique to this scenario" bullets

Keep it under 6 concepts. Prefer nouns over verbs. Separate with ` · `.

#### 2b. Key flows (table rows)
Extract flows from the `## Data Flow` section — one `###` heading = one flow = one row.
If `## Data Flow` is absent or sparse, fall back to `<tr class="f*">` rows in the HTML deck.

**Flow color assignment:**

| Class | Color | When to use |
|---|---|---|
| `f1` | Blue | Read / Load — initial page loads, cache reads, library fetches |
| `f2` | Orange | Write / Mutation — POST, PATCH, user-initiated writes |
| `f3` | Green | Real-time / Streaming — WebSocket receive, SSE, live updates |
| `f4` | Red | Offline / Background — sync queues, offline playback, retry on foreground |
| `f5` | Purple | Special / Infrastructure — payment gateway, timers, auth, system-level |

#### 2c. Layer column structure

**Each layer column is a single tall cell** (`rowspan="N"` where N = number of flows). Components are listed top-to-bottom inside that one cell — never split across per-flow rows. Only the `lbl` (first) column has one row per flow.

Each component block is wrapped in `<div class="comp">`:
```html
<div class="comp">
  <span class="chip ...">ComponentName</span>
  <div class="flow-dots"><span class="flow-dot" style="background:var(--accent)"></span></div>
  <div class="sub">optional note</div>
</div>
```

**External column** — one `Storage` chip, then one `API` chip:
- **One `Storage` chip** (`.chip.st`, dashed) covers all local persistence for this scenario — each backing store goes as a separate `.sub` line (e.g. `CoreData — search cache`, `disk file:// — offline tracks`)
- **One `API` chip** (`.chip.ep`) covers all network endpoints — each path goes as a separate `.sub` line (e.g. `GET /me/library?cursor=&sort=`, `POST /orders`)
- Flow-dots on each `.comp` show which flows use that chip (union of all flows that touch any of its sub-entries)
- Use `—` only if no storage and no network involved

**Infrastructure column** — Gateway / SDK wrapper:
- One `.comp` per component: `APIClient`, `WebSocketClient`, `SSEClient`, `AVPlayer`, `StripePaymentGateway`, `NWPathMonitor`, `Timer (Foundation)` — always `.chip.infra`
- Flow-dots show which flows use it
- Sub-label: the key constraint or protocol it implements
- Use `—` if no infrastructure component is involved

**Data column** — Repository + DataSource(s):
- Repository: `.chip` (solid border) — always domain-prefixed (`RestaurantRepo`, `MessageRepo`)
- DataSource(s) are sub-labels under their Repository `.comp`, not separate chips
- Use `—` if this scenario bypasses the Repo/DS layer

**Domain column** — UseCase or Domain Service:
- UseCase: `.chip` (solid) — stateless, one-shot
- Service: `.chip.svc` (dashed) — stateful, long-lived
- Flow-dots show which flows invoke it
- Sub-label: key behaviour note (e.g. `app-scoped · AnyPublisher<Order, AppError>`)

**Presentation column** — ViewModel or ViewController:
- One `.comp` per named ViewModel/ViewController
- Flow-dots show which flows drive it
- Sub-label: key pattern if recall-worthy

### Step 3 — Chip type and rowspan rules

**Chip types:**

| Component type | Column | CSS class | Border |
|---|---|---|---|
| UseCase, Repository | Data / Domain | `.chip` | solid |
| Service (Domain), DataSource | Data / Domain | `.chip.svc` / `.chip.ds` | dashed |
| Infrastructure Gateway/SDK | Infrastructure | `.chip.infra` | solid, purple tint |
| Network endpoint | External | `.chip.ep` | solid, neutral |
| Storage / DB | External | `.chip.st` | dashed, neutral |
| Shared (spans multiple flows) | any | `.chip.shared` | neutral + flow dots |

**Unique component rule:** Each named component must appear as a chip at most once per column in the card.
- Consecutive flows sharing a component → rowspan (see below)
- Non-consecutive flows where the component is the **primary** entry in the cell → first occurrence is the chip; later rows use `<span class="ref-badge">↑</span>` inline after the chip name
- Non-consecutive flows where the component is **secondary** (cell already has another primary chip) → do not repeat the chip; fold the reuse into a `.sub` line under the primary chip (e.g. `FeedLocalDS — Like{successfullySent=false}`)
- Per-flow sub-labels for a shared component are stacked as separate `.sub` lines under the single chip

**Rowspan:** Every layer column (`col-external`, `col-infra`, Data, Domain, Presentation) uses `rowspan="N"` on the `<td>` where N = total flow rows in the card. The `lbl` column never rowspans — one row per flow.

**Non-consecutive reuse within a `.comp`:** not applicable under the tall-cell model — each component appears exactly once.

### Step 4 — Diff against current recall card

Extract the existing `<div class="scenario-card">` block for this scenario from `system-design-recall.html`.

Compare extracted data (Step 2) against what's in the current card. Report only real drift — intentional abbreviations are NOT drift:
- `FetchRestaurantsUseCase` → `FetchRestaurantsUC` ✅ (ok abbreviation)
- `RestaurantRepository` → `RestaurantRepo` ✅ (ok abbreviation)
- `RestaurantRemoteDataSource` → `RestaurantRemoteDS` ✅ (ok abbreviation)
- Sub-labels absent from the recall card ✅ (recall is intentionally condensed)

**Flag as drift:**
- A component name changed (rename, not abbreviation)
- An endpoint path changed
- A flow was added to the `.md` but is absent from the recall card
- The scenario tag is missing a concept from the `.md` delta table
- A chip type is wrong (solid vs dashed, wrong color class)
- A layer cell has `—` in the recall but has a real component in the `.md` (or vice versa)
- Layer columns are not tall cells (per-flow `<td>`s instead of one `rowspan="N"` cell)
- Multiple storage chips instead of a single `Storage` chip with `.sub` lines
- Network endpoints are listed as individual chips instead of a single `API` chip with `.sub` lines
- A `.comp` wrapper is missing around a chip + flow-dots + sub block

### Step 5 — Return

Return:
1. **Drift report** for this scenario
2. **New card HTML** (the full `<div class="scenario-card">...</div>` block) — generated even if there's no drift, so the assembler can place it

```
### Scenario: <name>
**Drift:** None / Minor / Significant

Changes:
- <finding 1>
- <finding 2>
- (none)

**New card HTML:**
<div class="scenario-card">
  ...
</div>
```

---

## Mode: assemble

The prompt will provide:
- **Approved scenarios:** list of scenario names to update
- **New card HTML per scenario:** the card HTML blocks returned by individual diff workers
- **Unapproved scenarios:** their card HTML must be copied verbatim from the current file

### Step 1 — Read the current recall HTML

Read `docs/deck/system-design-recall.html`.

### Step 2 — Assemble the updated file

Replace each approved scenario's `<div class="scenario-card">` block with the new card HTML from the prompt.
Copy all unapproved scenario card blocks verbatim from the file read in Step 1.

**Card order must always be preserved:**
1. Uber Eats
2. Messenger
3. Music Streaming
4. Instagram News Feed
5. Hotel Booking
6. Story Viewer

**Never touch:** `<head>`, `<nav>`, `<header>`, `.legend`, `.chip-legend` sections.

**Row borders:** `.arch-table tbody tr` must NOT have `border-bottom`. Flow rows are visually separated by the left-border color on `.flow-name` only. If the `<style>` block still contains that rule, remove it (and its `tr:last-child` companion) during assembly.

### Step 3 — Write the updated file

Write the full updated `docs/deck/system-design-recall.html`.

### Step 4 — Return

```
## Assembled — system-design-recall.html

### Updated cards
| Scenario | Flows | Changes |
|---|---|---|
| <name> | <count> | <summary> |

### Unchanged cards
<list of cards written back verbatim>
```
