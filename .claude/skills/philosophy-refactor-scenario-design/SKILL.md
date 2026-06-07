---
name: philosophy-refactor-scenario-design
description: Refactors a raw iOS system design notes file (from a YouTube video or mock interview) to align with the generic iOS architecture in docs/ios-app-system-design-philosophy.md. Produces a clean scenario .md doc and a matching HTML deck file.
user-invocable: true
---

The user provides a file path as the argument.

**If no path provided:** list all files in `docs/SystemDesign/` and ask: "Which system design doc do you want to refactor, or provide a path to raw notes for a new app?"

**Mode detection:**
- Path inside `docs/SystemDesign/` → **Refactor mode**: update the existing `.md` in place + regenerate HTML
- Any other path → **Create mode**: treat as raw notes, produce new `.md` + HTML from scratch

---

## Phase 1 — Analyze

Use agent `philosophy-refactor-scenario-design-worker` with:
> **Mode: [refactor|create]. Phase: analyze.** Input file: [path].
> In refactor mode: also read the existing HTML deck + `docs/deck/SystemDesign/MusicAppSystemDesign.html` as style reference.
> Return a full structured plan.

Present the plan to the user. Ask: **"Apply all changes? Or select specific items?"**

## Phase 2 — Apply + Generate

After confirmation, use agent `philosophy-refactor-scenario-design-worker` with:
> **Mode: [refactor|create]. Phase: apply.** Input file: [path]. Approved changes: [approved items from Phase 1].
> Apply all approved changes, cross-check the result, write the `.md` file.

The worker will indicate when to spawn `philosophy-scenario-html-worker`. When it does, spawn that worker with:
> **Mode: generate.** Scenario .md: [output .md path]. HTML deck path: [target HTML path]. Style reference: `docs/deck/SystemDesign/MusicAppSystemDesign.html`. Before generating, read `docs/conventions/scenario-conventions.md` — Section 9 defines the required `#delta` section structure (`.delta-grid` / `.delta-card` / `.delta-topic` / `.delta-decision` / `.delta-rationale`). Do not use `.rule` or `.callout` classes for the delta section.

## Report

Relay both workers' reports. Append:
> Recommended follow-up: Run `/philosophy-sync-recall-html [scenario-name]` to update the recall card for this scenario.
