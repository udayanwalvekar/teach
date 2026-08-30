---
name: teach
description: Turn the product, feature, automation, or technical system just built or discussed in the current chat into a fun, visual, standalone local HTML lesson for a non-developer. Use when the builder explicitly invokes Teach or asks to understand what they just built; do not use for ordinary implementation, code documentation, or generic explanations unrelated to the active build.
---

# Teach

Turn the active build into a small explorable lesson. Use the current chat as the primary source, so the builder should not need to explain their work again.

## Create the lesson

1. Reconstruct what was built, why it exists, the important parts, and one end-to-end flow from the active chat. Inspect the relevant local files when doing so materially improves accuracy. Clearly separate confirmed behavior from inference.
2. Organize the lesson around two direct questions: **What did I build?** and **How does it work?** Follow one real user action or piece of information through the complete system so the explanation stays grounded in the builder's work.
3. Read [the teaching method](references/teaching-method.md), [the brand system](references/brand.md), and [the lesson format](references/lesson-format.md) before authoring.
4. Write the lesson data as JSON. Default to `~/teach-lessons/<lesson-slug>/lesson.json` so generated artifacts do not dirty the product repository. Reuse that file for follow-up revisions.
5. Build the standalone page with `scripts/build_lesson.py`. Serve only its lesson directory on `127.0.0.1` with `scripts/serve_lesson.py`; never bind the local lesson server to `0.0.0.0`.
6. Open and inspect the rendered lesson in a browser. Check the actual text, diagram wrapping, mobile layout, keyboard focus, interactions, quiz explanations, and question-copy flow. Fix visible issues before handing it back.

The output is one self-contained `index.html`. It must not need a package install, API key, account, CDN, or internet connection.

## Teach like a person

- Begin with what the builder accomplished and why it matters.
- Answer “what did I build?” before teaching the implementation: the outcome, who it is for, and what it now lets someone do.
- Answer “how does it work?” with a real end-to-end trace through the actual components, decisions, state, and data in this build.
- Name the actual tech stack used in the build. For each technology, explain what it is, where it runs, why it is there, what responsibility it owns, and what it talks to next.
- Explain the interface, frontend, backend, database, state, function calls, APIs, authentication, and hosting when they genuinely exist in the build. If an expected layer does not exist, say that plainly instead of inventing one.
- When a function call matters, show who calls it, what information goes in, what the function does, what comes back or changes, and where the result travels next.
- Use ordinary words before introducing the technical term in parentheses.
- Prefer the real components, names, events, fields, state, and relationships from the builder's system once their meaning is clear.
- Keep a jargon inventory while writing. Every technical word used in the lesson must appear in `concepts` with a plain definition and an explanation of what it means in this build.
- Use a relatable analogy when it makes a hard mechanism easier to see. Map each part to the real system and say where the analogy stops being accurate.
- Make a visualization the main teaching surface, not decoration beside a wall of text.
- Draw diagrams in a clean, classy, minimal style: only meaningful nodes and connections, generous spacing, direct labels, restrained color, and one obvious reading path. Remove decorative complexity that does not teach.
- Offer three depths: what you built, how it works, and under the hood.
- Prefer click-through flows, layer reveals, before-and-after comparisons, and break/fix scenarios over passive diagrams.
- Trace the same concrete action or object through the complete system at least once.
- End with 3 to 5 scenario questions. Explain every answer immediately. Never shame a low score.
- Avoid `simple`, `obvious`, `just`, corporate filler, fake excitement, and any jargon that is missing from the dictionary.
- Never include secrets, tokens, private customer data, hidden prompts, or confidential chat content in the generated page.

## Keep questions in the loop

The local page is not an AI chatbot. Its question dock helps the builder form a question and copy it back into the same chat.

When the builder asks a follow-up, answer it and update the existing lesson when the answer changes or deepens their mental model. Add a new chapter only when it represents a distinct idea; otherwise improve the relevant explanation or diagram in place, rebuild, and keep the same local URL when possible.

## v1 boundary

Keep v1 local and private. Do not add hosting, authentication, analytics, databases, model API calls, or GrowthX infrastructure unless the user explicitly starts that later phase.
