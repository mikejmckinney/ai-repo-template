# Phase 4 Claude-path verification scratch (attempt #2)

This file exists only to verify that Phase 4 of
`.github/prompts/pr-resolve-all.md` resolves bot-authored review threads
after Claude lands a fix. Attempt #1 (PR #95) surfaced 7 real findings
in the source branch's content; all were hotfixed in 12828aa and this
attempt runs against the corrected Phase 4.

It contains two deliberate nits to attract inline comments from bot
reviewers:

1. **Typo**: this sentance has a intentional typo to bait a reviewer.
2. **Grammar**: the following bullet have a subject-verb agreement problem
   that bot reviewers reliably flags as a nit.

Once bot reviews land, this PR will be labeled
`claude-fix` + `auto-resolve-threads` and the V2 pass criteria are:

- Claude pushes a fix commit addressing the nits (or the inherited
  source-branch review comments, whichever is easier to verify).
- Claude posts a Phase 1 Issue/Suggestion Index.
- Claude posts a Phase 3 Resolution Report that **includes** a Phase 4
  subsection (not appends — Phase 4 now runs before Phase 3 posts).
- Each bot-authored thread receives an audit-trail reply citing the
  resolving SHA and ISS-NN, then closes via `resolveReviewThread`,
  **even if the thread has become `isOutdated`** due to the fix commit
  moving the commented line.
- Any human-authored thread seeded on this PR stays **open**.

This file will be removed together with the scratch branch after
verification completes.
