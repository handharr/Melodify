---
name: philosophy-sync-skills
description: Propagates architecture changes from docs/ios-app-system-design-philosophy.md into all skill files. Keeps naming conventions, dependency rules, file paths, and content blocklists in sync with the philosophy doc.
user-invocable: true
---

The philosophy doc was updated. Propagate those changes into every skill file under `.claude/skills/`.

This skill proposes changes per skill before writing — it never silently overwrites.

## Phase 1 — Analyze

Use agent `philosophy-sync-skills-worker` with:
> **Mode: analyze.** Read `docs/ios-app-system-design-philosophy.md` and all SKILL.md files under `.claude/skills/`. Extract the current architecture state from the philosophy doc, then assess impact per skill and return a structured proposal (impact level + specific changes needed per skill). Skip self-edits on `philosophy-sync-skills/SKILL.md`.

Present the worker's proposals to the user. Ask: **"Apply all? Or select specific skills?"**

## Phase 2 — Apply

After user confirms, use agent `philosophy-sync-skills-worker` with:
> **Mode: apply.** Apply the following approved changes to the listed skill files. Make only the listed edits — do not rewrite sections that were not flagged. Write each updated file.
>
> [Include the full approved proposals from Phase 1]

## Report

Relay the worker's final report. Append:
> Recommended follow-up:
> - Run /philosophy-sync-scenarios to propagate philosophy changes into scenario docs
> - Run /philosophy-audit-scenarios to verify full consistency across scenarios
