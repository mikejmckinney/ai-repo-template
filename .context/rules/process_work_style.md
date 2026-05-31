# Work style, testing, validation

> Extracted from AGENTS.md §"Work style", §"Testing requirements", and §"Validation" in PR for #253 (ADR-021).
> Read before any non-trivial implementation.

## Work style

- **Branch first, then commit per task boundary.** You MUST be on a non-default branch *before* making any non-trivial edit — branching is a precondition for the work, not a wrap-up step. You MUST also commit (and push, when a remote exists) at least once per task boundary, *not* only at the end of a multi-task session. Working directly on `main`/`master` is not acceptable, even for "I'll branch later" exploration. Branch naming: use `feature/<role>-<task-id>` as the standard branch-per-role form from [docs/guides/multi-agent-coordination.md](../../docs/guides/multi-agent-coordination.md); a `fix/<issue>-<slug>` form is also acceptable for bug-fix branches when that naming is clearer. See ADR-012 for why this rule needs explicit statement.
- **Small, reversible changes** beat rewrites. Prefer the minimal diff that fully solves the task. Minimal diff means keep the implementation scope small and reversible. It does not mean the parent/default agent should avoid delegation. Do not skip role dispatch merely to keep the work inside one agent.
- **No drive-by refactors.** If you spot something unrelated worth fixing, file a follow-up task instead of bundling it in.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.
- **Run the pre-push review on non-trivial diffs (SHOULD).** Before `git push` on any non-trivial change, run [`.github/prompts/pre-push-review.md`](../../.github/prompts/pre-push-review.md) — Critic + lint + `./test.sh` against the working-tree diff, with a single Markdown summary you read before pushing. "Non-trivial" = >50 LOC changed OR any change to `scripts/*.sh`, `.github/workflows/*.yml`, role files (canonical `.agents/*.md` or platform overlays `.github/agents/*.agent.md`, `.claude/agents/*.md`), per-concern process rules (`.context/rules/process_*.md`, `.context/rules/domain_*.md`, `.context/rules/repo_*.md`, `.context/rules/agent_ownership.md`), or `AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md`. Trivial diffs and revert/bot PRs are exempt. The DevOps role MUST run it for shell/workflow changes (see `.agents/devops.md` Do list).

## Testing requirements

- Follow the test pyramid: many unit tests, fewer integration tests, minimal E2E tests.
- Write tests before or alongside implementation (TDD preferred).
- All behavioral changes must include appropriate tests.
- A pragmatic sandbox/dogfood test must be performed and `Sandbox issue:` and `Sandbox PR:` labels (with real URLs) must appear in the test/verification section per ADR-029. Read and follow the [sandbox verification playbook](/docs/guides/sandbox-verification.md) which details the process for using sandbox and which sandbox instance to use.
- CI must pass before marking tasks complete. If CI fails:
  1. Read the error logs
  2. Fix the underlying issue
  3. Push and retry until green

## Validation

### Primary validation: User outcome / 15-minute test

Before marking any non-exempt issue implementation complete, perform the issue's
`User outcome (15-minute test)` against the actual problem statement and record
the result with concrete evidence in the PR body.

Outcome validation answers: did the shipped artifact solve the user's stated
problem?

If the user outcome does not resolve the problem statement, do not patch around
the test merely to make it pass. Stop, document the framing disconnect, and
escalate to the user or revise the issue/plan.

A pragmatic sandbox/dogfood test with concrete steps is required in the
verification section of issues and plans. Read and follow the
[sandbox verification playbook](/docs/guides/sandbox-verification.md)
playbook which details the process for using sandbox and which sandbox instance to use.
The `Sandbox issue:` and `Sandbox PR:`
labels (canonical literals per ADR-029, the PR template, and Judge diff-gate
item 20) should be linked as proof that the user outcome solves the problem.
For example,
An issue opened to add a .md file that walks an agent through the development and
implementation of a new feature should, as part of the test and validation, walk
through and run the process defined in the .md file in a sandbox or test environment
to verify that it meets the user outcome which in turn, should solve the problem.
If this does not happen, then there is a disconnect between the user outcome
and the problem statement and that should be raised to the user for review.

### Supporting validation

Unit tests, integration tests, `./test.sh`, lint, pre-commit, schema validators,
and CI are supporting regression and hygiene evidence.
They do not replace user-outcome validation.  Artifact creation, static prose
review, schema validation, or logical similarity are not sufficient evidence for
operational process/user-outcome claims.

A green CI run with no user-outcome evidence is not ready for review.

- Run the repo's verification commands (prefer those documented in AI_REPO_GUIDE.md) before declaring done.
- Ensure all tests pass locally before pushing.
- Check that CI pipeline is green.
