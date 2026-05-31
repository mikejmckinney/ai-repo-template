# Template detection

> Extracted from AGENTS.md §"Template detection" in PR for #253 (ADR-021).
> Distinguishes the template repo from downstream projects built from it.
> Read at first session in any new clone. Skip on subsequent sessions in
> the same clone unless the repo identity is in question.

- Determine the current repository name (e.g., via `git remote -v` or folder name).
- If the repo is named `ai-repo-template` (or `mikejmckinney/ai-repo-template`), or the
  legacy name `dotfiles` / `mikejmckinney/dotfiles` (still honored for one release):
  - Treat README.md, AI_REPO_GUIDE.md, and CLAUDE.md as the template's docs; do NOT regenerate/overwrite them.
  - Treat `.context/rules/agent_ownership.md` as the template's real ownership map - do NOT wholesale replace it; extend with project-specific source paths when deriving.
- Otherwise:
  - If README.md or AI_REPO_GUIDE.md contains `TEMPLATE_PLACEHOLDER`, treat them as stubs:
    replace README.md with project-specific README, and defer the final AI_REPO_GUIDE.md regeneration until after the Mode B context reset and repopulation steps complete.
  - If the resettable live context files still clearly describe the template repo itself (for example, `.context/00_INDEX.md` still names `ai-repo-template`, `.context/roadmap.md` still uses the template roadmap title, or the template-only architecture diagrams are still present), treat the repo as still in **Mode B** even if placeholder scans are otherwise clean.
  - During **Mode B** onboarding, also reset `.context/00_INDEX.md`, `.context/roadmap.md`, and `.context/vision/README.md` from the **canonical stub** blocks embedded in `.github/prompts/repo-onboarding.md`, even if the live template repo versions of those files no longer contain `TEMPLATE_PLACEHOLDER`.
  - After that reset, repopulate those three files with project-specific content before continuing past Phase 0 or regenerating AI_REPO_GUIDE.md.
  - As part of that same reset, delete `.context/vision/architecture/multi-agent-flow.md` and `.context/vision/architecture/state-surfaces.md`; they are template-only diagrams and should not survive into a derived repo's initial stub state.
  - Extend `.context/rules/agent_ownership.md` with rows for your project's real source paths (e.g. `src/frontend/**`, `src/backend/**`, `tests/**`). Do NOT delete the template-governance roles (Analyst / Architect / PM / QA / DevOps / Docs / Judge / Critic) - they are load-bearing.
  - If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`:
    replace it with the actual repository path (e.g., `owner/repo`) detected from `git remote -v`.
  - **Clear the template's retrospective example state (Mode B only).** `.context/sessions/*.md` may ship with ai-repo-template's own session history, while `.context/state/` ships reusable GitHub-first guidance artifacts. Downstream projects must reset the retrospective example during onboarding so stale template history is not mistaken for project reality. Specifically:
    - `.context/sessions/latest_summary.md` - replace body with a single "No sessions yet" line (keep the marker until first durable retrospective entry).
    - Keep `agent_state_comment_template.md` and `README.md` in `.context/state/`.
    - Keep `feedback_template.md` and `README.md` in `.context/sessions/`.
    - Do not add repo-local claim boards or checked-in task/handoff scaffolding during onboarding; ADR-025 uses GitHub issue/PR state for live coordination.
