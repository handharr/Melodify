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

### Maintenance rules

When adding or renaming a chip in `system-design-recall.html`, apply the same change
to `system-design-recall-diagram.html`:
1. Add/update `id="{prefix}-{name}"` on the chip `<span>`
2. Add/update the corresponding entry in `PATHS`

When adding a new scenario:
1. Choose a unique prefix (2–4 chars, lowercase, no hyphens)
2. Add the prefix to the table above
3. Add chip IDs to all connection-participant chips
4. Add all flow paths to `PATHS`, grouped with a comment header
