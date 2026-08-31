# Lesson format

Create a UTF-8 JSON file with these top-level keys.

## `meta`

Required fields:

- `slug`: lowercase words separated by hyphens
- `title`: what the learner will understand
- `subject`: short label for the thing they built
- `one_liner`: the outcome in plain English
- `minutes`: estimated reading and interaction time

## `story`

Use exactly 3 chapters, in this order:

1. `problem`: why the work started and what was hard before
2. `built`: what now exists and what it lets the person do
3. `works`: the shortest accurate end-to-end explanation

Each chapter has:

- `id`, `kicker`, `title`, `plain`, and `takeaway`
- `problem` and `built` stay text-only.
- `works` has one `visual` with `type: "flow"` and 3 to 5 `steps`.

Each flow step has:

- `label`: the action in a few words
- `detail`: one short explanation of what happens

The visual may include a short `title`. It must trace the complete path from trigger to visible result.

## `technologies`

Optional array of 0 to 6 tools that genuinely help explain the build. Each item has:

- `name`: the real technology or product name
- `explanation`: one sentence, written for an 18-year-old, covering what it is and the job it performs here

Do not add a tool merely because it appears in a file. Include only tools a learner needs to understand the three-part story.

Teach lessons do not include quizzes, playgrounds, inline glossary tooltips, or dictionary sections. The build script validates this shape and embeds it into a standalone page. Preserve the JSON as the editable source of truth for later revisions.
