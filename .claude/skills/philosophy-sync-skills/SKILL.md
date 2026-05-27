---
name: philosophy-sync-skills
description: Propagates architecture changes from docs/ios-app-system-design-philosophy.md into all skill files. Keeps naming conventions, dependency rules, file paths, and content blocklists in sync with the philosophy doc.
user-invocable: true
---

The philosophy doc (`docs/ios-app-system-design-philosophy.md`) was updated. Your job is to propagate those changes into every skill file under `.claude/skills/`, then report what changed.

This skill proposes changes per skill before writing — it never silently overwrites.

## Step 1 — Read all files

Read:
1. `docs/ios-app-system-design-philosophy.md` — the updated philosophy (source of truth)
2. Every `SKILL.md` under `.claude/skills/`:
   - `.claude/skills/philosophy-audit-scenarios/SKILL.md`
   - `.claude/skills/philosophy-refactor-scenario-design/SKILL.md`
   - `.claude/skills/philosophy-sync-scenario-html/SKILL.md`
   - `.claude/skills/philosophy-sync-scenarios/SKILL.md`
   - `.claude/skills/philosophy-sync-skills/SKILL.md` — read but **skip self-edits**

## Step 2 — Extract current architecture state from the philosophy doc

From the philosophy doc, extract the following as the source of truth:

**File paths**
- The `.md` filename and its HTML deck filename under `docs/deck/`

**Layer names**
- All layers currently defined (e.g. Presentation, Domain, Data, Infrastructure, Application)

**Naming conventions — suffix → layer mapping**
Extract every suffix defined in the philosophy doc's suffix table. Current example:

| Suffix | Layer |
|---|---|
| `UseCase` | Domain |
| `Service` | Domain |
| `Repository` | Data |
| `DataSource` | Data |
| `Mapper` | Data |
| `DTO` | Data |
| `Gateway` | Infrastructure |
| `Coordinator` | Application |

**Dependency rule — exact wording**
Extract the full dependency rule sentence as written in the philosophy doc. Example:
> Presentation → Domain ← Data. Infrastructure conforms to Domain protocols. Domain depends on nothing.

**Generic-only content blocklist**
Extract all comparison tables and "Why X over Y?" explanations that belong only in the philosophy doc and must never appear in scenario docs. Current list:
- "Why MVVM over MVP?" / "Why MVVM over VIPER?" / "Why Clean Architecture over MVC?"
- "Why FetchPolicy over hardcoding network/cache logic per ViewModel?"
- "UseCase vs Domain Service" comparison table
- "Domain Service vs Gateway" comparison table

## Step 3 — Assess impact per skill

For each skill file, check against the extracted state. Never assume a skill is up to date — read and verify each one.

### Checks to run per skill

**File path references**
Does the skill hardcode the philosophy `.md` or `.html` filename? If so, does it match the current filename exactly?

**Naming conventions**
Does the skill's naming convention list include every suffix from step 2? Flag any suffix that is missing or uses outdated terminology.

**Dependency rule text**
Does the skill quote the dependency rule? If so, does it match the exact current wording from the philosophy doc?

**Generic content blocklist** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenario-html`
Does the skill's "do not include in scenarios" list cover every item in the blocklist extracted in step 2?

**Scenario template link** — applies to: `refactor-scenario-design`
Does the template `> Scenario extension of [...]` link match the current philosophy doc path (`../ios-app-system-design-philosophy.md`)?

**Architecture section four-layer structure** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenarios`
Does the skill enforce the required four-layer structure for `## Architecture` sections: `Presentation → Domain → Data → Infrastructure`, with all four layers always present and unused layers marked `None`?

**Frontmatter description**
Does the `description:` field in the frontmatter reference the correct philosophy filename?

### Proposal format

For each skill, produce:

```
### Skill: <name>
**File:** .claude/skills/<name>/SKILL.md
**Impact:** High / Medium / Low / None

Changes needed:
- [ ] Line ~N: <current text> → <replacement> — reason
- [ ] No changes needed
```

Show all proposals to the user before writing any file. Ask: "Apply all? Or select specific skills?"

## Step 4 — Apply approved changes

For each approved skill, make only the changes listed in the proposal. Do not rewrite sections that were not flagged.

Order of edits per skill:
1. Frontmatter `description:` — file path references
2. Body file path references (all occurrences)
3. Naming convention entries — add missing suffixes, do not remove existing ones unless outdated
4. Dependency rule text — replace with exact wording from philosophy doc
5. Generic content blocklist — append missing entries, do not reorder existing ones
6. Scenario template link — update path only

Write each skill file after edits are confirmed.

## Step 5 — Report to user

```
## Sync Complete — Skills

### Architecture state extracted from philosophy doc
- Layers: <list>
- Naming suffixes: <list>
- Dependency rule: <exact wording>
- Generic content blocklist: <list>

### Skills updated
| Skill | Impact | Changes applied |
|---|---|---|
| audit-scenarios | ... | ... |
| refactor-scenario-design | ... | ... |
| sync-scenario-html | ... | ... |
| sync-scenarios | ... | ... |
| sync-philosophy-skills | ⏭️ skipped | Self-edit not supported — update manually if needed |

### Skipped skills
<any skill skipped and why>

### Recommended follow-up
- Run /philosophy-sync-scenarios to propagate philosophy changes into scenario docs
- Run /philosophy-audit-scenarios to verify full consistency across scenarios
```
