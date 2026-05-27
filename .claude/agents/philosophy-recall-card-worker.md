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

#### 2c. Per-flow layer data (table cells)

**External column** — merges Storage + Network (both are external concerns, not app layers):
- Show storage chip first (if any), then network chip — stacked vertically in the same `<td>`
- Storage: `CoreData`, `Realm`, `GRDB`, `disk file://`, `SDWebImage disk cache`, `Keychain`, `UserDefaults`
- Network: `GET /path`, `POST /path`, `WS /path`, `SSE /path`, etc.
- Sub-labels go immediately after the chip they annotate
- Use `—` only if neither storage nor network is involved

**Infrastructure column** — Gateway / SDK wrapper:
- Values: `APIClient`, `WebSocketClient`, `OrderSSEGateway`, `AVPlayer`, `StripePaymentGateway`, `NWPathMonitor`, `Timer (Foundation)` — always `.chip.infra`
- Sub-label: the protocol it implements or the key constraint
- Use `—` if no infrastructure component is involved

**Data column** — Repository + DataSource(s):
- Repository: `.chip` (solid border) — always domain-prefixed (`RestaurantRepo`, `MessageRepo`)
- DataSource(s): `.chip.ds` (dashed border) — always domain-prefixed (`RestaurantRemoteDS`, `MessageLocalDS`)
- Use `—` if this flow bypasses the Repo/DS layer

**Domain column** — UseCase or Domain Service:
- UseCase: `.chip` (solid) — stateless, one-shot
- Service: `.chip.svc` (dashed) — stateful, long-lived
- Sub-label: key behaviour note (e.g. `"app-scoped · AnyPublisher<Order, AppError>"`)
- Use `—` if a flow is presentation-only

**Presentation column** — ViewModel or ViewController:
- Named ViewModel as `.chip`
- Sub-label: key pattern if recall-worthy
- Use `—` only for flows explicitly infrastructure-only (no presentation component involved)

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

**Rowspan — use when:**
- The chip is the sole or primary component in the cell
- It appears in 2+ consecutive rows

Add `rowspan="N"`, render chip as `.chip.shared`, add `<div class="flow-dots">` with one `<span class="flow-dot">` per participating flow.

**Do not rowspan:**
- DataSource cells (per-flow sub-notes carry distinct recall details)
- External (network) cells (endpoints are always unique per flow)
- Mixed-component cells

**Non-consecutive reuse:** show the chip again in later rows followed by `<span class="ref-badge">↑</span>`.

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
- The recall card has separate Storage and Network columns instead of a single External column

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

**Never touch:** `<style>`, `<head>`, `<nav>`, `<header>`, `.legend`, `.chip-legend` sections.

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
