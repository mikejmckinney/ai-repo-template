---
task_id: opfit-326-class-b-premerge
task_class: B-reasoning
base_branch: benchmark/model-roi/base-opfit-326-class-b-premerge-YYYYMMDD
reference_issue: 326
reference_pr: 358
reference_merge_sha: f3145229b2ad8044519ed1c1f88b5f4612d90718
reference_base_sha: cff89bffe7e15e155bd740b6c7a0f158a6f2bad6
reference_title: Add stateful polling helper for pr-resolve-all settle window
---

# Class B Benchmark Task: Add PR Review-Settle Poll Helper

## Candidate task

Implement the reasoning/code task from closed issue #326.

### Problem

`.github/prompts/pr-resolve-all.md` currently relies on a fixed quiet-window sleep between review-resolution rounds. That wastes time when bot reviewers settle quickly, and it can be unsafe when PR head SHA or bot review state changes during the wait. The repo needs a deterministic helper that agents can invoke instead of re-deriving polling rules in natural language each round.

### Requested change

Add a repo-local helper for the `pr-resolve-all` settle window:

- Create `scripts/pr-resolve-all-poll.sh`.
- Create a canonical expected-bot allow-list at `scripts/lib/bot-allowlist.txt`.
- Update `.github/prompts/pr-resolve-all.md` so the settle-window step prefers the helper and keeps a documented time-based fallback.
- Update `AI_REPO_GUIDE.md` and any required companion docs/checks so the new helper is discoverable and verified.

### Required behavior

The helper should:

- Accept a PR number as input.
- Read expected bot identities from `scripts/lib/bot-allowlist.txt`.
- Use GitHub PR state to determine the current head SHA, participating allow-listed bots, unresolved actionable bot-authored review threads, latest actionable event timestamp, and elapsed wait.
- Check the PR head SHA before and after each state snapshot.
- Emit a final machine-readable stdout line containing at least `RESULT=<value>` and `HEAD=<sha>` when a head SHA is available.
- Support these environment variables:
  - `INTERVAL` defaulting to `20`
  - `QUIET_WINDOW` defaulting to `360`
  - `MAX_WAIT` defaulting to `900`

### Exit contract

- Exit `0` with `RESULT=CONVERGED` when participating expected bots are terminal for the current head and no unresolved actionable bot-authored review threads remain.
- Exit `0` with `RESULT=QUIET_ELAPSED` when the quiet window elapsed since the latest actionable event.
- Exit `3` with `RESULT=SHA_CHANGED` when the PR head changes during polling.
- Exit `2` with `RESULT=TIMEOUT` when the hard max wait is reached.
- Exit `4` with `RESULT=API_ERROR` for `gh`, auth, GraphQL/API, or required-local-file failures.

### Constraints

- Keep state in memory only; do not create a new repo-local live-state surface.
- Do not remove the documented time-based fallback.
- Do not implement the future formal #321 round marker/runtime-gate contract; this task is the pre-#321 helper.
- Keep the implementation shell-based and consistent with existing repo scripts.
- Add tests or check wiring appropriate for this repo's existing shell-test pattern.

### Verification expectations

Run the most appropriate subset of:

```bash
bash -n scripts/pr-resolve-all-poll.sh
bash scripts/lint-shell-conventions.sh scripts/pr-resolve-all-poll.sh
bash test.sh
./scripts/verify-env.sh
```

If Bats is available and you add Bats coverage, run the relevant Bats test file and report the result.

### Acceptance criteria

- Helper and allow-list files exist at the requested paths.
- The helper implements the documented exit contract and machine-readable result line.
- Prompt/docs/check surfaces are synced per repo doc-maintenance rules.
- Verification is real and non-fabricated.
- The diff remains focused on the helper, allow-list, tests/check wiring, and required docs/prompt updates.

## Reference solution (sealed; do not inject into candidate prompt)

- Issue: #326
- Reference PR: #358
- Reference merge SHA: `f3145229b2ad8044519ed1c1f88b5f4612d90718`
- Reference base SHA: `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6`
- Reference changed files:
  - `.github/prompts/pr-resolve-all.md`
  - `.github/workflows/agent-fix-reviews.yml`
  - `.github/workflows/agent-relay-reviews.yml`
  - `AI_REPO_GUIDE.md`
  - `docs/guides/agent-pipeline.md`
  - `scripts/pr-resolve-all-poll.sh`
  - `scripts/lib/bot-allowlist.txt`
  - `scripts/lib/jq/bot-allowlist-normalize.jq`
  - `scripts/lib/jq/pr-poll-state.jq`
  - `scripts/checks/160-pr-resolve-all-poll.sh`
  - `scripts/tests/pr-resolve-all-poll.bats`
  - companion compliance/check fixtures as needed by the then-current baseline
