---
name: philosophy-learn-from-video
description: Refines raw YouTube video notes (from Gemini) into a structured learning doc for interview prep. Iterative loop: Phase 1 produces a refined draft + targeted Gemini questions; Phase 2+ incorporates answers, evaluates gaps, and generates follow-up questions until the doc is complete.
user-invocable: true
---

Iterative Q&A loop to turn raw Gemini video notes into a polished interview-ready learning doc.

## Detecting the Phase

**Phase 1** — user runs `/philosophy-learn-from-video <path>` with a file path. If no path provided, ask for it.

**Phase 2+** — user pastes Gemini's answers back into the conversation. Detect by: numbered answers corresponding to previously generated questions, "here are Gemini's answers", or any similar signal.

This is a multi-turn loop — Phase 2 repeats until the doc is declared complete.

---

## Phase 1

Use agent `philosophy-learn-from-video-worker` with:
> **Phase: 1.** File: [user-provided path]. Read the raw notes, produce the refined learning doc (overwrite in place), and return the Gemini question list.

Print the worker's Gemini question list in the conversation. Tell the user: "Paste Gemini's answers back here to continue."

---

## Phase 2+

Use agent `philosophy-learn-from-video-worker` with:
> **Phase: 2.** Notes file: [same path — ask if unclear]. Gemini answers: [paste the answers the user just provided]. Enrich the notes file with insights from these answers, evaluate remaining gaps, and return either follow-up questions (gaps remain) or signal doc completion.

If the worker returns follow-up questions, print them and say: "Paste Gemini's answers back here to continue."
If the worker signals completion, confirm: "Doc is complete — no further questions needed."
