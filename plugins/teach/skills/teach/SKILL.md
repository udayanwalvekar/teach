---
name: teach
description: Turn the product, feature, automation, or technical system just built or discussed in the current chat into an evidence-backed local learning module for a non-developer. Use when the builder says "teach", explicitly invokes Teach, or asks to understand what they just built; do not use for ordinary implementation, code documentation, or generic explanations unrelated to the active build.
---

# Teach

The single word `teach` is a complete request. Do not ask the builder to restate the teaching level, technologies, or system boundaries; those decisions are part of this skill.

Teach uses two separate agents because investigating code and designing learning are different jobs. Never ask one agent to do both in the same pass.

## Run the two-agent pipeline

1. Create or reuse `~/teach-lessons/<lesson-slug>/` outside the builder's repository.
2. Start a fresh **Build Investigator** agent. Give it the active conversation, access to the relevant repository, [the investigator prompt](references/build-investigator.md), and [the build-map format](references/build-map-format.md). Its only output is `build-map.json`.
3. Run `scripts/validate_build_map.py` on that file. If evidence is missing or an uncertainty affects the lesson, send the gap back to the investigator. Do not let the learning agent guess.
4. Start a different, fresh **Learning Designer** agent. Give it only the builder's teaching request, the validated `build-map.json`, [the learning-designer prompt](references/learning-designer.md), [the teaching method](references/teaching-method.md), and [the lesson format](references/lesson-format.md). Do not give this agent the full chat or repository.
5. Save its output as `lesson.json`. Build with `scripts/build_lesson.py lesson.json --build-map build-map.json`. The script validates every evidence reference before rendering.
6. Serve only the lesson directory on `127.0.0.1` with `scripts/serve_lesson.py`. Never bind the server to `0.0.0.0`.
7. Open the rendered lesson in a browser. Check the real text, diagram wrapping, 320-pixel layout, keyboard focus, reduced motion, and interactions. Fix visible problems before handing it back.

Use the environment's native subagent or delegation feature for the two agents. If delegation is unavailable, say that Teach requires two isolated passes; do not silently collapse them into one prompt.

Resolve bundled files from the directory containing this `SKILL.md`, not from the builder's project. In Claude Code that directory is available as `${CLAUDE_SKILL_DIR}`. Use Python 3.9 or newer (`python3` on macOS/Linux, or `py -3`/`python` on Windows), and confirm the selected interpreter meets that minimum before running the scripts.

The output directory contains three useful artifacts:

- `build-map.json`: what the code and conversation prove
- `lesson.json`: what the module teaches and in what order
- `index.html`: the self-contained page shown to the learner

## Non-negotiable teaching rules

- Write for a curious 18-year-old. Familiar words come before technical names.
- State what the learner will understand by the end.
- Show one real before-and-after transformation supported by the build evidence.
- Draw one simple system diagram. For full-stack work, label frontend, backend, and third-party services where they exist. For work inside one layer, diagram that layer's meaningful sub-parts instead of inventing the rest of the stack.
- Put each relevant technology inside the step where it performs a job. Do not create a detached technology inventory.
- Include one short, unscored pause-and-answer check. Do not add quiz options, points, grades, or a playground.
- Never include secrets, tokens, private customer data, hidden prompts, or confidential chat content in the generated page.
- Use this exact privacy boundary: **Teach generates and stores the finished lesson locally. It does not publish or host the page.** Do not claim that the coding agent or its model is offline.

When a follow-up changes the facts, rerun the investigator. When it changes only the explanation, reuse the validated build map and rerun the learning designer.

## Product boundary

Teach generates a local learning module. It does not host lessons, create accounts, save progress, run analytics, or call a model from the finished page.
