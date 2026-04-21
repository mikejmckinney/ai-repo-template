# Phase 4 Claude-path verification scratch

This file exists only to verify that Phase 4 of
`.github/prompts/pr-resolve-all.md` resolves bot-authored review threads
after Claude lands a fix. It contains two deliberate nits to attract
inline comments from Gemini, Copilot review, and Codex Connector:

1. **Typo**: this sentance has a intentional typo to bait a reviewer.
2. **Grammar**: the following bullet have a subject-verb agreement problem
   that bot reviewers reliably flags as a nit.

Once this PR receives bot reviews on the nits above, we label it with
`claude-fix` + `auto-resolve-threads` and confirm:

- Claude pushes a fix commit addressing the nits.
- Claude posts a Phase 1 Issue/Suggestion Index and a Phase 3 Resolution
  Report with a Phase 4 subsection.
- Each bot-authored thread receives an audit-trail reply citing the
  resolving SHA and ISS-NN, then closes via `resolveReviewThread`.
- Any human-authored thread seeded on this PR stays **open**.

This file will be removed together with the scratch branch after
verification completes.
