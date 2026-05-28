---
name: philosophy-audit-recall-html
description: Read-only audit of docs/deck/system-design-recall.html against all scenario .md sources, HTML decks, and Section 7/8 of docs/conventions/scenario-conventions.md. Reports chip ID violations, PATHS completeness gaps, layer chain skips, missing/phantom components, and flow drift. Makes no changes.
user-invocable: true
---

Read-only audit of the recall diagram. Makes no changes.

Checks every scenario card in `docs/deck/system-design-recall.html` against:
- Its scenario `.md` (component presence, flow rows, endpoints)
- Its HTML deck (component names, chip types)
- `docs/conventions/scenario-conventions.md` Section 7 (chip IDs, PATHS) and Section 8 (layer chain fidelity, external naming)

## Parse Arguments

**Accepted names** (case-insensitive, hyphens optional):
`uber-eats`, `messenger`, `music-streaming`, `instagram-news-feed` (or `instagram`), `hotel-booking` (or `hotel`), `story-viewer` (or `story`)

| Invocation | Mode |
|---|---|
| No argument | All 6 scenarios |
| One or more names | Only those scenarios |

## Scenario → file mapping

| Scenario | Prefix | .md | HTML deck |
|---|---|---|---|
| uber-eats | `ue` | `docs/scenarios/ios-uber-eats-system-design.md` | `docs/deck/scenarios/uber-eats-system-design.html` |
| messenger | `ms` | `docs/scenarios/ios-messenger-system-design.md` | `docs/deck/scenarios/messenger-system-design.html` |
| music-streaming | `mst` | `docs/scenarios/ios-music-streaming-system-design.md` | `docs/deck/scenarios/music-streaming-system-design.html` |
| instagram-news-feed | `ig` | `docs/scenarios/ios-instagram-news-feed-system-design.md` | `docs/deck/scenarios/instagram-news-feed-system-design.html` |
| hotel-booking | `hb` | `docs/scenarios/ios-hotel-booking-system-design.md` | `docs/deck/scenarios/hotel-booking-system-design.html` |
| story-viewer | `sv` | `docs/scenarios/ios-story-viewer-system-design.md` | `docs/deck/scenarios/story-viewer-system-design.html` |

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
Scope: all 6 scenarios | <name(s)>

---

<per-scenario findings from each worker, in card order>

---

### Summary

| Scenario | Flows | Components | Endpoints | Chip Types | Chip IDs | PATHS | Chain | Naming | Overall |
|---|---|---|---|---|---|---|---|---|---|
| uber-eats     | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | ✅/⚠️ | Clean/Issues |
| messenger     | ... |
| music-streaming | ... |
| instagram-news-feed | ... |
| hotel-booking | ... |
| story-viewer  | ... |
```

End with recommended actions:
- Any findings → run `/philosophy-sync-recall-html <scenario-name>` for each affected scenario (or no argument to fix all)
- PATHS violations → note that manual review of the PATHS array may be needed after sync
- All clean → "Recall diagram is in sync with all scenario sources."
