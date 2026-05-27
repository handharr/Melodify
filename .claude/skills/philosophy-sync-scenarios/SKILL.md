---
name: philosophy-sync-scenarios
description: Propagates changes from docs/ios-app-system-design-philosophy.md into all docs/scenarios/ files, and fixes any standing naming/layer/content violations found during the same pass. Proposes all changes per scenario before writing, then regenerates HTML for any changed scenario.
user-invocable: true
---

The generic architecture doc (`docs/ios-app-system-design-philosophy.md`) was updated. Your job is to propagate those changes into every scenario doc in `docs/scenarios/`, fix any standing violations found during the same pass, then regenerate the HTML for any scenario that changed.

This skill proposes changes per scenario before writing — it never silently overwrites.

## Step 1 — Read all files

Read:
1. `docs/ios-app-system-design-philosophy.md` — the updated generic architecture
2. Every `.md` file in `docs/scenarios/`

## Step 2 — Identify what changed in the generic doc

Summarise the changes to the generic doc in plain terms. Focus on:
- New patterns or conventions added
- Renamed components or layers
- Removed or deprecated patterns
- New rationale or "why" explanations added
- Changes to the dependency rule or testing strategy

Present this summary to the user before proceeding — it gives context for the per-scenario proposals.

## Step 3 — Assess impact per scenario

For each scenario doc, run two independent passes and merge the findings into a single proposal.

### Pass A — Delta propagation

Determine which generic doc changes (from Step 2) are relevant to this scenario. Not all changes affect all scenarios. Use judgment:
- A new concurrency pattern in the generic doc probably affects all scenarios
- A new pagination note only affects scenarios that discuss pagination
- A renamed component affects any scenario that uses that component name

### Pass B — Standing-rules audit

Independently of what changed in the generic doc, check every scenario against these standing rules:

**B1. Architecture section — 5-layer completeness**
The `## Architecture` section must list all five layers in order: Presentation → Domain → Data → Infrastructure → External. Every layer must appear even if unused — unused layers are marked `None`.

Flag if:
- Any of the five layers is missing entirely
- A layer is omitted instead of showing `None`
- The section only contains a general pattern statement with no named components

**B2. Naming conventions**
Check every component name against the generic doc's conventions:
- Remote access: `*RemoteDataSource` — always domain-prefixed (e.g. `RestaurantRemoteDataSource`, not bare `RemoteDataSource` as a class name)
- Local access: `*LocalDataSource` — always domain-prefixed (e.g. `MessageLocalDataSource`, not bare `LocalDataSource` as a class name in layer breakdowns, data flows, or code examples)
- Business logic: `*UseCase` (stateless) or `*Service` (stateful Domain Service)
- DTOs: `*DTO` — Mappers: `*Mapper`
- Navigation: `*Coordinator`
- Infrastructure wrappers: `*Gateway` — always vendor-prefixed (e.g. `StripePaymentGateway`, not bare `Gateway`)

**Exception:** bare `LocalDataSource` / `RemoteDataSource` is acceptable in the delta table's "Generic" column, pattern-level warning callouts, and type-annotation diagrams. It is NOT acceptable as a class name in layer breakdowns, data flow pseudocode, or vocabulary tables.

**B3. Redundant generic content**
Flag as ❌ Redundant if the scenario contains any of these generic-only explanations:
- "Why MVVM over MVP?" or "Why MVVM over VIPER?"
- "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- UseCase vs Domain Service comparison table (columns: Triggered by / State / Has I/O? / Lifetime)
- Domain Service vs Gateway comparison table

Scenario-specific reasoning is fine (e.g. "Why UIKit over SwiftUI for THIS scenario"). The test: would this exact explanation appear unchanged in every other scenario? If yes, it's generic and must be removed.

**B4. External SDK wrapper compliance**
For every External SDK listed in the Architecture section:
- No-wrapper exceptions: UIKit, SwiftUI, Combine only
- Every other SDK must have a named wrapper
- Wrapper placement: single-layer SDK → `DataSource`/`APIClient`/`WebSocketClient` (Data) or `Service` (Domain); multi-layer SDK → `*Gateway` in Infrastructure

Flag if a multi-layer SDK is wrapped as a DataSource/Service, or a single-layer SDK is wrapped as a Gateway.

**B5. "Same as generic" accuracy**
Verify the existing "Same as generic architecture" list is still accurate against the current generic doc. Flag any entry that no longer matches, or any pattern present in the generic doc that is missing from the list.

**B6. Layer dependency rule**
Flag:
- ViewModels calling Repositories directly (should go via UseCase)
- UseCases referencing network types (should use Repository protocol)
- Repositories returning DTOs beyond their own layer (should map first)
- Domain models mentioning UIKit or networking types

---

For each scenario, produce a single merged proposal:

```
### Scenario: <name>
**Impact:** High / Medium / Low / None

#### Delta changes (from generic doc update)
- [ ] Delta "Same as generic" list: add <X> (new pattern in generic doc)
- [ ] Delta table: update <row> — generic column now says <Y>
- [ ] Section <Z>: rename <OldTerm> → <NewTerm> throughout

#### Standing violations (pre-existing, independent of this sync)
- [ ] B1 Architecture: missing Infrastructure layer — add with `None`
- [ ] B2 Naming: rename `LocalDataSource` → `MessageLocalDataSource` in layer breakdown
- [ ] B3 Redundant: remove "Why MVVM over MVP?" section
- [ ] B4 SDK wrapper: AVFoundation is multi-layer — wrap as `AVPlayerGateway` in Infrastructure, not a Service
- [ ] B5 "Same" list: `FetchPolicy` missing — add it
- [ ] B6 Layer rule: ViewModel calls Repository directly — route via UseCase

#### No changes needed
(only if both passes found nothing)
```

Show all proposals to the user before writing any file. Ask for confirmation: "Apply all? Or select specific scenarios?"

## Step 4 — Apply approved changes

For each approved scenario, apply both delta changes and standing-violation fixes:

**Delta changes:**
1. Update the "Same as generic architecture" list if new shared patterns were added
2. Update the delta table rows where the "Generic" column description changed
3. Rename any component names that were updated in the generic doc
4. Update rationale text if the "why" for a shared pattern changed
5. Do NOT remove delta items that are still scenario-specific — only update the generic-side descriptions

**Standing-violation fixes:**
6. Add any missing Architecture layers (marked `None` if unused)
7. Rename naming violations to their correct domain-prefixed forms throughout the file
8. Remove any redundant generic content sections (B3)
9. Correct SDK wrapper placement if misclassified (B4)
10. Add missing "same" list entries for patterns now in the generic doc (B5)
11. Fix layer dependency violations if clearly structural (B6) — if ambiguous, flag for manual review instead of silently rewriting

Write the updated `.md` file.

## Step 5 — Regenerate HTML for the generic architecture doc

The generic architecture HTML at `docs/deck/ios-app-system-design-philosophy.html` must always stay in sync with `docs/ios-app-system-design-philosophy.md`.

Regenerate `docs/deck/ios-app-system-design-philosophy.html` after every run of this skill, even if the changes seem minor. Use the same CSS and component class rules as `sync-scenario-html`:
- Copy CSS verbatim from `docs/deck/scenarios/music-streaming-system-design.html`
- Map every `##` section to `<section id="...">` with a `.toc` entry
- `.callout` (blue) for "why" decisions, `.rule` (green) for principles, `.warn` (orange) for gotchas
- Nav breadcrumb links back to `index.html`
- Bottom nav: left `← Home`, right links to `scenarios/music-streaming-system-design.html`

## Step 7 — Regenerate HTML for changed scenarios

For each scenario whose `.md` was updated in step 4, regenerate its HTML deck following the same rules as `sync-scenario-html`:

- Copy CSS verbatim from `docs/deck/scenarios/music-streaming-system-design.html`
- Map every `##` section to `<section id="...">` with a `.toc` entry
- Use `.callout` (blue) for "why" decisions, `.rule` (green) for principles, `.warn` (orange) for gotchas
- Delta section always comes first in TOC and body
- Save to `docs/deck/scenarios/<scenario-name>.html`

## Step 8 — Report to user

After all writes are complete:

```
## Sync Complete

### Files updated
- `docs/ios-app-system-design-philosophy.md` ← source
- `docs/deck/ios-app-system-design-philosophy.html` ✅ regenerated

### Generic doc changes
<summary from step 2>

### Scenarios updated
| Scenario | .md updated | HTML regenerated | Delta changes | Standing fixes |
|---|---|---|---|---|
| music-streaming | ✅ | ✅ | Added FetchPolicy to "same" list | Renamed LocalDataSource → TrackLocalDataSource |
| hotel-booking | ✅ | ✅ | None | Removed redundant "Why MVVM over MVP?" section |
| (next) | ⏭️ skipped | — | No impact | No violations found |

### Skipped scenarios
<list any that were skipped and why>

### Remaining manual review items
<list any B6 layer dependency violations that were flagged but not auto-fixed due to ambiguity>
```

If no standing violations were found in any scenario, omit the "Standing fixes" column and the "Remaining manual review items" section.
