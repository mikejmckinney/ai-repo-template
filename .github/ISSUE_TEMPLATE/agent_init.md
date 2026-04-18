---
name: Agent Initialization
about: Initialize a new repository from this template
title: '[INIT] Initialize repository from template'
labels: setup, agent-task
assignees: ''
---

## Repository Initialization Task

This repository was created from the `ai-repo-template`. Please initialize it for the actual project.

## Truth Hierarchy

Use this priority order when information conflicts:
1. `./.context/**` — canonical project direction and constraints
2. `./docs/**` — supporting detail and reference material
3. Codebase — current implementation reality

## Preflight Checks

- [ ] Verify `.context/00_INDEX.md` exists
- [ ] Verify `.github/prompts/repo-onboarding.md` exists
- [ ] Verify `.github/prompts/copilot-onboarding.md` exists
- [ ] Scan and list all files containing `TEMPLATE_PLACEHOLDER`
- [ ] Run `git remote -v` to detect repository owner/name

## Initialization Steps

### 1. Understand the Project

Determine the project purpose and current status from:
- `.context/**`
- `docs/**`
- Existing codebase (if any)

### 2. Run Onboarding Prompts

Execute in order:
1. `.github/prompts/repo-onboarding.md`
2. `.github/prompts/copilot-onboarding.md`

### 3. Update README.md

- If README.md contains `TEMPLATE_PLACEHOLDER`, replace it entirely with project-specific content
- Otherwise, revise without deleting real content

Include:
- Project name and description
- Setup instructions
- Usage examples
- Tech stack
- `## Limitations` — known constraints of the project
- `## Future Improvements` — forward-looking items not on the active roadmap
- `## FAQ` — short section or link to `docs/FAQ.md`

### 4. Customize docs/FAQ.md

- Remove template-specific entries (those prefixed with "Template:")
- Add project-specific questions surfaced during onboarding
- If the project will keep the FAQ in README instead, delete `docs/FAQ.md`

### 5. Regenerate AI_REPO_GUIDE.md

Create a new AI_REPO_GUIDE.md for THIS repo (not the template), including:
- Project summary
- Where canonical truth lives (`.context/00_INDEX.md`)
- How to use the context pack
- Repo conventions
- Build/test/lint commands
- Next steps

### 6. Update Issue Template Config

Update `.github/ISSUE_TEMPLATE/config.yml`:
- Replace `PLEASE_UPDATE_THIS/URL` with the actual `owner/repo` from `git remote -v`
- This enables the "Discussions" link on the New Issue page

### 7. Customize CI Pipeline

Update `.github/workflows/ci-tests.yml`:
- Add project-specific build commands
- Add test commands
- Add lint commands
- Remove placeholder comments

### 8. Fill in Context Pack

Update `.context/` files:
- `00_INDEX.md` — project summary and key decisions
- `roadmap.md` — define project phases
- `state/task_*.md` — current work (if any)

### 9. Configure Secrets (if needed)

Document any required repository secrets:
- `BACKEND_URL` for keep-warm workflow
- API keys, database URLs, etc.

## Important Notes

- Do NOT modify `.context/**` beyond filling in placeholders unless explicitly instructed
- Propose changes via comments if you see issues
- Run `./test.sh` to verify template integrity after changes

## Project Details

<!-- Fill in if known -->

**Project Name**: 
**Description**: 
**Tech Stack**: 
**Primary Language**: 
