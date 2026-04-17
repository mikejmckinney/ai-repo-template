# AGENTS.md

## Template detection (important)
- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `ai-repo-template` (or `mikejmckinney/ai-repo-template`), or the
  legacy name `dotfiles` / `mikejmckinney/dotfiles` (still honored for one release):
  - Treat README.md, AI_REPO_GUIDE.md, and CLAUDE.md as the template's docs; do NOT regenerate/overwrite them.
- Otherwise:
  - If README.md or AI_REPO_GUIDE.md contains `TEMPLATE_PLACEHOLDER`, treat them as stubs:
    replace README.md with project-specific README, and regenerate AI_REPO_GUIDE.md from the repo's real assets (./.context/**, ./docs/**, source).
  - If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`:
    replace it with the actual repository path (e.g., `owner/repo`) detected from `git remote -v`.

## Critical thinking and communication
Agents must reason critically rather than agree by default. The bar is "objective and evidence-based," not "agreeable."

- **Push back when warranted.** If the user's plan, premise, or proposed code has a flaw, say so directly and explain why. Don't hedge to be polite. If a better approach exists, recommend it and justify the tradeoff.
- **Calibrate confidence.** State what you verified vs. what you assumed. When something is uncertain, say "uncertain" — don't pad with false confidence and don't hide behind vague qualifiers.
- **Don't guess APIs, file contents, or runtime behavior.** Verify by reading the file or searching the codebase. If you can't verify, say so explicitly rather than asserting.
- **Compare approaches honestly.** When multiple options are viable, name the tradeoffs (cost, risk, reversibility, blast radius) before recommending one.
- **Default to concise.** Add structure only when it earns its keep; don't pad length or drop detail the answer needs.  if a complete answer genuinely requires length, use multiple parts or multiple responses rather than cutting corners.

## Work style
- **Small, reversible changes** beat rewrites. Prefer the minimal diff that fully solves the task.
- **No drive-by refactors.** If you spot something unrelated worth fixing, file a follow-up task instead of bundling it in.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.

## Truth hierarchy
When information conflicts, use this priority order:
1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

## Role selection (multi-agent workflow)
This template supports parallel role-specialized agents. Before editing any file:
1. Identify your role (or ask the user which role to adopt). Role definitions live in `.github/agents/*.agent.md` — Architect, Judge, Critic, PM, Frontend, Backend, QA, DevOps, Docs.
2. Read `.context/rules/agent_ownership.md` to confirm which paths your role owns.
3. Read `.context/state/coordination.md` to see active locks and claim your task before editing.
4. Stay inside your owned paths. Any cross-role edit requires a PM claim. **Never guess ownership silently** — escalate to PM.
5. Full workflow (plan-gate → dispatch → parallel implementation → QA → diff-gate → merge) is documented in `docs/guides/multi-agent-coordination.md`.

## Context pack usage
- Start with `.context/00_INDEX.md` for project overview
- Check `.context/state/_active.md` or `task_*.md` for current work in progress
- Reference `.context/rules/` for constraints that must not be violated
- Use `.context/roadmap.md` to understand project phases
- Reference `.context/vision/` for design mockups and architecture

## Onboarding procedure
1. Read `/AI_REPO_GUIDE.md`.
2. Read `.context/00_INDEX.md` if it exists.
3. Check `.context/state/_active.md` or `task_*.md` for cognitive handoff from previous sessions.
4. If AI_REPO_GUIDE.md missing or stale: follow `.github/prompts/repo-onboarding.md` to rebuild context.

## Ongoing maintenance
- If your PR changes build/run/test/lint commands, layout, entry points, configs, conventions, or troubleshooting:
  update `/AI_REPO_GUIDE.md` in the same PR (or explicitly say "AI_REPO_GUIDE.md: no changes required").
- Update `.context/state/task_*.md` when switching tasks to enable session handoff.

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

## Code quality
Universal SOLID / TDD / clean-code rules are defined as Hard rules H1–H8 and Soft rules S1–S6 in `.context/rules/domain_code_quality.md`. Secrets hygiene (no secrets in code or logs) and the ~200-line file guideline live in `docs/guides/agent-best-practices.md`. Do not duplicate these in AGENTS.md or role agent files — link to the relevant rule IDs or guide sections instead.

## Review guidelines
- Block on failing CI/tests or missing test coverage for changed behavior.
- Require exact repro/verification commands for any functional change.
- Prefer minimal diffs; avoid drive-by refactors.
- No secrets/PII in logs.
- Call out risk areas: authz, data migrations, concurrency, perf regressions.
