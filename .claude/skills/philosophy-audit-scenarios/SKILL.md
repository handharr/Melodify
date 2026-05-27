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

### 2c. Layer dependency rule
Check that the dependency rule holds: **Presentation → Domain ← Data. Infrastructure conforms to Domain protocols. Domain depends on nothing.**

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

| Scenario | Delta | Naming | Layers | HTML Sync | Redundant Content | Actions |
|---|---|---|---|---|---|---|
| music-streaming | ✅ | ✅ | ✅ | ✅ | ✅ | None |
| (next scenario) | ... | ... | ... | ... | ... | ... |

## Step 4 — Recommend next steps

Based on findings, recommend which skill to run:
- Naming or layer violations → `/philosophy-refactor-scenario-design` to clean up the scenario
- HTML out of sync → `/philosophy-sync-scenario-html` on the affected file
- Delta stale against generic doc → `/philosophy-sync-scenarios` to propagate arch changes
