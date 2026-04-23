# AGENTS.md

## Template detection (important)
- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `ai-repo-template` (or `mikejmckinney/ai-repo-template`), or the
  legacy name `dotfiles` / `mikejmckinney/dotfiles` (still honored for one release):
  - Treat README.md, AI_REPO_GUIDE.md, and CLAUDE.md as the template's docs; do NOT regenerate/overwrite them.
  - Treat `.context/rules/agent_ownership.md` as the template's real ownership map — do NOT wholesale replace it; extend with project-specific source paths when deriving.
- Otherwise:
  - If README.md or AI_REPO_GUIDE.md contains `TEMPLATE_PLACEHOLDER`, treat them as stubs:
    replace README.md with project-specific README, and regenerate AI_REPO_GUIDE.md from the repo's real assets (./.context/**, ./docs/**, source).
  - Extend `.context/rules/agent_ownership.md` with rows for your project's real source paths (e.g. `src/frontend/**`, `src/backend/**`, `tests/**`). Do NOT delete the template-governance roles (Analyst / Architect / PM / QA / DevOps / Docs / Judge / Critic) — they are load-bearing.
  - If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`:
    replace it with the actual repository path (e.g., `owner/repo`) detected from `git remote -v`.

## Critical thinking and communication
Agents must reason critically rather than agree by default. The bar is "objective and evidence-based," not "agreeable."

- **Push back when warranted.** If the user's plan, premise, or proposed code has a flaw, say so directly and explain why. Don't hedge to be polite. If a better approach exists, recommend it and justify the tradeoff.
- **Calibrate confidence.** State what you verified vs. what you assumed. When something is uncertain, say "uncertain" — don't pad with false confidence and don't hide behind vague qualifiers.
- **Don't guess APIs, file contents, or runtime behavior.** Verify by reading the file or searching the codebase. If you can't verify, say so explicitly rather than asserting.
- **Compare approaches honestly.** When multiple options are viable, name the tradeoffs (cost, risk, reversibility, blast radius) before recommending one.
- **Cite your sources.** When stating a fact about the codebase or docs, include a relative path (and a line number when precision matters: `path/to/file.md:42`). Statements without a citation are treated as assumptions and must be marked `uncertain`. Judge and Critic reject uncited claims of fact.
- **Default to concise.** Add structure only when it earns its keep; don't pad length or drop detail the answer needs. If a complete answer genuinely requires length, use multiple parts or multiple responses rather than cutting corners.

## Work style
- **Small, reversible changes** beat rewrites. Prefer the minimal diff that fully solves the task.
- **No drive-by refactors.** If you spot something unrelated worth fixing, file a follow-up task instead of bundling it in.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.

## Clarification and ambiguity
When a request is genuinely ambiguous — where different reasonable interpretations lead to meaningfully different work — stop and ask before proceeding (unless it qualifies as a low-stakes decision — see the escape hatch below). Don't guess and build, and don't ask and build in parallel; ask, then wait.

- **Resolve from the repo first.** Before asking, check the **Truth hierarchy** sources (see §Truth hierarchy below) for an existing answer. If you can resolve the ambiguity by reading, do that instead of asking.
- **Budget your questions.** Limit yourself to at most three targeted questions per turn, and only ask questions that are genuinely blocking — not nice-to-haves you could resolve yourself or defer. If you only have one blocking question, ask one.
- **Low-stakes escape hatch.** For low-stakes decisions where stopping would cost more than it saves, state the assumption you're making inline and proceed. Example: "Assuming you want this as a new function rather than modifying the existing one — say so if not." This is only appropriate when the work is easy to revert if the assumption was wrong.
- **When to trigger a clarifying question.** Ask specifically when: (1) the request could reasonably mean two or more different things, (2) a decision requires information only the user has (business context, preferences, external constraints), (3) the request conflicts with something in the repo's rules or prior decisions (follow the **Push back** rule in §Critical thinking and communication rather than just asking), or (4) proceeding would require inventing facts (API shapes, data structures, domain terms) that can't be verified.
- **Don't ask** about style preferences, formatting, or conventions the repo's linter or rules files already answer.

## Truth hierarchy
When information conflicts, use this priority order:
1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

### Conflict-resolution procedure
When you detect a conflict between two sources at adjacent priorities, do **not** silently pick one. Instead:

1. **Note the conflict** in your output (a one-line callout naming both sources).
2. **Follow the higher-priority source** for the current task.
3. **File a follow-up** issue or open a PR updating the lower-priority source so it matches.
4. **Never edit the higher-priority source to match the lower one** without an ADR. If the lower source is what's actually correct, that's an architectural change that needs `docs/decisions/`.

## Role selection (multi-agent workflow)
This template supports parallel role-specialized agents. Before editing any file:
1. Identify your role (or ask the user which role to adopt). Role definitions live in `.github/agents/*.agent.md` — Analyst, Architect, Judge, Critic, PM, Frontend, Backend, QA, DevOps, Docs.
2. Read `.context/rules/agent_ownership.md` to confirm which paths your role owns.
3. Read `.context/state/coordination.md` to see active locks and claim your task before editing.
4. Stay inside your owned paths. Any cross-role edit requires a PM claim. **Never guess ownership silently** — escalate to PM.
5. Full workflow (analysis → plan-gate → dispatch → parallel implementation → QA → diff-gate → merge) is documented in `docs/guides/multi-agent-coordination.md`.

### Analyst pre-flight gate (REQUIRED before implementation)

If the issue assigned to you references a prompt file in `.github/prompts/NN-*.md`
(where `NN` is a two-digit number prefix — for example `01-init-project.md` or
`05-portfolio-demo-app.md`; this is a project implementation prompt — not a shared
procedural prompt like `pr-resolve-all.md`, `repo-onboarding.md`,
`copilot-onboarding.md`, or `expand-backlog-entry.md`),
you must dispatch the Analyst role first and wait for a passing Pre-Flight
Report before writing any code.

**Why this exists**: Prompt files that describe deliverables without
specifying user outcomes produce technically correct but scope-mismatched
implementations. Automated review catches code quality; it does not catch
"shipped the wrong artifact." The Analyst's Pre-Flight Report applies the
15-minute test before implementation begins, which is the only cheap point
to catch this failure mode.

**Procedure**:

1. Check the issue for an existing Pre-Flight Report comment matching the
   template in `.github/agents/analyst.agent.md` → "Prompt Pre-Flight Validation".
2. If one exists with verdict **PASS**, proceed to Architect handoff as normal.
3. If one exists with verdict **FAIL** or **HOLD**, stop. Do not implement.
   Address the mismatch or ambiguity first.
4. If no report exists, dispatch Analyst yourself (or, if you are running as
   Copilot's cloud agent, post a comment: "Dispatching Analyst for pre-flight
   validation before implementation" and proceed to run the analysis per
   the Analyst role file). Wait for the report. Then re-evaluate.

**When this gate does NOT apply**:

- Ad-hoc issues that don't reference a `.github/prompts/NN-*.md` file.
- Simple bug fixes, dependency bumps, typo corrections, doc edits.
- Issues that reference shared procedural prompts (`pr-resolve-all.md`, etc.) —
  those have their own verification and don't produce novel deliverables.

Skipping this gate on a prompt-referenced issue is a known failure mode.
If you find yourself reasoning "this prompt looks clear enough, I'll skip
pre-flight," that's the signal to run pre-flight anyway.

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
Doc-sync triggers (which files must update together) live in a single source of truth: **`.context/rules/process_doc_maintenance.md`**. Read it before opening a PR; Judge enforces it at diff-gate.

### Session-state cadence
Keep agent working memory current so the next session (or next role) can resume cleanly:

- **`.context/state/_active.md`** — rewrite (don't append) at every task boundary. Max ~20 lines. Schema: Active Task, File, Role, Blockers, Next 1–3 actions. Schema and examples in `.context/state/README.md`.
- **`.context/state/task_<slug>.md`** — create from `.context/state/task_template.md` at task start. Delete (or move to `.context/sessions/`) at task end.
- **Handoff trigger** — when a single agent conversation exceeds ~30 turns OR before any handoff to a different role/agent, write a structured handoff to `.context/state/handoff_<slug>.md` (template: `.context/state/handoff_template.md`) and start a fresh session. The handoff is the baton; the next session reads it instead of replaying the full chat.
- **Close-out (post-merge)** — the role that led the work updates `.context/sessions/latest_summary.md` with a 3–5 line entry: what shipped, what was harder than expected, what generalizes (→ open a follow-up to update rules/ADRs/guides if applicable). PM verifies this exists before marking the task done in `coordination.md`.

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

## Templates and conventions
GitHub auto-populates issue and PR templates only in the browser flow, not when an agent uses `gh` / MCP / API. Agents must apply them explicitly. The issue templates start with a YAML front-matter block delimited by `---`; that block is metadata for GitHub's template chooser, not body text. Strip the front-matter and copy only the Markdown content after the closing `---` into the issue/PR body.

- **Creating issues programmatically** — use the body skeleton from the matching `.github/ISSUE_TEMPLATE/{feature_request,bug_report,agent_init}.md` file (Markdown body only; strip the leading YAML front-matter).
- **Creating PRs programmatically** — use the body skeleton from `.github/pull_request_template.md` (no front-matter to strip in this file). The **Doc sync** checklist is REQUIRED; Judge enforces it at diff-gate.
- **Addressing review feedback on a PR you authored** — follow `.github/prompts/pr-resolve-all.md` (Phases 1–4) so the Resolution Report and Phase 4 thread-resolution land consistently. This applies even when no `@<agent> follow` mention has been posted; ad-hoc fixes skip the audit trail.
- **Bundling small follow-ups vs. splitting** — see `docs/guides/agent-best-practices.md` → "Issue and PR Granularity."
- If a section the work needs is missing from a template, **update the template in the same PR** rather than skipping the section.

## Code quality
Universal SOLID / TDD / clean-code rules are defined as Hard rules H1–H8 and Soft rules S1–S6 in `.context/rules/domain_code_quality.md`. Secrets hygiene (no secrets in code or logs) and the ~200-line file guideline live in `docs/guides/agent-best-practices.md`. Do not duplicate these in AGENTS.md or role agent files — link to the relevant rule IDs or guide sections instead.

## Review guidelines
- Block on failing CI/tests or missing test coverage for changed behavior.
- Require exact repro/verification commands for any functional change.
- Prefer minimal diffs; avoid drive-by refactors.
- No secrets/PII in logs.
- Call out risk areas: authz, data migrations, concurrency, perf regressions.
