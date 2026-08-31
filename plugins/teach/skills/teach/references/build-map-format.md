# Build-map format

The Build Investigator writes one UTF-8 JSON object.

```json
{
  "meta": {
    "subject": "Short name",
    "summary": "One factual sentence about the finished capability"
  },
  "scope": {
    "mode": "full-stack",
    "areas": [
      {
        "id": "frontend",
        "name": "Frontend",
        "role": "What this area does in plain language",
        "components": ["Only the meaningful pieces"]
      }
    ]
  },
  "problem": {
    "summary": "Why the work started",
    "evidence_ids": ["e1"]
  },
  "build": {
    "summary": "What now exists",
    "evidence_ids": ["e2"]
  },
  "system_flow": [
    {
      "id": "trigger",
      "label": "Short step label",
      "detail": "What happens",
      "area_id": "frontend",
      "evidence_ids": ["e3"]
    }
  ],
  "technologies": [
    {
      "name": "Real technology name",
      "job": "The job it performs here",
      "relevance": "Why the learner needs it for this mental model",
      "evidence_ids": ["e4"]
    }
  ],
  "important_decisions": [
    {
      "summary": "A decision, mistake, or fix that changed the result",
      "evidence_ids": ["e5"]
    }
  ],
  "discarded_details": [
    {
      "detail": "A discovered but irrelevant detail",
      "reason": "Why it does not belong in the lesson"
    }
  ],
  "uncertainties": [],
  "evidence": [
    {
      "id": "e1",
      "kind": "code",
      "source": "relative/path.py:useful_symbol",
      "supports": "The exact claim this source supports"
    }
  ]
}
```

Rules enforced by the validator:

- `scope.mode` is `full-stack`, `single-area`, or `cross-cutting`.
- Use one to six system areas and three to seven flow steps.
- Area and evidence IDs are lowercase words joined by hyphens and are unique.
- Every flow step points to a declared area.
- Every factual section points to existing evidence.
- Use no more than eight relevant technologies.
- Evidence kinds are `conversation`, `code`, `documentation`, `runtime`, or `test`.
- `uncertainties` contains plain strings. Leave it empty only when the important path is confirmed.
