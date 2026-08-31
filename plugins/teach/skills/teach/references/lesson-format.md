# Lesson format

The Learning Designer writes one UTF-8 JSON object. Every `evidence_ids` array refers to evidence declared in the validated build map.

## `meta`

Required fields:

- `slug`: lowercase words separated by hyphens
- `title`: what the learner will understand
- `subject`: short label for the build
- `one_liner`: the outcome in plain English
- `learning_goal`: what the learner will be able to explain
- `minutes`: integer from 1 to 10

## `story`

Use exactly three chapters in this order: `problem`, `built`, `works`.

Every chapter contains `id`, `kicker`, `title`, `plain`, `takeaway`, and one or more `evidence_ids`.

### `problem`

Text only. Explain why the work started.

### `built`

Add one `example` object:

```json
{
  "before": "The confirmed state before",
  "after": "The confirmed state after",
  "insight": "What changed in the learner's mental model",
  "evidence_ids": ["e1", "e2"]
}
```

Do not invent counts or outcomes to make the example feel concrete.

### `works`

Add one `visual` with `type: "flow"`, a short `title`, and three to five `steps`.

Each step contains:

- `label`: one short action
- `detail`: one plain-language explanation
- `area_id`: an area ID from the build map
- `area_name`: the exact learner-facing area name from the build map
- `evidence_ids`: evidence for the step
- optional `technology`: an object with `name`, a one-sentence `explanation`, and `evidence_ids`

Technology names must come from the build map. Its evidence IDs must belong to that technology in the build map and must also support the flow step where it appears. There is no top-level technologies section.

## `check`

Add one unscored recall object after the story:

```json
{
  "question": "One question the learner can answer in their own words",
  "answer": "A short factual answer",
  "why": "Why this idea matters",
  "evidence_ids": ["e3"]
}
```

Do not add multiple choice, points, grades, quiz language, a playground, glossary tooltips, or a dictionary section. The build script validates the lesson against the build map and preserves both JSON files beside the generated page.
