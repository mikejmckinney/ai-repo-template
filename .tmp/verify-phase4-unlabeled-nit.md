# Verify Phase 4 (unlabeled negative case) — review-bait scratch doc

This file exists only on the
`claude/verify-phase4-unlabeled-20260421-2349` branch.

**V4 — Unlabeled negative**: this PR will be labeled **only** `claude-fix`
(not `auto-resolve-threads`). The point is to confirm Phase 4 is **skipped
entirely** when the opt-in label is absent — i.e., the gate holds from the
other direction (V2 proved Phase 4 runs when the label is present; V4
proves it does nothing when the label is absent).

DO NOT MERGE.

## Deliberate nits below

- Each of the bot reviewers are expected to flag the subject-verb disagreement here.
- This sentance intentionally contains a typo.
- Seperate items on the check list should trigger a spelling flag.

## Expected outcome

- `agent-fix-reviews.yml` fires on the `labeled` event when `claude-fix`
  is applied.
- Claude posts the Phase 1 Issue/Suggestion Index.
- Claude pushes a fix commit addressing the nits.
- Claude's Phase 3 Resolution Report **should include a Phase 4
  subsection** that says approximately:
  `Label auto-resolve-threads not present — skipping thread resolution.`
  (wording per `.github/prompts/pr-resolve-all.md` Phase 4 report
  section).
- **No** audit-trail replies posted on any review thread.
- **All** review threads remain `isResolved: false`.
