## Template detection
- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `ai-repo-template` (or `mikejmckinney/ai-repo-template`), or the
  legacy name `dotfiles` / `mikejmckinney/dotfiles` (still honored for one release):
  - Treat README.md, AI_REPO_GUIDE.md, and CLAUDE.md as the template's docs; do NOT regenerate/overwrite them.
- Otherwise:
  - If README.md or AI_REPO_GUIDE.md contains `TEMPLATE_PLACEHOLDER`, treat them as stubs:
    replace README.md with project-specific README, and regenerate AI_REPO_GUIDE.md from the repo's real assets (./.context/**, ./docs/**, source).
  - If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`:
    replace it with the actual repository path (e.g., `owner/repo`) detected from `git remote -v`.

## Truth hierarchy
- When sources conflict, prioritize `.context/**` > `docs/**` > codebase.
  See `AGENTS.md` §"Truth hierarchy" for rationale and the full onboarding procedure.

## Required context
- Always read `/AI_REPO_GUIDE.md` first.
- If AI_REPO_GUIDE.md is missing/stale: follow `.github/prompts/repo-onboarding.md` and update AI_REPO_GUIDE.md in the same PR.

## Following referenced prompt files
When a user's comment or issue body contains the pattern `@copilot follow <path>`
(e.g. `@copilot follow .github/prompts/pr-resolve-all.md`):

1. Read the entire file at `<path>` before doing anything else.
2. Treat that file's contents as your primary task instructions for this run,
   overriding any shorter instruction in the mention.
3. Execute every phase/step in the referenced file in order. Do not skip phases.
4. If the file's "Rules" or "Verification" section conflicts with defaults
   elsewhere in this repo, the referenced file wins for this task.
5. If your cumulative response would exceed GitHub's per-comment size limit
   (~65 KB of rendered markdown), split it across multiple sequential PR
   comments labeled `Part 1/N`, `Part 2/N`, … rather than truncating. Post
   each part as soon as it's ready so the author can read along.
6. Only one `@copilot follow <path>` reference is expected per comment. If the
   path doesn't exist or isn't under `.github/prompts/`, post a single comment
   explaining that and stop.

This mirrors the `@claude follow <path>` convention wired through
`.github/workflows/claude.yml`, so either agent can be invoked with the same
one-liner.

## Onboarding / refresh instructions (only when needed)
- If this file (`.github/copilot-instructions.md`) is missing or clearly generic/stale: follow `.github/prompts/copilot-onboarding.md` to regenerate it *after* AI_REPO_GUIDE.md is accurate.

## Quality bar
- Don't guess APIs/behavior; cite repo files.
- Run verification commands (prefer those in AI_REPO_GUIDE.md).
- If your changes affect commands/layout/conventions/troubleshooting: update AI_REPO_GUIDE.md (or state "no changes required").
