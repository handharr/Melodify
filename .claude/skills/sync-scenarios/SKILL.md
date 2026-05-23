---
name: sync-scenarios
description: Propagates changes from docs/ios-app-system-design.md into all docs/scenarios/ files. Proposes updates per scenario before writing, then regenerates HTML for any changed scenario.
user-invocable: true
---

The generic architecture doc (`docs/ios-app-system-design.md`) was updated. Your job is to propagate those changes into every scenario doc in `docs/scenarios/`, then regenerate the HTML for any scenario that changed.

This skill proposes changes per scenario before writing — it never silently overwrites.

## Step 1 — Read all files

Read:
1. `docs/ios-app-system-design.md` — the updated generic architecture
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

For each scenario doc, determine which of the generic doc changes are relevant to it.

Not all changes affect all scenarios. Use judgment:
- A new concurrency pattern in the generic doc probably affects all scenarios
- A new pagination note only affects scenarios that discuss pagination
- A renamed component affects any scenario that uses that component name

For each scenario, produce a proposal:

```
### Scenario: <name>
**Impact:** High / Medium / Low / None

Changes needed:
- [ ] Delta "Same as generic" list: add <X> (new pattern in generic doc)
- [ ] Delta table: update <row> — generic column now says <Y>
- [ ] Section <Z>: rename <OldTerm> → <NewTerm> throughout
- [ ] No changes needed
```

Show all proposals to the user before writing any file. Ask for confirmation: "Apply all? Or select specific scenarios?"

## Step 4 — Apply approved changes

For each approved scenario:

1. Update the "Same as generic architecture" list if new shared patterns were added
2. Update the delta table rows where the "Generic" column description changed
3. Rename any component names that were updated in the generic doc
4. Update rationale text if the "why" for a shared pattern changed
5. Do NOT remove delta items that are still scenario-specific — only update the generic-side descriptions

Write the updated `.md` file.

## Step 5 — Regenerate HTML for the generic architecture doc

The generic architecture HTML at `docs/deck/ios-app-system-design.html` must always stay in sync with `docs/ios-app-system-design.md`.

Regenerate `docs/deck/ios-app-system-design.html` after every run of this skill, even if the changes seem minor. Use the same CSS and component class rules as `sync-scenario-html`:
- Copy CSS verbatim from `docs/deck/music-streaming-system-design.html`
- Map every `##` section to `<section id="...">` with a `.toc` entry
- `.callout` (blue) for "why" decisions, `.rule` (green) for principles, `.warn` (orange) for gotchas
- Nav breadcrumb links back to `index.html`
- Bottom nav: left `← Home`, right links to `music-streaming-system-design.html`

## Step 7 — Regenerate HTML for changed scenarios

For each scenario whose `.md` was updated in step 4, regenerate its HTML deck following the same rules as `sync-scenario-html`:

- Copy CSS verbatim from `docs/deck/music-streaming-system-design.html`
- Map every `##` section to `<section id="...">` with a `.toc` entry
- Use `.callout` (blue) for "why" decisions, `.rule` (green) for principles, `.warn` (orange) for gotchas
- Delta section always comes first in TOC and body
- Save to `docs/deck/<scenario-name>.html`

## Step 8 — Report to user

After all writes are complete:

```
## Sync Complete

### Files updated
- `docs/ios-app-system-design.md` ← source
- `docs/deck/ios-app-system-design.html` ✅ regenerated

### Generic doc changes
<summary from step 2>

### Scenarios updated
| Scenario | .md updated | HTML regenerated | Changes |
|---|---|---|---|
| music-streaming | ✅ | ✅ | Added FetchPolicy to "same" list; renamed X → Y |
| (next) | ⏭️ skipped | — | No impact from this change |

### Skipped scenarios
<list any that were skipped and why>

### Recommended follow-up
- Run /audit-scenarios to verify full consistency
```
