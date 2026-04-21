# Phase 4 Claude-path verification scratch (attempt #3)

Attempt history:
- Attempt #1 (PR #95, closed): 7 findings — fixed in 12828aa
- Attempt #2 (PR #96, closed): Codex found phase-ordering regression
  in workflow inline prompts — fixed in e76f56f
- Attempt #3 (this PR): running against the corrected inline prompts.

This file contains two deliberate nits to attract inline bot comments:

1. **Typo**: this sentence has an intentional typo to bait a reviewer.
2. **Grammar**: the following bullet has a subject-verb agreement problem
   that bot reviewers reliably flag as a nit.

Once bot reviews land, we apply `claude-fix` + `auto-resolve-threads` to
trigger `agent-fix-reviews.yml` end-to-end. V2 pass criteria:

- Workflow fires on the `labeled` event (retroactive trigger path).
- Claude posts a Phase-1 Issue/Suggestion Index as its own PR comment.
- Claude pushes a fix commit resolving every bot-surfaced ISS-NN.
- Claude executes Phase 4 **before** posting Phase 3 (per the corrected
  canonical ordering) and collects results.
- Claude posts a Phase-3 Resolution Report that **includes** a Phase 4
  subsection listing every thread considered.
- Each bot-authored thread that matched `✅ Fixed` receives an
  audit-trail reply (`Resolved by <agent> in <sha> (ISS-NN…)`) and
  closes via `resolveReviewThread`, **even when `isOutdated == true`**.
- Any human-authored thread seeded on this PR stays **open** with no
  audit reply (V5 evidence).

This file dies with the branch. See PR #93 for context.
