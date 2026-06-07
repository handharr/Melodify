---
name: philosophy-audit-recall-html
description: Read-only audit of docs/deck/system-design-recall.html against all system design .md sources, HTML decks, and Section 7/8 of docs/conventions/scenario-conventions.md. Reports chip ID violations, PATHS completeness gaps, layer chain skips, missing/phantom components, and flow drift. Makes no changes.
user-invocable: true
---

Read-only audit of the recall diagram. Makes no changes.

Checks every app card in `docs/deck/system-design-recall.html` against:
- Its system design `.md` (component presence, flow rows, endpoints)
- Its HTML deck (component names, chip types)
- `docs/conventions/scenario-conventions.md` Section 7 (chip IDs, PATHS) and Section 8 (layer chain fidelity, external naming)

## Parse Arguments

**Accepted names** (case-insensitive):
`music-app` (or `music`), `chat-app` (or `chat`), `core-kit` (or `core`), `melodify-design-system` (or `mds`)

| Invocation | Mode |
|---|---|
| No argument | All 4 apps |
| One or more names | Only those apps |

## App → file mapping

| App | Prefix | .md | HTML deck |
|---|---|---|---|
| music-app | `mus` | `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md` | `docs/deck/SystemDesign/MusicAppSystemDesign.html` |
| chat-app | `cha` | `docs/SystemDesign/ChatApp/ChatAppSystemDesign.md` | `docs/deck/SystemDesign/ChatAppSystemDesign.html` |
| core-kit | `ck` | `docs/SystemDesign/CoreKit/CoreKitSystemDesign.md` | `docs/deck/SystemDesign/CoreKitSystemDesign.html` |
| melodify-design-system | `mds` | `docs/SystemDesign/MelodifyDesignSystem/MelodifyDesignSystemSystemDesign.md` | `docs/deck/SystemDesign/MelodifyDesignSystemSystemDesign.html` |

## Workflow

Spawn one `philosophy-recall-diagram-audit-worker` **per target scenario in parallel**. Pass each worker:
- Scenario name
- Scenario prefix (from table above)
- Scenario .md path
- HTML deck path

## Report

Collect all worker results. Assemble the final audit report:

```
## Recall Diagram Audit — <date>
Scope: all 4 apps | <name(s)>

---

<per-app findings from each worker, in card order>

---

### Summary

| App | Flows | Components | Endpoints | Chip Types | Chip IDs | PATHS | Chain | Naming | Overall |
|---|---|---|---|---|---|---|---|---|---|
| music-app     | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | Clean/Issues |
| chat-app      | ... |
| core-kit      | ... |
| melodify-design-system | ... |
```

End with recommended actions:
- Any findings → run `/philosophy-sync-recall-html <scenario-name>` for each affected scenario (or no argument to fix all)
- PATHS violations → note that manual review of the PATHS array may be needed after sync
- All clean → "Recall diagram is in sync with all scenario sources."
