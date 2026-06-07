# Scenario Conventions

Machine-readable rules for all three doc types:
- `docs/SystemDesign/<App>/<App>SystemDesign.md` — system design markdown docs
- `docs/deck/SystemDesign/<App>SystemDesign.html` — system design HTML decks
- `docs/deck/system-design-recall.html` — recall card with SVG connection arcs

Apps: `MusicApp`, `ChatApp`, `CoreKit`, `MelodifyDesignSystem`

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

Full-stack apps (MusicApp, ChatApp) cover all 6 layers. SPM packages (CoreKit, MelodifyDesignSystem) omit layers they genuinely don't have — mark unused layers `None` or omit the row.

Layer order (top to bottom in docs): **Presentation → Domain → Data → Application → Infrastructure → External**

**Domain sublayers** (always grouped in this order):
1. UseCases
2. Services (or `None`)
3. Specs (or `None`) — pure stateless business logic; `Domain/Specs/`
4. Models
5. Requests

**Data sublayers** (always grouped in this order):
1. Repositories
2. DataSources
3. DTOs
4. Mappers

**Infrastructure:** `<Vendor>Gateway` conforms to `<Domain>GatewayProtocol` defined in Domain. Or `None`.

**External:** SDK names only — no wrapper class names here.

---

## Section 3b — Dependencies Layer and Component Annotations

### Dependencies layer

The bottom layer of every High-Level Design diagram is always named **`Dependencies`** — never `CoreKit`, `External`, or `Infrastructure`.

It lists every external SDK or SPM package that any layer in the app imports, one line per framework:

```
│  Dependencies                                                       │
│  CoreKit             WebSocketClient · APIClient · ChannelRouter    │
│  CoreData            NSPersistentContainer · NSFetchRequest         │
│  Network             NWPathMonitor                                  │
│  BackgroundTasks     BGTaskScheduler · BGAppRefreshTask             │
│  UserNotifications   APNs silent push handling                      │
```

Rules:
- Internal SPM packages (e.g. `CoreKit`) listed before Apple frameworks
- List only frameworks with non-obvious usage; omit `Foundation` and `UIKit` unless a specific type (e.g. `FileManager`) needs calling out
- Each line: `FrameworkName   Type1 · Type2` — dot-separated type list, no parentheses

### Component dependency annotations

Any **Data layer** component that wraps or directly imports an external dependency carries an inline bracket annotation on the same line:

```
│  MessageLocalDataSource               [CoreData]                    │
│  MessageRemoteDataSource              [CoreKit · APIClient]         │
│  PendingMessageQueue (actor)          [Foundation · FileManager]    │
│  ConnectionManager (actor)            [CoreKit · WebSocketClient    │
│                                        Network · NWPathMonitor]     │
```

Format: `[FrameworkName · TypeName]` — comma-free, dot-separated. Multi-line wrap is allowed for long annotations; indent continuation to align with the opening bracket.

**Application layer** components also carry annotations for OS-level frameworks they register or observe:

```
│  ChatCoordinator              [UIKit · BackgroundTasks ·            │
│                                UserNotifications]                   │
```

**Domain layer** components must never carry dependency annotations — Domain depends on nothing. Any annotation on a Domain component is a layer violation.

**Presentation layer** UIKit/Combine dependency is noted once in the layer header `(UIKit · Combine)`, not per component.

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

Remove from system design `.md` files — belongs only in the philosophy doc:

- "Why MVVM over MVP?" / "Why MVVM over VIPER?"
- "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- "UseCase vs Domain Service" comparison table
- "Domain Service vs Gateway" comparison table

**Test:** would this exact explanation appear unchanged in every other app? If yes → generic → remove.

---

## Section 6 — Technical Deep-dive Requirements

Every system design `.md` must contain this section with this exact structure:

```markdown
## 6. Technical Deep-dive

### Why [specific question unique to this app]?
[rationale — scenario-specific only; see Section 5 blocklist]

### Why [another specific question]?
[rationale]

...one ### subsection per key decision...

### Interview Q&A

| Question | Answer |
|---|---|
```

Rules:
- All "why" rationale, trade-offs, and "X over Y" decisions belong **exclusively** here
- Sections 1–5 are pure design — no rationale paragraphs, no bold **Why?** sentences
- Every `### Why` subsection must be scenario-specific (blocklist test: would it appear unchanged in every other app? If yes → remove)
- The `### Interview Q&A` table is always the last subsection
- Minimum 3 `### Why` subsections per app; typical range 5–7

---

## Section 9 — HTML Deck: Delta Section

Every `docs/deck/SystemDesign/<App>SystemDesign.html` must include a `#delta` section as the **first section** of the deck (before `#requirements`).

### Purpose

A compact, at-a-glance summary of the architectural decisions unique to this app — what this scenario adds to or deviates from the generic architecture in `docs/ios-app-system-design-philosophy.md`. It is a quick-reference surface for interview prep, not a duplicate of the full rationale in `#technical-deep-dive`.

### Content source

Each `### Why` subsection in `## 6. Technical Deep-dive` of the app's `.md` maps to one delta card. The `### Interview Q&A` table is **not** included here — it stays in `#technical-deep-dive` only.

### Card count

5–8 cards. If there are more `### Why` subsections than 8, prioritise by interview relevance — decisions most likely to be challenged in a live session first.

### HTML structure

```html
<section id="delta">
  <h2>Delta — Key Decisions</h2>
  <div class="delta-grid">
    <div class="delta-card">
      <div class="delta-topic">Short label (3–6 words)</div>
      <div class="delta-decision">The key decision — one line</div>
      <div class="delta-rationale">One-sentence why — scenario-specific only</div>
    </div>
    <!-- one .delta-card per selected ### Why subsection, max 8 -->
  </div>
</section>
```

### Field rules

| Field | Source | Format |
|---|---|---|
| `delta-topic` | `### Why` heading, distilled | 3–6 words, no "Why" prefix (e.g. `Transport split`, `Message ordering`) |
| `delta-decision` | First sentence / key claim of the `### Why` body | One line; use `·` as separator for compound decisions |
| `delta-rationale` | One sentence from the `### Why` body | Must pass Section 5 blocklist test — scenario-specific only |

### Generic content rule

Every `delta-rationale` must pass the **Section 5 blocklist test**: if the sentence would appear unchanged in every other app (e.g. "Why Clean Architecture?", "Why MVVM?"), omit the card entirely. The delta section must contain zero generic rationale.

---

## Section 7 — Recall Diagram: Chip ID Convention

`system-design-recall.html` renders SVG bezier arcs between chips. Every chip
that participates in a connection arc must carry an `id` attribute.

### ID scheme

```
{app-prefix}-{component-kebab-name}
```

| App                    | Prefix |
|------------------------|--------|
| MusicApp               | `mus`  |
| ChatApp                | `cha`  |
| CoreKit                | `ck`   |
| MelodifyDesignSystem   | `mds`  |

Examples: `id="mus-track-repo"`, `id="cha-msg-stream-svc"`, `id="ck-ws-client"`

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

When adding a new app:
1. Choose a unique prefix (2–4 chars, lowercase, no hyphens)
2. Add the prefix to the table above
3. Add chip IDs to all connection-participant chips
4. Add all flow paths to `PATHS`, grouped with a comment header
5. Apply `.col-groups` sub-grouping to Data and Domain columns

---

## Section 8 — Recall Diagram Fidelity Rules

`system-design-recall.html` must faithfully reflect the layer structure in the corresponding
app `.md` and `docs/deck/SystemDesign/<App>SystemDesign.html`. It is a compressed view — not a simplified one.
Compression is allowed (fewer rows, merged sub-text); architectural shortcuts are not.

### Layer chain fidelity

Every named intermediate component in the `.md` architecture must appear as its own chip
in the recall card. Absorbing it into a neighbour's sub-text and skipping it in `PATHS` is a violation.

| Violation | Correct |
|---|---|
| `CoreData → Repository` arc (LocalDS skipped) | `CoreData → LocalDS → Repository` arc |
| LocalDS mentioned only in Repository sub-text | LocalDS has its own `chip ds` in the DataSource group |
| `API → Repository` arc (RemoteDS skipped) | `API → APIClient → RemoteDS → Repository` or `API → APIClient → Repository` when RemoteDS is not a named separate class |

**Rule:** if a component has a named class in the app's `.md` (e.g. `TrackLocalDataSource`,
`MessageLocalDataSource`), it must be a chip in the recall card with its own `id` and appear in `PATHS`.

### External chip naming

Use the concrete technology name, never a generic label:

| Generic (banned) | Concrete (required) |
|---|---|
| `Storage` | `CoreData`, `Realm`, `GRDB`, `SQLite` |
| `Database` | `CoreData`, `Realm`, etc. |
| `Cache` | the actual backing store |
| `Network` | `URLSession` (or omit — already implied by `APIClient`) |

**Exception:** `API` and `Storage` are acceptable only as the chip label in the `API` endpoint group
and as a fallback when the app genuinely uses multiple storage backends with no single name.

### PATHS completeness check

Before committing a recall card change, verify:
1. Every chip with an `id` that participates in a flow appears in at least one `PATHS` entry
2. No `PATHS` entry references an `id` that does not exist in the HTML
3. The left-to-right order of `ids` in each path matches the actual layer dependency direction
   (External → Data → Domain → Presentation)

### Sync trigger

Update `system-design-recall.html` whenever any of the following change in an app's `.md`:
- A component is added, removed, or renamed in the High-Level Design section (§4)
- A new flow is added or removed in the Data Flow section (§5)
- An endpoint is added or removed in the API Design section (§2)
