---
name: teach
description: Turn the product, feature, automation, or technical system just built or discussed in the current chat into a fun, visual, standalone local HTML lesson for a non-developer. Use when the builder explicitly invokes Teach or asks to understand what they just built; do not use for ordinary implementation, code documentation, or generic explanations unrelated to the active build.
---

# Teach

Turn the active build into a small explorable lesson. Use the current chat as the primary source, so the builder should not need to explain their work again.

## Create the lesson

1. Reconstruct why the work started, what was built, and the shortest accurate explanation of how it works. Use the active chat first. Inspect local files only when the chat leaves an important factual gap.
2. Organize every lesson into exactly three parts: **The problem**, **What you built**, and **How it works**. The final part should follow one real action through 3 to 5 steps, from trigger to visible result.
3. Read [the teaching method](references/teaching-method.md), [the brand system](references/brand.md), and [the lesson format](references/lesson-format.md) before authoring.
4. Write the lesson data as JSON. Default to `~/teach-lessons/<lesson-slug>/lesson.json` so generated artifacts do not dirty the product repository. Reuse that file for follow-up revisions.
5. Resolve bundled files from the directory containing this `SKILL.md`, not from the builder's project. In Claude Code that directory is available as `${CLAUDE_SKILL_DIR}`. Use an available Python 3 launcher (`python3` on macOS/Linux, or `py -3`/`python` on Windows) to run the bundled `scripts/build_lesson.py` and `scripts/serve_lesson.py`. Serve only the lesson directory on `127.0.0.1`; never bind the local lesson server to `0.0.0.0`.
6. Open and inspect the rendered lesson in a browser. Check the actual text, diagram wrapping, mobile layout, keyboard focus, and interactions. Fix visible issues before handing it back.

The output is one self-contained `index.html`. It must not need a package install, API key, account, CDN, or internet connection.

## Teach like a person

- Write for a curious 18-year-old. Use short sentences and familiar words.
- Keep the entire lesson readable in about 3 minutes. Each part gets one short paragraph, one takeaway, and at most one visual.
- Describe the outcome before naming files or tools.
- In **How it works**, show the trigger, the important transformation, and the result. Skip internal details that do not change the learner's mental model.
- Use 3 to 5 visual nodes. Each node should be understandable without opening its detail panel.
- If a technology name helps, add it to the compact **Tools used** list with one sentence: what it is and what job it performs here. Do not create inline jargon tooltips or a dictionary.
- Do not add quizzes, playgrounds, scenarios, scores, analogies, architecture inventories, or speculative future versions.
- Avoid `simple`, `obvious`, `just`, corporate filler, fake excitement, and sentences that describe the teaching process instead of the build.
- Never include secrets, tokens, private customer data, hidden prompts, or confidential chat content in the generated page.

When the builder asks a follow-up in chat, answer it and update the existing lesson only when it changes the three-part mental model. Rebuild and keep the same local URL when possible.

## v1 boundary

Keep v1 local and private. Do not add hosting, authentication, analytics, databases, model API calls, or GrowthX infrastructure unless the user explicitly starts that later phase.
