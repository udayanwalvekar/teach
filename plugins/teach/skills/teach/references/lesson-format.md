# Lesson format

Create a UTF-8 JSON file with these top-level keys.

## `meta`

Required fields:

- `slug`: lowercase words separated by hyphens
- `title`: what the learner will understand
- `subject`: short label for the thing they built
- `one_liner`: the outcome in plain English
- `builder_win`: one concrete sentence about what they accomplished
- `minutes`: estimated reading and interaction time
- `chat_context`: a short phrase included when copying a follow-up question

## `story`

Use 3 to 6 chapters. Each chapter has:

- `id`, `kicker`, `title`, `plain`, and `takeaway`
- Optional `analogy` with `title`, `body`, `mapping[]`, and `limit`
- Each `mapping` item has `familiar` and `real`
- One `visual`

Supported visual types:

- `flow`: `steps[]` with `label`, `detail`, and optional `technical`
- `layers`: `layers[]` with `label`, `detail`, and optional `technical`
- `compare`: `left` and `right`, each with `label`, `detail`, and `points[]`
- `timeline`: `steps[]` with `label`, `detail`, and optional `technical`
- `map`: `nodes[]` with `id`, `label`, `detail`, and optional `technical`; `links[]` with `from` and `to`

Every visual may include a short `title`. At least one chapter must trace the complete end-to-end path through the real build.

## `stack`

This is the compact map of the actual technologies used in the build. Include:

- `summary`: a plain-English description of the overall stack, including any expected layer that is intentionally absent
- `items`: 2 to 8 entries, each with `layer`, `technology`, `role`, and `connection`

`layer` is the human-readable part of the system, such as interface, backend, data, or hosting. `technology` uses the real product or framework name. `role` explains its one job in this build. `connection` explains what it receives and where its result goes next.

If a function call is important to the build, include it in the relevant role or connection with the caller, input, work, result, and next destination.

## `concepts`

This is the complete jargon dictionary for the page. Every technical word used in visible copy must have an entry.

Each item has:

- `term`: the preferred visible name
- Optional `aliases[]`: other visible forms that should open the same definition
- `plain`: a short ordinary-language definition
- `in_build`: what the term specifically means or does in the builder's system

The lesson shell automatically adds a dotted underline and inline tooltip to occurrences of each term and alias. Keep aliases specific enough to avoid matching ordinary words.

## `playground`

Include `title`, `description`, and 2 to 4 `scenarios`. Each scenario has `label`, `tone` (`normal`, `broken`, or `recovered`), `headline`, `body`, and `trace[]`.

## `quiz`

Use 3 to 5 items. Each item has `question`, `choices[]`, zero-based `answer`, and `explanation`. Keep choice shapes parallel and make distractors plausible.

## `followups`

Use 3 to 5 suggested questions that naturally deepen the lesson.

The build script validates this shape and embeds it into a standalone page. Preserve the JSON as the editable source of truth for later questions.
