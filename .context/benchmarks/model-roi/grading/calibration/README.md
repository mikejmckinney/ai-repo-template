# Grading calibration

Anchor runs validate a new `score_set_id` before it is used for routing decisions.

## Procedure

1. Copy `anchor-manifest.tsv.example` to a sealed maintainer path (not committed with
   real alias mappings until after grading lock).
2. List 2–4 completed benchmark artifacts with known reference scores from a prior
   locked score set or maintainer adjudication.
3. Run the full grading pipeline under a **calibration** `score_set_id`.
4. Compare compiled scores to anchor expectations with `compare-grade-sets.py`.
5. If mean absolute category delta exceeds 3 points, revise task spec anchors or
   grader prompt before promoting the score set to canonical.

Calibration runs use the same scripts as production grading; only the `score_set_id`
label differs.
