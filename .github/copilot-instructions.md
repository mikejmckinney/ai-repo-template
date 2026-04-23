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

## Analyst pre-flight (before implementing from a prompt file)

If an assigned issue references `.github/prompts/NN-*.md` (where `NN` is a
two-digit number prefix — for example `01-init-project.md` or
`05-portfolio-demo-app.md`; a project implementation prompt — NOT a shared
procedure like `pr-resolve-all.md`, `repo-onboarding.md`,
`copilot-onboarding.md`, or `expand-backlog-entry.md`), run pre-flight before
writing any code. Skip for bug fixes, dep bumps, doc typos, and ad-hoc
issues without a prompt reference.

Procedure:

1. Check the issue for an existing `## 🔬 Analyst Pre-Flight Report` comment.
2. If it exists with verdict **PASS**, proceed to implementation.
3. If it exists with **FAIL** or **HOLD**, stop — wait for the author.
4. If none exists, act as Analyst: read `.github/agents/analyst.agent.md`
   ("Prompt Pre-Flight Validation" section) for the 15-minute test and the
   exact report template. Post the report as an issue comment. Then:
   - **PASS** → implement.
   - **FAIL** (scope mismatch) → post the mismatch, stop.
   - **HOLD** (ambiguities) → post a numbered list, stop.

If a prompt "looks clear enough" to skip pre-flight, run it anyway — that's
the signal, not the exemption.

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
