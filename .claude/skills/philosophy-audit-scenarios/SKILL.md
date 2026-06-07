---
name: philosophy-audit-scenarios
description: Read-only audit of all docs/SystemDesign/ files against docs/ios-app-system-design-philosophy.md. Reports stale naming, missing delta coverage, layer violations, and HTML sync drift. Makes no changes.
user-invocable: true
---

Read-only audit of all 4 system design docs against the generic iOS architecture. Makes no changes.

## Workflow

Spawn one `philosophy-scenario-audit-worker` **per app in parallel** — all 4 simultaneously. Each worker receives:
- System design .md path (e.g. `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md`)
- HTML deck path (e.g. `docs/deck/SystemDesign/MusicAppSystemDesign.html`)
- Philosophy doc path: `docs/ios-app-system-design-philosophy.md`

**App → file mapping:**

| App | .md | HTML deck |
|---|---|---|
| MusicApp | `docs/SystemDesign/MusicApp/MusicAppSystemDesign.md` | `docs/deck/SystemDesign/MusicAppSystemDesign.html` |
| ChatApp | `docs/SystemDesign/ChatApp/ChatAppSystemDesign.md` | `docs/deck/SystemDesign/ChatAppSystemDesign.html` |
| CoreKit | `docs/SystemDesign/CoreKit/CoreKitSystemDesign.md` | `docs/deck/SystemDesign/CoreKitSystemDesign.html` |
| MelodifyDesignSystem | `docs/SystemDesign/MelodifyDesignSystem/MelodifyDesignSystemSystemDesign.md` | `docs/deck/SystemDesign/MelodifyDesignSystemSystemDesign.html` |

## Report

Collect all 6 worker results. Assemble the final audit report:

```
## Audit Report — <date>

### docs/ios-app-system-design-philosophy.md
<version summary — what patterns/conventions are currently defined>

---

<per-scenario findings from each worker>

---

### Summary

| Scenario | Delta | Arch Coverage | Naming | Layers | HTML Sync | Redundant Content | Actions |
|---|---|---|---|---|---|---|---|
```

End with recommended next steps based on findings:
- Naming or layer violations → `/philosophy-refactor-scenario-design` to clean up the system design doc
- HTML out of sync → `/philosophy-sync-scenario-html` on the affected file
- Delta stale against generic doc → `/philosophy-sync-scenarios` to propagate arch changes
