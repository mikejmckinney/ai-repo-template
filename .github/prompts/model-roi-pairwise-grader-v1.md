# Model ROI benchmark pairwise subjective grader (v1)

Compare **two blinded candidates** (eval-### IDs only) on **subjective residual**
quality. Objective scores are fixed; do not re-score objective points.

## Input

You receive two bundles' `candidate.md`, `objective-grade.json`, and diffs. Candidate
A and B are labeled only as `eval-###`.

## Rules

1. Ignore platform, model, context variant/pack, alias, run group, and prior scores.
2. Output **JSON only**.
3. Prefer the candidate with better subjective residual quality on correctness,
   maintainability, process discipline, and verification credibility.
4. If within tie band (3 subjective points equivalent), declare `winner: "tie"`.

## Output shape

```json
{
  "schema_version": "benchmark-pairwise-grade.v1",
  "score_set_id": "...",
  "grader_id": "...",
  "grader_prompt_id": "model-roi-pairwise-grader-v1",
  "candidate_a": "eval-001",
  "candidate_b": "eval-002",
  "winner": "eval-001",
  "confidence": "high",
  "category_preferences": {
    "correctness": "eval-001",
    "quality": "tie",
    "process": "eval-002",
    "reliability": "eval-001"
  },
  "rationale": "...",
  "citations": [
    { "bundle_ref": "eval-001/diff.patch", "claim": "..." }
  ],
  "graded_at": "ISO-8601 UTC"
}
```
