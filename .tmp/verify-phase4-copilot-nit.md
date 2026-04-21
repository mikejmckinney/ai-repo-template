# Verify Phase 4 (Copilot path) — review-bait scratch doc

This file exists only on the `copilot/verify-phase4-copilot-20260421-2241`
branch. It is seeded with deliberate nits so that bot reviewers
(Gemini, Copilot, Codex) will file inline review comments that
`agent-relay-reviews.yml` + the Copilot cloud agent can then resolve.

DO NOT MERGE — this PR is the live end-to-end V3 verification for
ADR-007 Phase 4 (Copilot path).

## Deliberate nits below

- Seperate items in this bullet list should trigger a spelling flag.
- Each of the reviewer bots are expected to flag the subject-verb disagreement in this sentence.
- This sentance intentionally contains a typo that Gemini typically surfaces.

## Expected outcome

Once the bots file inline review comments, this PR will be labeled
`copilot-relay` + `auto-resolve-threads`. The relay workflow posts an
`@copilot follow .github/prompts/pr-resolve-all.md` comment; Copilot's
cloud agent reads the prompt and executes phases 1 → 2 → 4 → 3. Each
bot-authored thread whose `ISS-NN` clears with `✅ Fixed` should receive
an audit-trail reply of the form
`Resolved by copilot (via agent-relay-reviews) in <SHA> (ISS-NN).` and
close via `resolveReviewThread`.

Human-authored threads (if any) must remain open.
