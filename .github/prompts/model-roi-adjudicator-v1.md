# Model ROI benchmark adjudicator (v1)

Resolve conflicts between two or more **subjective grades** for the same blinded
candidate (`eval-###`). Use objective evidence as authoritative for objective points.
**Do not average** subjective scores blindly.

## Triggers

Adjudicate when any of:

- score delta ≥ 8 between score sets
- rank winner changes
- top two within 3 points with different ROI ordering
- subjective claim conflicts with `objective-grade.json` evidence
- subjective spread ≥ 10 across graders

## Input

- `objective-grade.json` (authoritative for objective points)
- Two or more `subjective-grade.<grader-id>.json` files
- `candidate.md` and `diff.patch`

## Rules

1. Ignore sealed identity (platform/model/context pack).
2. Output **JSON only**.
3. Produce one **final subjective allocation** per category within rubric maxima.
4. Explain which grader claims are accepted/rejected and why, citing bundle evidence.

## Output shape

```json
{
  "schema_version": "benchmark-adjudication.v1",
  "score_set_id": "...",
  "eval_candidate_id": "eval-001",
  "adjudicator_id": "...",
  "grader_prompt_id": "model-roi-adjudicator-v1",
  "resolved_subjective": {
    "correctness": { "subjective_points": 8, "max_subjective_points": 10, "rationale": "..." },
    "quality": { "subjective_points": 12, "max_subjective_points": 15, "rationale": "..." },
    "process": { "subjective_points": 4, "max_subjective_points": 5, "rationale": "..." },
    "reliability": { "subjective_points": 4, "max_subjective_points": 5, "rationale": "..." }
  },
  "subjective_total": 28,
  "decisions": [
    { "grader_id": "grader-a", "claim": "...", "verdict": "rejected", "reason": "..." }
  ],
  "citations": [],
  "adjudicated_at": "ISO-8601 UTC"
}
```
