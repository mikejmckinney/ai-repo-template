## Template detection
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

## Truth hierarchy
When sources conflict, prioritize `.context/**` > `docs/**` > codebase.
See `AGENTS.md` §"Truth hierarchy" for rationale and the full onboarding procedure.

## Required context
- Always read `/AI_REPO_GUIDE.md` first.
- If AI_REPO_GUIDE.md is missing/stale: follow `.github/prompts/repo-onboarding.md` and update AI_REPO_GUIDE.md in the same PR.

## Analyst pre-flight (before implementing a novel user-facing deliverable)

The gate (ADR-005, broadened by ADR-014) fires when **any one** of these
is true:

- Issue references `.github/prompts/NN-*.md` (a numbered project prompt
  like `01-init-project.md`) and the prompt describes a deliverable.
- Issue uses `feature_request.md` template and carries `enhancement` label.
- Issue is an ADR proposing a new agent surface (role, webhook, external
  interface, automation mode).
- Issue body uses action verbs (build, implement, ship, create) + a
  user-facing noun (UI, dashboard, page, service, pipeline, dataset, demo,
  integration).

Opt out by adding the `outcome-validated` label **and** an inline outcome
paragraph in the issue body (one paragraph describing what a user can
*do* when shipped). Label alone is not sufficient.

Skip entirely for: `bug`, `docs` (no new behavior), `dependencies`,
`chore:*`, reverts, internal refactors, and issues referencing only
shared procedural prompts (`pr-resolve-all.md`, `repo-onboarding.md`,
`copilot-onboarding.md`, `expand-backlog-entry.md`).

Procedure:

1. Check the issue for an existing `## 🔬 Analyst Pre-Flight Report` comment.
2. If it exists with verdict **PASS**, proceed to implementation.
3. If it exists with **FAIL** or **HOLD**, stop — wait for the author.
4. If none exists, act as Analyst: read `.github/agents/analyst.agent.md`
   ("Pre-Flight Validation" section) for the 15-minute test and the
   exact report template. Post the report as an issue comment. Then:
   - **PASS** → implement.
   - **FAIL** (scope mismatch) → post the mismatch, stop.
   - **HOLD** (ambiguities) → post a numbered list, stop.

If an issue "looks clear enough" to skip pre-flight, run it anyway — that's
the signal, not the exemption.

## Plan-as-comment requirement (before implementing any non-exempt issue)

Before writing code for any issue, post an Implementation Plan as a
comment on that issue using `.github/PLAN_TEMPLATE.md`. See ADR-011 and
AGENTS.md → "Plan-as-comment requirement" for the full rules.

Quick rules:

1. Default: plan required.
2. Skip when: issue is labeled `chore:no-plan`, author is
   Renovate/Dependabot, or the work is a revert of a prior PR.
3. Single template, no tiering. Sections that don't apply get
   `N/A — <reason>`, not silent omission.
4. Implement after posting (no formal approval gate in v1; reviewed at
   PR time). If your diff diverges from the plan by ~30%+ in file count
   or scope, post a "Plan revision" comment before pushing.
5. PR body MUST link the issue or a parent PR (`Closes #NN`, `Refs #NN`).
   Judge BLOCKs at diff-gate when missing and no exemption applies.
6. PR body's `## Plan` section should link the plan comment (and any
   revisions) and summarize the latest version in 1–2 sentences. Populate
   it when you open the PR; if a "Plan revision" comment is posted after
   the PR is already open, refresh that section and tick the matching
   box in `## Plan revision sync` in the same push as the divergent code.
   Judge advises (REQUEST_CHANGES, not BLOCK) at diff-gate when missing
   or stale.

The Analyst pre-flight gate above runs *in addition to* this plan
requirement on any issue meeting its broader trigger — prompt-referenced
project issues, ad-hoc deliverable issues, and ADRs proposing new agent
surfaces (per ADR-014). It is not replaced by the plan requirement.

## Following referenced prompt files
When a comment or issue body contains `@copilot follow <path>` (e.g.
`@copilot follow .github/prompts/pr-resolve-all.md`):

1. Only the first `@copilot follow <path>` per comment is processed. If the
   path doesn't exist or isn't under `.github/prompts/`, post a single
   comment explaining and stop.
2. Read the entire file at `<path>` before anything else.
3. Treat its contents as primary task instructions, overriding shorter
   instructions in the mention.
4. Execute every phase/step in order. Do not skip phases.
5. If the file's "Rules" or "Verification" section conflicts with defaults
   elsewhere in this repo, the referenced file wins for this task.
6. If your cumulative response would exceed GitHub's per-comment limit
   (~65 KB), split across sequential comments labeled `Part 1/N`,
   `Part 2/N`, ... rather than truncating. Post each part as soon as ready.

Mirrors the `@claude follow <path>` convention in `.github/workflows/claude.yml`.

## Onboarding / refresh (only when needed)
If this file is missing or clearly generic/stale: follow
`.github/prompts/copilot-onboarding.md` *after* AI_REPO_GUIDE.md is accurate.

## Quality bar
- Don't guess APIs/behavior; cite repo files.
- Run verification commands (prefer those in AI_REPO_GUIDE.md).
- If changes affect commands/layout/conventions/troubleshooting, update
  AI_REPO_GUIDE.md (or state "no changes required").

## Templates and conventions
GitHub auto-populates issue and PR templates only in the browser flow, not
when an agent uses `gh` / MCP / API. Apply them explicitly. The issue
templates start with a YAML front-matter block delimited by `---`; that
block is metadata for GitHub's template chooser, not body text. Strip the
front-matter and pass only the Markdown content after the closing `---`
to `gh` / MCP / API.

- When creating issues programmatically, use the body skeleton from
  `.github/ISSUE_TEMPLATE/{feature_request,bug_report,agent_init}.md`
  (Markdown body only; strip the leading YAML front-matter).
- When creating PRs programmatically, use the body skeleton from
  `.github/pull_request_template.md` (no front-matter to strip in this
  file). The **Doc sync** checklist is REQUIRED — Judge enforces it at
  diff-gate.
- When addressing review feedback on a PR you authored, follow
  `.github/prompts/pr-resolve-all.md` (Phases 1–4) so the Resolution
  Report and Phase 4 thread-resolution land consistently — even when no
  `@copilot follow` mention has been posted.
- For bundling small follow-ups vs. splitting them, see
  `docs/guides/agent-best-practices.md` → "Issue and PR Granularity."
- If a section the work needs is missing from a template, **update the
  template in the same PR** rather than skipping the section.
