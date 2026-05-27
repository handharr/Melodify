---
name: philosophy-audit-scenarios
description: Read-only audit of all docs/scenarios/ files against docs/ios-app-system-design-philosophy.md. Reports stale naming, missing delta coverage, layer violations, and HTML sync drift. Makes no changes.
user-invocable: true
---

Audit all scenario docs in `docs/scenarios/` against the generic iOS architecture in `docs/ios-app-system-design-philosophy.md`. This is a read-only skill — report findings only, make no changes.

## Step 1 — Read all files

Read:
1. `docs/ios-app-system-design-philosophy.md` — the source of truth for naming, patterns, and layer rules
2. Every `.md` file in `docs/scenarios/`
3. Every corresponding HTML at `docs/deck/<scenario-name>.html` — to check HTML sync

## Step 2 — Run per-scenario checks

For each scenario doc, check all of the following:

### 2a. Delta section completeness
- Does a `## Delta` section exist?
- Does it have a "Same as generic architecture" list?
- Is the "same" list actually accurate against the current generic doc? (e.g. if the generic doc added `FetchPolicy` but the scenario's "same" list doesn't mention it, flag it)
- Does the delta table cover all scenario-specific components? (nothing scenario-specific should be listed as "same")
- Are "Key decisions unique to this scenario" present?

### 2b. Naming convention alignment
Check every component name against the generic architecture doc's conventions:
- Remote access layer named `*RemoteDataSource` (not `APIClient`, `Service`, `Manager`, `Store`) — and always domain-prefixed (e.g. `RestaurantRemoteDataSource`, not bare `RemoteDataSource` as a class name)
- Local access layer named `*LocalDataSource` (not `Store`, `Cache`, `DB`) — always domain-prefixed (e.g. `MessageLocalDataSource`, not bare `LocalDataSource` as a class name in layer breakdowns, data flows, or code examples)
- Business logic named `*UseCase` (stateless) or `*Service` (stateful Domain Service)
- Data transfer objects named `*DTO`
- Conversion types named `*Mapper`
- Navigation named `*Coordinator`
- Infrastructure wrappers named `*Gateway` (never `*Manager`, `*Service`, or `*DataSource` for SDK facades) — always vendor-prefixed (e.g. `StripePaymentGateway`, not bare `Gateway`)

Flag any deviation with the correct term.

**Exception:** bare `LocalDataSource` / `RemoteDataSource` is acceptable in: the delta table's "Generic" column (describing what the base arch provides), pattern-level warning callouts, and type-annotation diagrams showing which layer uses which access style. It is NOT acceptable as a class name in layer breakdowns, data flow pseudocode, or vocabulary mapping tables.

### 2e. Redundant generic content
Check both the `.md` and its HTML for explanations that belong only in `ios-app-system-design.md`, not in a scenario deck:

**Flag as ❌ Redundant** if the scenario contains any of the following generic-only sections:
- "Why MVVM over MVP?" explanation
- "Why MVVM over VIPER?" explanation
- "Why Clean Architecture over MVC?" explanation
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?" explanation
- "UseCase vs Domain Service" comparison table (with columns: Triggered by / State / Has I/O? / Lifetime)
- "Domain Service vs Gateway" comparison table

**Scenario-specific reasoning is fine** — e.g. "Why UIKit over SwiftUI for THIS scenario" (AVPlayerViewController, scroll lifecycle), "Why GRDB for this app", "Why SSE over polling for this use case", "Why manual DI over Swinject (what the reference video uses)".

The test: would this exact explanation appear unchanged in every other scenario? If yes, it's generic and must be removed from the scenario deck.

### 2f. Architecture section — end-to-end component coverage

The `## Architecture` section must always list all five layers in order: **Presentation → Domain → Data → Infrastructure → External**. Every layer must appear, even if unused — unused layers are marked `None`. This makes the section scannable in an interview without the reader having to guess what was considered.

Required structure:

```
Presentation
  <named ViewControllers and ViewModels>

Domain
  UseCases: <named, one per user action or screen load>
  Services: <named Domain Services, or None>
  Models: <named Domain Models and Param structs>

Data
  Repositories: <named, one per aggregate>
  DataSources: <named RemoteDataSource and LocalDataSource per Repository, domain-prefixed>
  DTOs / Mappers: <named>

Infrastructure
  Gateways: <named vendor-prefixed Gateways, or None>

External
  SDKs / Frameworks: <named, e.g. Stripe, CoreData, AVFoundation — or None>
```

Flag as ❌ if:
- Any of the five layers is missing entirely from the Architecture section
- A layer that has no components is omitted instead of showing `None`
- The section only contains a general pattern statement with no named components
- DataSources are listed without domain prefix (bare `RemoteDataSource` / `LocalDataSource`)

Flag as ⚠️ if:
- All five layers are present but one or more sublists (e.g. Services, DTOs) are missing while components for that sublayer clearly exist in the scenario

### 2g. External SDK wrapper compliance

For every External SDK or framework listed in the scenario's Architecture section:

1. **No-wrapper exceptions: UIKit, SwiftUI, Combine only** — these are the UI and reactive primitives, appearing in every file by design. Flag if any other SDK (including Apple's own AVFoundation, CoreData, URLSession) is used directly without a wrapper. "Apple-made" is not the criterion — "bounded scope" is.
2. **Always wrap:** every other SDK must have a named wrapper somewhere in the codebase.
3. **Wrapper placement:** count how many layers the wrapper touches:
   - One layer only:
     - Data networking → `APIClient` / `WebSocketClient` in Data (e.g. URLSession → `APIClient`, URLSessionWebSocketTask → `WebSocketClient`)
     - Data persistence → `*LocalDataSource` in Data (e.g. CoreData → `TrackLocalDataSource`)
     - Domain logic → `*Service` in Domain (e.g. AVFoundation → `PlayerService`)
   - Two or more layers → `*Gateway` in Infrastructure (e.g. Stripe spans Presentation + Data → `StripePaymentGateway`)

Flag as ❌ if:
- An External SDK (other than SwiftUI/UIKit/Combine) is imported directly in Domain or Presentation without a wrapper
- A multi-layer SDK is wrapped as a `DataSource` or `Service` instead of a `Gateway`
- A single-layer SDK is wrapped as a `Gateway` when it only touches one layer

Flag as ⚠️ if:
- An External SDK is listed but no wrapper name is given (unclear where it lives)

### 2c. Layer dependency rule
Check that the dependency rule holds: **Presentation → Domain ← Data. Infrastructure conforms to Domain protocols. Domain depends on nothing. External is the outermost ring — only wrapper layers (Gateway, DataSource, Service) import from it; nothing in Domain or Presentation touches External directly.**

Flag:
- ViewModels calling Repositories directly (should go via UseCase)
- UseCases referencing network types (should use Repository protocol)
- Repositories returning DTOs beyond their own layer (should map first)
- Domain models mentioning UIKit or networking types

### 2d. HTML sync drift (both .md and .html)
Compare the scenario `.md` section structure against its HTML:
- Does the HTML have all sections present in the `.md`?
- Does the HTML delta table match the `.md` delta table?
- Is the HTML missing or has extra content not in the `.md`?

Mark as:
- ✅ In sync
- ⚠️ Minor drift (small content differences)
- ❌ Out of sync (structural differences or missing sections)

## Step 3 — Produce the audit report

Output a structured report. Format:

```
## Audit Report — <date>

### docs/ios-app-system-design-philosophy.md
<version summary — what patterns/conventions are currently defined>

---

### Scenario: <scenario name>
**File:** docs/scenarios/<filename>.md
**HTML:** docs/deck/<filename>.html

#### Delta Section
✅ / ⚠️ / ❌ <finding>

#### Architecture — End-to-End Coverage
✅ / ⚠️ / ❌ <finding per missing or incomplete layer>

#### Naming Conventions
✅ / ⚠️ / ❌ <finding per violation>

#### Layer Dependency Rule
✅ / ⚠️ / ❌ <finding per violation>

#### HTML Sync
✅ In sync / ⚠️ Minor drift / ❌ Out of sync
<list of drifted sections if any>

#### Action Required
- [ ] <specific fix needed>
- [ ] <specific fix needed>
```

End the report with a summary table:

| Scenario | Delta | Arch Coverage | Naming | Layers | HTML Sync | Redundant Content | Actions |
|---|---|---|---|---|---|---|---|
| music-streaming | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | None |
| (next scenario) | ... | ... | ... | ... | ... | ... | ... |

## Step 4 — Recommend next steps

Based on findings, recommend which skill to run:
- Naming or layer violations → `/philosophy-refactor-scenario-design` to clean up the scenario
- HTML out of sync → `/philosophy-sync-scenario-html` on the affected file
- Delta stale against generic doc → `/philosophy-sync-scenarios` to propagate arch changes
