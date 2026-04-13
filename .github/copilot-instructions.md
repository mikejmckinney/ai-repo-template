## Template detection
- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `ai-repo-template` (or `mikejmckinney/ai-repo-template`), or the
  legacy name `dotfiles` / `mikejmckinney/dotfiles` (still honored for one release):
  - Treat README.md and AI_REPO_GUIDE.md as the template's docs; do NOT regenerate/overwrite them.
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

## Onboarding / refresh instructions (only when needed)
- If this file (`.github/copilot-instructions.md`) is missing or clearly generic/stale: follow `.github/prompts/copilot-onboarding.md` to regenerate it *after* AI_REPO_GUIDE.md is accurate.

## Quality bar
- Don't guess APIs/behavior; cite repo files.
- Run verification commands (prefer those in AI_REPO_GUIDE.md).
- If your changes affect commands/layout/conventions/troubleshooting: update AI_REPO_GUIDE.md (or state "no changes required").
