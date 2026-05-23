---
name: learn-from-video
description: Refines raw YouTube video notes (from Gemini) into a structured learning doc for interview prep. Iterative loop: Phase 1 produces a refined draft + targeted Gemini questions; Phase 2+ incorporates answers, evaluates gaps, and generates follow-up questions until the doc is complete.
user-invocable: true
---

The user watches YouTube videos for interview preparation and gets Gemini to summarize them into raw notes. This skill turns those raw notes into a polished, interview-ready learning doc through an iterative Q&A loop with Gemini.

## Detecting the Phase

**Phase 1** — triggered when the user runs `/learn-from-video <path>` with a file path argument.

**Phase 2+** — triggered when the user pastes Gemini's answers back into the conversation. Detect this by looking for:
- A message that contains answers corresponding to questions you previously generated
- The user saying something like "here are Gemini's answers", "Gemini replied", or pasting a numbered list of answers

This is a loop — Phase 2 may repeat multiple times (Phase 2, Phase 3, Phase 4…) until the doc is complete. Each iteration follows the same Phase 2 steps.

If no file path is given in Phase 1, ask the user for the file path before proceeding.

---

## Phase 1 — Refine Raw Notes + Generate Questions

### Step 1 — Read the raw notes

Read the file at the path provided. Do not assume its structure. Extract:
- The topic / domain (e.g., "iOS Combine framework", "System design: ride-sharing", "Swift concurrency")
- The video source if mentioned
- All factual content: concepts, patterns, mechanisms, code snippets, diagrams described in text, Q&A, comparisons

### Step 2 — Produce the refined learning doc

Write a structured `.md` file. Overwrite the original file (do not create a separate `-refined.md`). Use this structure, skipping any section where the raw notes have no content:

```
# <Topic> — Learning Notes

**Source:** <video title or URL if mentioned, otherwise "YouTube">
**Domain:** <e.g., iOS / System Design / Swift / Algorithms>

---

## Core Concepts

For each key concept:
### <Concept Name>
<Clear definition — one paragraph max. No jargon without explanation.>

---

## How It Works

<Mechanism / flow description. Use numbered steps for sequential processes.
Use diagrams as ASCII if helpful — e.g., A → B → C.>

---

## Key Patterns

<Recurring patterns, idioms, or design decisions covered in the video.
Use sub-headers per pattern. Include "Why this pattern?" for each.>

---

## Trade-offs & Design Decisions

| Decision | Why This Approach | What You Give Up |
|---|---|---|
| (fill in) | (fill in) | (fill in) |

---

## Code Examples

<Preserve all code snippets from the notes verbatim. Add a one-line comment above each block explaining what it demonstrates.>

---

## Common Pitfalls / Gotchas

- <Pitfall 1 — what goes wrong and why>
- <Pitfall 2>

---

## Interview Talking Points

Concise bullets the user should be able to say out loud in an interview:
- <Talking point 1>
- <Talking point 2>
(aim for 5–8 bullets that cover the "what", "why", and "when to use")

---

## Open Questions

(Leave blank — filled in Phase 2 after Gemini Q&A)

---
```

### Step 3 — Generate Gemini questions

After writing the file, output a question list the user can copy-paste directly to Gemini.

**Question quality rules:**
- Ask about things the raw notes were vague or shallow on
- Ask about edge cases, failure modes, and "what happens when X" scenarios
- Ask about trade-offs the notes didn't cover
- Ask for code examples if the notes had none or incomplete ones
- Ask about interview context: "what would an interviewer expect to hear about X?"
- Do NOT ask things already well-covered in the notes

Generate 6–10 questions. Format them as a numbered list with a brief rationale in parentheses so the user understands why each question matters.

**Output format:**

```
---

## Questions for Gemini

Copy-paste these to Gemini. Paste the answers back here when done.

> Can you answer these questions based on the video? Only answer based on this video's content. If the answer is not covered in the video, reply "Out of this video's scope."

1. <Question> *(rationale)*
2. <Question> *(rationale)*
...

---
```

Print the questions in the conversation — do not write them to a file.

---

## Phase 2 — Incorporate Gemini Answers + Finalize

### Step 1 — Map answers to sections

Read the current state of the notes file. For each Gemini answer:
- Identify which section it enriches (Core Concepts, Patterns, Trade-offs, etc.)
- Identify any new section it warrants that doesn't exist yet

### Step 2 — Enrich the doc

Edit the notes file:
- Skip any answer marked "Out of this video's scope" — do not enrich, invent, or fill gaps from outside the video
- Fold new insights into existing sections — do not just append answers at the bottom
- Add new sections if an answer surfaced a topic not covered at all
- Fill in the `## Open Questions` section with any unresolved nuances or things worth exploring further
- Keep the doc tight — integrate, don't duplicate

### Step 3 — Gap evaluation

After enriching the doc, assess its completeness honestly across these dimensions:

| Dimension | Complete when… |
|---|---|
| Concept coverage | Every concept mentioned in the video has a clear definition |
| Mechanism depth | "How it works" can be explained step-by-step without hand-waving |
| Trade-offs | Every major design decision has a "why this, not that" answer |
| Code fluency | There is at least one code example per key pattern |
| Failure modes | Common mistakes and edge cases are documented |
| Interview readiness | Talking points cover what, why, and when to use — sayable out loud |

**If gaps remain:** generate 3–6 targeted follow-up questions for the next Gemini round. Apply the same question quality rules as Phase 1. Print them in the conversation with the same format. Do NOT add the Key Takeaways section yet — the doc isn't done.

**If no meaningful gaps remain:** proceed to Step 4 (finalize).

### Step 4 — Finalize (only when gaps are closed)

Append at the end of the file:

```markdown
---

## Key Takeaways

<3–5 sentences. If someone asked "tell me about <topic> in 30 seconds", what would the user say? Write it in first person, interview-ready.>
```

### Step 5 — Report to user

State the file path and which round this was (e.g., "Round 2 of 3"). Give a 2-sentence summary of what this round added. If you generated follow-up questions, say clearly: "Paste Gemini's answers back here to continue." If the doc is final, say: "Doc is complete — no further questions needed."

---

## Constraints

- Never invent facts not in the raw notes or Gemini answers. If something is unclear, write "(needs verification)" not a guess.
- Only enrich the doc from Gemini answers that are within the video's scope. If Gemini replies "Out of this video's scope", treat that question as unanswerable and do not fill it with outside knowledge.
- Keep the tone technical and direct — this is interview prep, not a blog post.
- Preserve all code snippets exactly. Do not paraphrase code.
- The final doc should be readable top-to-bottom in 10 minutes or less. Cut filler.
