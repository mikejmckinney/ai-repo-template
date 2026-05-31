# Template detection

> Extracted from AGENTS.md §"Template detection" in PR for #253 (ADR-021).
> Distinguishes the template repo from downstream projects built from it.
> Read at first session in any new clone. Skip on subsequent sessions in
> the same clone unless the repo identity is in question.

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
  - **Clear the template's retrospective example state (Mode B only).** `.context/sessions/*.md` may ship with ai-repo-template's own session history, while `.context/state/` ships reusable GitHub-first guidance artifacts. Downstream projects must reset the retrospective example during onboarding so stale template history is not mistaken for project reality. Specifically:
    - `.context/sessions/latest_summary.md` — replace body with a single "No sessions yet" line (keep the marker until first durable retrospective entry).
    - Keep `agent_state_comment_template.md` and `README.md` in `.context/state/`.
    - Keep `feedback_template.md` and `README.md` in `.context/sessions/`.
    - Do not add repo-local claim boards or checked-in task/handoff scaffolding during onboarding; ADR-025 uses GitHub issue/PR state for live coordination.
