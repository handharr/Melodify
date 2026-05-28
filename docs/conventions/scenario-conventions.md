# Scenario Conventions

Machine-readable rules for all three scenario doc types:
- `docs/scenarios/*.md` — scenario markdown docs
- `docs/deck/scenarios/*.html` — scenario HTML decks
- `docs/deck/system-design-recall.html` — recall card with SVG connection arcs

Workers read this file at runtime. The philosophy doc (`docs/ios-app-system-design-philosophy.md`) is the human-readable narrative; this file is the authoritative rule set.

---

## Section 1 — Naming Conventions

| Component | Pattern | Example |
|---|---|---|
| Remote access | `<Domain>RemoteDataSource` — always domain-prefixed | `HotelRemoteDataSource` |
| Local / cache access | `<Domain>LocalDataSource` — always domain-prefixed | `MessageLocalDataSource` |
| Business logic (stateless) | `<Action>UseCase` | `FetchHotelDetailUseCase` |
| Business logic (stateful) | `<Domain>Service` | `ReservationService` |
| Data transfer object | `<Domain>DTO` | `HotelListingDTO` |
| Conversion | `<Domain>Mapper` | `HotelListingMapper` |
| Navigation | `<Scope>Coordinator` | `AppCoordinator`, `ChatCoordinator` |
| Infrastructure wrapper | `<Vendor><Domain>Gateway` — vendor-prefixed | `StripePaymentGateway` |

**Exception:** bare `LocalDataSource` / `RemoteDataSource` is acceptable only in:
- Delta table "Generic" column
- Pattern-level callouts (e.g. "every repo has a LocalDataSource and a RemoteDataSource")
- Type-annotation diagrams

Never as a class name in layer breakdowns, data flows, component tables, or vocabulary tables.

---

## Section 2 — Layer Dependency Rule

```
Presentation → Domain ← Data
Infrastructure conforms to Domain protocols
Domain depends on nothing
External is the outermost ring — only wrapper layers import from it
```

Violations to flag:
- Any Presentation component (ViewController, ViewModel) accesses a Data layer component (Repository, DataSource, DTO, Mapper) directly — must go via UseCase
- UseCase accesses DataSource directly — must go via Repository
- UseCase references network types (URLSession, URLRequest, etc.) — must use Repository protocol
- Repository returns DTO beyond its own layer — must map to Domain model first
- Domain model imports UIKit or Foundation networking types

---

## Section 3 — Architecture Layer Structure

Every scenario must cover all 5 layers. Unused layers marked `None`.

Layer order (top to bottom in docs): **Presentation → Domain → Infrastructure → Data → External → Application**

**Domain sublayers** (always grouped in this order):
1. UseCases
2. Services (or `None`)
3. Models
4. Params

**Data sublayers** (always grouped in this order):
1. Repositories
2. DataSources
3. DTOs
4. Mappers

**Infrastructure:** `<Vendor>Gateway` conforms to `<Domain>GatewayProtocol` defined in Domain. Or `None`.

**External:** SDK names only — no wrapper class names here.

---

## Section 4 — SDK Wrapper Placement

| SDK footprint | Wrap as | Layer |
|---|---|---|
| Touches one layer only (data access) | `DataSource` / `APIClient` / `WebSocketClient` | Data |
| Touches one layer only (Domain logic) | `Service` | Domain |
| Touches two or more layers | `<Vendor>Gateway` | Infrastructure |
| UIKit / SwiftUI / Combine | No wrapper needed | — |

**No-wrapper exceptions: UIKit, SwiftUI, Combine only.** All other SDKs must always be wrapped.

---

## Section 5 — Generic Content Blocklist

Remove from scenario `.md` files — belongs only in the philosophy doc:

- "Why MVVM over MVP?" / "Why MVVM over VIPER?"
- "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- "UseCase vs Domain Service" comparison table
- "Domain Service vs Gateway" comparison table

**Test:** would this exact explanation appear unchanged in every other scenario? If yes → generic → remove.

---

## Section 6 — Delta Section Requirements

Every scenario `.md` must contain this section with this exact structure:

```markdown
## Delta — What This Scenario Adds

### Same as generic architecture
- (bullet list — patterns shared with every other scenario)

### What this scenario adds
| Concept | Generic | This Scenario |
|---|---|---|

### Key decisions unique to this scenario
- (bullet list — the "why" for each delta item)
```

Rules:
- Nothing scenario-specific in the "Same as generic" list
- Nothing generic in the delta table
- Every row in the delta table must have a corresponding bullet in "Key decisions"

---

## Section 7 — Recall Diagram: Chip ID Convention

`system-design-recall.html` renders SVG bezier arcs between chips. Every chip
that participates in a connection arc must carry an `id` attribute.

### ID scheme

```
{scenario-prefix}-{component-kebab-name}
```

| Scenario            | Prefix |
|---------------------|--------|
| Uber Eats           | `ue`   |
| Messenger           | `ms`   |
| Music Streaming     | `mst`  |
| Instagram News Feed | `ig`   |
| Hotel Booking       | `hb`   |
| Story Viewer        | `sv`   |

Examples: `id="ue-basket-repo"`, `id="ms-msg-stream-svc"`, `id="hb-stripe"`

### PATHS array

The `const PATHS` array inside the diagram's `<script>` block is the authoritative
connection graph. Each entry:

```js
{ flow: 'f1', ids: ['chip-a', 'chip-b', 'chip-c'] }
```

A bezier arc is drawn between every adjacent pair in `ids`, left-to-right through layers.
Flow IDs map to colours: `f1` blue, `f2` orange, `f3` green, `f4` red, `f5` purple.

### Column sub-grouping (Data and Domain columns)

Data and Domain `<td>` cells use a `.col-groups` flex-row wrapper to visually separate
component types. Groups are rendered left-to-right in dependency order.

**Data column group order:** `Client` → `DataSource` → `Repository`
- `Client` — `APIClient`, `WebSocketClient`, `SSEClient` (infra chip, lives in Data)
- `DataSource` — `chip ds` (dashed) components only
- `Repository` — `chip` (solid) repo components

**Domain column group order:** `UseCase` → `Service`
- `UseCase` — `chip` (solid, non-`svc`) components
- `Service` — `chip svc` (dashed) components

Only render a group `<div class="col-group">` when it contains at least one chip.
Single-group cells still use the `.col-groups` wrapper (consistent structure, label
helps orient the reader).

HTML structure:
```html
<div class="col-groups">
  <div class="col-group">
    <div class="col-group-label">GroupName</div>
    <div class="comp">…chip…</div>
  </div>
</div>
```

### Maintenance rules

When adding or renaming a chip in `system-design-recall.html`:
1. Add/update `id="{prefix}-{name}"` on the chip `<span>`
2. Add/update the corresponding entry in `PATHS`
3. Place the chip in the correct sub-group within its column

When adding a new scenario:
1. Choose a unique prefix (2–4 chars, lowercase, no hyphens)
2. Add the prefix to the table above
3. Add chip IDs to all connection-participant chips
4. Add all flow paths to `PATHS`, grouped with a comment header
5. Apply `.col-groups` sub-grouping to Data and Domain columns

---

## Section 8 — Recall Diagram Fidelity Rules

`system-design-recall.html` must faithfully reflect the layer structure in the corresponding
scenario `.md` and `docs/deck/scenarios/*.html`. It is a compressed view — not a simplified one.
Compression is allowed (fewer rows, merged sub-text); architectural shortcuts are not.

### Layer chain fidelity

Every named intermediate component in the `.md` architecture must appear as its own chip
in the recall card. Absorbing it into a neighbour's sub-text and skipping it in `PATHS` is a violation.

| Violation | Correct |
|---|---|
| `CoreData → Repository` arc (LocalDS skipped) | `CoreData → LocalDS → Repository` arc |
| LocalDS mentioned only in Repository sub-text | LocalDS has its own `chip ds` in the DataSource group |
| `API → Repository` arc (RemoteDS skipped) | `API → APIClient → RemoteDS → Repository` or `API → APIClient → Repository` when RemoteDS is not a named separate class |

**Rule:** if a component has a named class in the scenario `.md` (e.g. `RestaurantLocalDataSource`,
`MessageStreamDataSource`), it must be a chip in the recall card with its own `id` and appear in `PATHS`.

### External chip naming

Use the concrete technology name, never a generic label:

| Generic (banned) | Concrete (required) |
|---|---|
| `Storage` | `CoreData`, `Realm`, `GRDB`, `SQLite` |
| `Database` | `CoreData`, `Realm`, etc. |
| `Cache` | the actual backing store |
| `Network` | `URLSession` (or omit — already implied by `APIClient`) |

**Exception:** `API` and `Storage` are acceptable only as the chip label in the `API` endpoint group
and as a fallback when the scenario genuinely uses multiple storage backends with no single name.

### PATHS completeness check

Before committing a recall card change, verify:
1. Every chip with an `id` that participates in a flow appears in at least one `PATHS` entry
2. No `PATHS` entry references an `id` that does not exist in the HTML
3. The left-to-right order of `ids` in each path matches the actual layer dependency direction
   (External → Data → Domain → Presentation)

### Sync trigger

Update `system-design-recall.html` whenever any of the following change in a scenario:
- A component is added, removed, or renamed in the `.md` Layer Breakdown
- A new flow row is added or removed in the `.md` Data Flow section
- An endpoint is added or removed in the `.md` API Design section
