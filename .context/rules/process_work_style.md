# Work style, testing, validation

> Extracted from AGENTS.md §"Work style", §"Testing requirements", and §"Validation" in PR for #253 (ADR-021).
> Read before any non-trivial implementation.

## Work style

- **Branch first, then commit per task boundary.** You MUST be on a non-default branch *before* making any non-trivial edit — branching is a precondition for the work, not a wrap-up step. You MUST also commit (and push, when a remote exists) at least once per task boundary, *not* only at the end of a multi-task session. Working directly on `main`/`master` is not acceptable, even for "I'll branch later" exploration. Branch naming: `feature/<role>-<task-id>` is defined in `docs/guides/multi-agent-coordination.md` §"Branch-Per-Role Model"; the `fix/<issue>-<slug>` form is shown by example in `.context/state/coordination.md` (no formal definition — follow the pattern). See ADR-012 for why this rule needs explicit statement.
- **Small, reversible changes** beat rewrites. Prefer the minimal diff that fully solves the task.
- **No drive-by refactors.** If you spot something unrelated worth fixing, file a follow-up task instead of bundling it in.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.
- **Run the pre-push review on non-trivial diffs (SHOULD).** Before `git push` on any non-trivial change, run [`.github/prompts/pre-push-review.md`](../../.github/prompts/pre-push-review.md) — Critic + lint + `./test.sh` against the working-tree diff, with a single Markdown summary you read before pushing. "Non-trivial" = >50 LOC changed OR any change to `scripts/*.sh`, `.github/workflows/*.yml`, role files (`.github/agents/*.agent.md`, `.claude/agents/*.md`), per-concern process rules (`.context/rules/process_*.md`, `.context/rules/domain_*.md`, `.context/rules/repo_*.md`, `.context/rules/agent_ownership.md`), or `AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md`. Trivial diffs and revert/bot PRs are exempt. The DevOps role MUST run it for shell/workflow changes (see `.github/agents/devops.agent.md` Do list).

## Testing requirements

- Follow the test pyramid: many unit tests, fewer integration tests, minimal E2E tests.
- Write tests before or alongside implementation (TDD preferred).
- All behavioral changes must include appropriate tests.
- CI must pass before marking tasks complete. If CI fails:
  1. Read the error logs
  2. Fix the underlying issue
  3. Push and retry until green

## Validation

- Run the repo's verification commands (prefer those documented in AI_REPO_GUIDE.md) before declaring done.
- Ensure all tests pass locally before pushing.
- Check that CI pipeline is green.
