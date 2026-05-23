---
name: audit-scenarios
description: Read-only audit of all docs/scenarios/ files against docs/ios-app-system-design.md. Reports stale naming, missing delta coverage, layer violations, and HTML sync drift. Makes no changes.
user-invocable: true
---

Audit all scenario docs in `docs/scenarios/` against the generic iOS architecture in `docs/ios-app-system-design.md`. This is a read-only skill — report findings only, make no changes.

## Step 1 — Read all files

Read:
1. `docs/ios-app-system-design.md` — the source of truth for naming, patterns, and layer rules
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
- Remote access layer named `*RemoteDataSource` (not `APIClient`, `Service`, `Manager`, `Store`)
- Local access layer named `*LocalDataSource` (not `Store`, `Cache`, `DB`)
- Business logic named `*UseCase` (stateless) or `*Service` (stateful Domain Service)
- Data transfer objects named `*DTO`
- Conversion types named `*Mapper`
- Navigation named `*Coordinator`

Flag any deviation with the correct term.

### 2c. Layer dependency rule
Check that the dependency rule holds: **Presentation → Domain ← Data. Domain depends on nothing.**

Flag:
- ViewModels calling Repositories directly (should go via UseCase)
- UseCases referencing network types (should use Repository protocol)
- Repositories returning DTOs beyond their own layer (should map first)
- Domain models mentioning UIKit or networking types

### 2d. HTML sync drift
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

### docs/ios-app-system-design.md
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

| Scenario | Delta | Naming | Layers | HTML Sync | Actions |
|---|---|---|---|---|---|
| music-streaming | ✅ | ✅ | ✅ | ✅ | None |
| (next scenario) | ... | ... | ... | ... | ... |

## Step 4 — Recommend next steps

Based on findings, recommend which skill to run:
- Naming or layer violations → `/refactor-scenario-design` to clean up the scenario
- HTML out of sync → `/sync-scenario-html` on the affected file
- Delta stale against generic doc → `/sync-scenarios` to propagate arch changes
