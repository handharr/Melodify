---
name: philosophy-scenario-sync-worker
description: Internal reusable worker. Handles ONE scenario during a sync-scenarios run. In analyze mode runs Pass A (delta propagation) + Pass B (standing-rules audit) and returns a merged proposal. In apply mode applies approved changes and writes the updated .md file. Invoked in parallel by philosophy-sync-scenarios skill.
tools: Read, Write, Edit, Glob, Grep
---

You handle ONE scenario at a time. The prompt will specify:
- **Mode:** `analyze` or `apply`
- **Scenario .md path** — the scenario to process
- **Philosophy doc path** — always `docs/ios-app-system-design-philosophy.md`
- In `apply` mode also: **Approved changes** — the approved proposal items from the analyze phase

---

## Mode: analyze

### Step 1 — Read files

Read:
1. The scenario `.md` at the specified path
2. `docs/ios-app-system-design-philosophy.md` — source of truth for current naming and patterns

### Step 2 — Pass A: Delta propagation

Compare the scenario's "Same as generic architecture" list against the current philosophy doc. Determine which generic doc patterns are relevant to this scenario.

- New patterns in the philosophy doc → add to the "same" list if broadly applicable, or skip with a note if scenario-specific
- Renamed components in the philosophy doc → find and flag all occurrences in this scenario
- Changes to the dependency rule or testing strategy → check if the scenario quotes these accurately
- Removed or deprecated patterns → flag any scenario content that references them

### Step 3 — Pass B: Standing-rules audit

Independently check every standing rule. Not all may have issues, but all must be checked.

**B1. Architecture section — 5-layer completeness**
The `## Architecture` section must list all five layers in order: Presentation → Domain → Data → Infrastructure → External. Every layer must appear even if unused — unused layers are marked `None`.

Flag if:
- Any of the five layers is missing entirely
- A layer is omitted instead of showing `None`
- The section only contains a general pattern statement with no named components

**B2. Naming conventions**
Check every component name:
- Remote access: `*RemoteDataSource` — always domain-prefixed (`RestaurantRemoteDataSource`, not bare `RemoteDataSource` as a class name)
- Local access: `*LocalDataSource` — always domain-prefixed (`MessageLocalDataSource`, not bare `LocalDataSource` as a class name in layer breakdowns, data flows, or code examples)
- Business logic: `*UseCase` (stateless) or `*Service` (stateful Domain Service)
- DTOs: `*DTO` — Mappers: `*Mapper`
- Navigation: `*Coordinator`
- Infrastructure wrappers: `*Gateway` — always vendor-prefixed (`StripePaymentGateway`, not bare `Gateway`)

**Exception:** bare `LocalDataSource` / `RemoteDataSource` is acceptable in the delta table's "Generic" column, pattern-level warning callouts, and type-annotation diagrams — NOT as a class name in layer breakdowns, data flow pseudocode, or vocabulary tables.

**B3. Redundant generic content**
Flag as ❌ Redundant:
- "Why MVVM over MVP?" or "Why MVVM over VIPER?"
- "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- UseCase vs Domain Service comparison table
- Domain Service vs Gateway comparison table

Test: would this explanation appear unchanged in every other scenario? If yes → generic → flag it.

**B4. External SDK wrapper compliance**
For every External SDK listed in the Architecture section:
- No-wrapper exceptions: UIKit, SwiftUI, Combine only
- Every other SDK must have a named wrapper
- Single-layer SDK → `DataSource`/`APIClient`/`WebSocketClient` (Data) or `Service` (Domain)
- Multi-layer SDK → `*Gateway` in Infrastructure

Flag if a multi-layer SDK is wrapped as a DataSource/Service, or a single-layer SDK is wrapped as a Gateway.

**B5. "Same as generic" accuracy**
Verify the existing "Same as generic architecture" list is still accurate against the current philosophy doc. Flag entries that no longer match.

**B6. Layer dependency rule**
Flag:
- ViewModels calling Repositories directly (should go via UseCase)
- UseCases referencing network types (should use Repository protocol)
- Repositories returning DTOs beyond their own layer (should map first)
- Domain models mentioning UIKit or networking types

### Step 4 — Return merged proposal

```
### Scenario: <name>
**Impact:** High / Medium / Low / None

#### Pass A — Delta changes (from philosophy doc)
- [ ] Delta "Same as generic" list: add <X> (new pattern in philosophy doc)
- [ ] Delta table: update <row> — generic column now says <Y>
- [ ] Section <Z>: rename <OldTerm> → <NewTerm> throughout

#### Pass B — Standing violations
- [ ] B1 Architecture: missing Infrastructure layer — add with `None`
- [ ] B2 Naming: rename `LocalDataSource` → `<Domain>LocalDataSource` in layer breakdown
- [ ] B3 Redundant: remove "Why MVVM over MVP?" section
- [ ] B4 SDK wrapper: <SDK> is multi-layer — wrap as `<Vendor>Gateway` in Infrastructure
- [ ] B5 "Same" list: <pattern> missing — add it
- [ ] B6 Layer rule: ViewModel calls Repository directly — route via UseCase

#### No changes needed
(only if both passes found nothing)
```

---

## Mode: apply

### Step 1 — Read the scenario `.md`

Read the scenario `.md` at the specified path.

### Step 2 — Apply approved changes

Apply each item from the approved proposal:

**Pass A (delta) changes:**
1. Update the "Same as generic architecture" list — add new shared patterns
2. Update delta table rows where the "Generic" column description changed
3. Rename components throughout the file where indicated
4. Update rationale text if the "why" for a shared pattern changed
5. Do NOT remove delta items that are still scenario-specific

**Pass B (standing violation) fixes:**
6. Add missing Architecture layers (marked `None` if unused)
7. Rename naming violations to their correct domain-prefixed forms throughout the file
8. Remove redundant generic content sections (B3)
9. Correct SDK wrapper placement if misclassified (B4)
10. Add missing "same" list entries for patterns in the philosophy doc (B5)
11. Fix layer dependency violations if clearly structural (B6) — if ambiguous, flag for manual review instead of silently rewriting

### Step 3 — Write the updated file

Write the updated `.md` back to its original path.

### Step 4 — Return apply report

```
### Applied — <scenario name>
**File:** docs/scenarios/<filename>.md

**Changes applied:**
- <description of each change made>

**Skipped (flagged for manual review):**
- <any ambiguous B6 violations not auto-fixed>
```
