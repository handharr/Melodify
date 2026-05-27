---
name: philosophy-audit-scenarios
description: Read-only audit of all docs/scenarios/ files against docs/ios-app-system-design-philosophy.md. Reports stale naming, missing delta coverage, layer violations, and HTML sync drift. Makes no changes.
user-invocable: true
---

Read-only audit of all 6 scenario docs against the generic iOS architecture. Makes no changes.

## Workflow

Spawn one `philosophy-scenario-audit-worker` **per scenario in parallel** — all 6 simultaneously. Each worker receives:
- Scenario .md path (e.g. `docs/scenarios/ios-uber-eats-system-design.md`)
- HTML deck path (e.g. `docs/deck/scenarios/uber-eats-system-design.html`)
- Philosophy doc path: `docs/ios-app-system-design-philosophy.md`

**Scenario → file mapping:**

| Scenario | .md | HTML deck |
|---|---|---|
| uber-eats | `docs/scenarios/ios-uber-eats-system-design.md` | `docs/deck/scenarios/uber-eats-system-design.html` |
| messenger | `docs/scenarios/ios-messenger-system-design.md` | `docs/deck/scenarios/messenger-system-design.html` |
| music-streaming | `docs/scenarios/ios-music-streaming-system-design.md` | `docs/deck/scenarios/music-streaming-system-design.html` |
| instagram-news-feed | `docs/scenarios/ios-instagram-news-feed-system-design.md` | `docs/deck/scenarios/instagram-news-feed-system-design.html` |
| hotel-booking | `docs/scenarios/ios-hotel-booking-system-design.md` | `docs/deck/scenarios/hotel-booking-system-design.html` |
| story-viewer | `docs/scenarios/ios-story-viewer-system-design.md` | `docs/deck/scenarios/story-viewer-system-design.html` |

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
- Naming or layer violations → `/philosophy-refactor-scenario-design` to clean up the scenario
- HTML out of sync → `/philosophy-sync-scenario-html` on the affected file
- Delta stale against generic doc → `/philosophy-sync-scenarios` to propagate arch changes
