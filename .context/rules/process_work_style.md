# Work style, testing, validation

> Extracted from AGENTS.md §"Work style", §"Testing requirements", and §"Validation" in PR for #253 (ADR-021).
> Read before any non-trivial implementation.

## Work style

- **Branch first, then commit per task boundary.** You MUST be on a non-default branch *before* making any non-trivial edit — branching is a precondition for the work, not a wrap-up step. You MUST also commit (and push, when a remote exists) at least once per task boundary, *not* only at the end of a multi-task session. Working directly on `main`/`master` is not acceptable, even for "I'll branch later" exploration. Branch naming: `feature/<role>-<task-id>` is defined in `docs/guides/multi-agent-coordination.md` §"Branch-Per-Role Model"; a `fix/<issue>-<slug>` form is also acceptable for bug-fix branches when that naming is clearer. See ADR-012 for why this rule needs explicit statement.
- **Small, reversible changes** beat rewrites. Prefer the minimal diff that fully solves the task. Minimal diff means keep the implementation scope small and reversible. It does not mean the parent/default agent should avoid delegation. Do not skip role dispatch merely to keep the work inside one agent.
- **No drive-by refactors.** If you spot something unrelated worth fixing, file a follow-up task instead of bundling it in.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.
- **Run the pre-push review on non-trivial diffs (SHOULD).** Before `git push` on any non-trivial change, run [`.github/prompts/pre-push-review.md`](../../.github/prompts/pre-push-review.md) — Critic + lint + `./test.sh` against the working-tree diff, with a single Markdown summary you read before pushing. "Non-trivial" = >50 LOC changed OR any change to `scripts/*.sh`, `.github/workflows/*.yml`, role files (canonical `.agents/*.md` or platform overlays `.github/agents/*.agent.md`, `.claude/agents/*.md`), per-concern process rules (`.context/rules/process_*.md`, `.context/rules/domain_*.md`, `.context/rules/repo_*.md`, `.context/rules/agent_ownership.md`), or `AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md`. Trivial diffs and revert/bot PRs are exempt. The DevOps role MUST run it for shell/workflow changes (see `.agents/devops.md` Do list).

## Testing requirements

- Follow the test pyramid: many unit tests, fewer integration tests, minimal E2E tests.
- Write tests before or alongside implementation (TDD preferred).
- All behavioral changes must include appropriate tests.
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

### Supporting validation

Unit tests, integration tests, `./test.sh`, lint, pre-commit, schema validators,
sandbox verification, and CI are supporting regression and hygiene evidence.
They do not replace user-outcome validation unless the user outcome is itself a
scripted command or automated check.

A green CI run with no user-outcome evidence is not ready for review.

- Run the repo's verification commands (prefer those documented in AI_REPO_GUIDE.md) before declaring done.
- Ensure all tests pass locally before pushing.
- Check that CI pipeline is green.

## Evidence taxonomy (schema_version: 2 — ADR-028)

When recording verification under `parent_compliance.verification_evidence`
(schema_version 2), each entry declares an evidence **class** plus a typed
**artifact** shape. ADR-028 introduces three classes:

| Class | What it proves | Required artifact keys | Typical artifact |
|---|---|---|---|
| `logical` | Static / by-inspection consistency (cross-references, supersession notes, schema additions match docs) | `path`, `section` | Repo-relative path + section heading where the claim is verifiable. |
| `mechanical` | A repeatable command produces a determinate outcome | `command` plus one of `expected_exit_code` or `expected_output_regex` | `bash test.sh` exit 0; `grep -q '^X' file` exit 0; `python3 scripts/foo.py --check` exit 0. |
| `pragmatic` | An external system/UI/observed behavior matches expectations | `url`, `observed_outcome` | A GitHub permalink to a comment/PR/file plus a one-sentence outcome ('comment posted, length 3264 bytes verified'). |

### Outcome → required-class matrix

Which class is *minimally adequate* depends on what the outcome claims:

| Outcome class | Minimum acceptable evidence class | Why |
|---|---|---|
| Schema / contract / rule edit (no runtime change) | `logical` | The change *is* the artifact; mechanical or pragmatic checks add no signal. |
| Validator / script / workflow / code change with executable surface | `mechanical` | The change has a runnable shape; a green command run is the cheapest determinate proof. |
| User-facing behavior, agent runtime dispatch, external system interaction, observed UI state | `pragmatic` | Logical and mechanical checks cannot prove an agent runtime, GitHub comment, or human-facing outcome actually occurred; pragmatic evidence is required. |

A stronger class always satisfies a weaker class's requirement, but a weaker
class does **not** satisfy a stronger class's requirement. Substituting
`logical` evidence ("the ADR says so") for a `pragmatic` outcome
("observed in production") is the failure mode ADR-028 binds Judge to
flag at diff-gate (see `.agents/judge.md` item 21).

The validator checks artifact **shape**, not semantic adequacy. Judge is
responsible for the outcome→class mapping at diff-gate; Critic is the
backstop for selectively-quoted or minimum-satisfying evidence. See
`docs/decisions/adr-028-gate-status-schema-and-evidence-taxonomy.md`
§ "Known limitations".
