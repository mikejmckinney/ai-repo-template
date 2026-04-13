# AGENTS.md

## Template detection (important)
- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `dotfiles` (or `mikejmckinney/dotfiles`):
  - Treat README.md and AI_REPO_GUIDE.md as the template's docs; do NOT regenerate/overwrite them.
- Otherwise:
  - If README.md or AI_REPO_GUIDE.md contains `TEMPLATE_PLACEHOLDER`, treat them as stubs:
    replace README.md with project-specific README, and regenerate AI_REPO_GUIDE.md from the repo's real assets (./.context/**, ./docs/**, source).
  - If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`:
    replace it with the actual repository path (e.g., `owner/repo`) detected from `git remote -v`.

## Truth hierarchy
When information conflicts, use this priority order:
1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

## Role selection (multi-agent workflow)
This template supports parallel role-specialized agents. Before editing any file:
1. Identify your role (or ask the user which role to adopt). Role definitions live in `.github/agents/*.agent.md` — Architect, Judge, PM, Frontend, Backend, QA, DevOps, Docs.
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

## Review guidelines
- Block on failing CI/tests or missing test coverage for changed behavior.
- Require exact repro/verification commands for any functional change.
- Prefer minimal diffs; avoid drive-by refactors.
- No secrets/PII in logs.
- Call out risk areas: authz, data migrations, concurrency, perf regressions.
