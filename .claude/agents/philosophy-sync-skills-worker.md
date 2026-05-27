---
name: philosophy-sync-skills-worker
description: Internal worker for philosophy-sync-skills. In analyze mode reads the philosophy doc and all skill files, extracts architecture state, and returns per-skill impact proposals. In apply mode applies the approved changes to the specified skill files.
tools: Read, Write, Edit, Glob, Grep
---

Read the **Mode** from the prompt and execute accordingly.

---

## Mode: analyze

### Step 1 — Read all files

Read:
1. `docs/ios-app-system-design-philosophy.md` — the updated philosophy (source of truth)
2. Every `SKILL.md` under `.claude/skills/`:
   - `.claude/skills/philosophy-audit-scenarios/SKILL.md`
   - `.claude/skills/philosophy-refactor-scenario-design/SKILL.md`
   - `.claude/skills/philosophy-sync-scenario-html/SKILL.md`
   - `.claude/skills/philosophy-sync-scenarios/SKILL.md`
   - `.claude/skills/philosophy-sync-skills/SKILL.md` — read but **skip self-edits**

### Step 2 — Extract current architecture state from the philosophy doc

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

### Step 3 — Assess impact per skill

For each skill file, check against the extracted state. Never assume a skill is up to date — read and verify each one.

**File path references**
Does the skill hardcode the philosophy `.md` or `.html` filename? If so, does it match the current filename exactly?

**Naming conventions**
Does the skill's naming convention list include every suffix from Step 2? Flag any suffix that is missing or uses outdated terminology.

**Dependency rule text**
Does the skill quote the dependency rule? If so, does it match the exact current wording from the philosophy doc?

**Generic content blocklist** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenario-html`
Does the skill's "do not include in scenarios" list cover every item in the blocklist extracted in Step 2?

**Scenario template link** — applies to: `refactor-scenario-design`
Does the template `> Scenario extension of [...]` link match the current philosophy doc path (`../ios-app-system-design-philosophy.md`)?

**Architecture section five-layer structure** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenarios`
Does the skill enforce the required five-layer structure for `## Architecture` sections: Presentation / Domain / Data / Infrastructure / External, with all five layers always present and unused layers marked `None`?

**SDK wrapper placement rules** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenarios`
Does the skill carry the current SDK wrapper placement rules?
- No-wrapper exceptions: UIKit, SwiftUI, Combine only
- Single-layer SDK → `*DataSource` / `APIClient` / `WebSocketClient` (Data) or `*Service` (Domain)
- Multi-layer SDK → `*Gateway` in Infrastructure

**Three-skill triad consistency** — applies to: `audit-scenarios`, `refactor-scenario-design`, `sync-scenarios`
These three skills form a triad. Checks that must appear in all three:
- 5-layer Architecture completeness
- Domain-prefixed DataSource naming
- Redundant generic content blocklist
- SDK wrapper placement
- "Same as generic" accuracy (both directions)
- Layer dependency rule

**Frontmatter description**
Does the `description:` field reference the correct philosophy filename?

### Step 4 — Return proposals

For each skill:

```
### Skill: <name>
**File:** .claude/skills/<name>/SKILL.md
**Impact:** High / Medium / Low / None

Changes needed:
- [ ] Line ~N: <current text> → <replacement> — reason
- [ ] No changes needed
```

---

## Mode: apply

The prompt will specify the approved skill list and the exact proposals from the analyze phase.

For each approved skill, apply only the listed changes. Do not rewrite sections that were not flagged.

**Order of edits per skill:**
1. Frontmatter `description:` — file path references
2. Body file path references (all occurrences)
3. Naming convention entries — add missing suffixes, do not remove existing ones unless outdated
4. Dependency rule text — replace with exact wording from philosophy doc
5. Generic content blocklist — append missing entries, do not reorder existing ones
6. Scenario template link — update path only

Write each updated skill file.

### Return apply report

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
```
