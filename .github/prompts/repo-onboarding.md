---
agent: agent
---

# Repo Onboarding Prompt (New + Existing Repos)

## Purpose
Onboard an agent to this repository with deterministic, non-destructive steps.
This prompt supports:
1. Template-derived repositories that still contain placeholders.
2. Existing repositories with established docs and source.

## Inputs
- Repository working tree
- `AGENTS.md`
- `AI_REPO_GUIDE.md` (if present)
- `./.context/**`
- `./docs/**`
- Source code files
- Optional session state files in `./.context/state/**`

## Hard Rules
1. Follow `AGENTS.md` first.
2. Use the truth hierarchy when inferring intent:
   1. `./.context/**`
   2. `./docs/**`
   3. source code
3. Do not treat placeholder docs as project truth.
4. Do not overwrite docs unless conditions below explicitly require it.
5. If a referenced command or script is missing, report that and continue.

---

## Step 0 — Detect Repository Identity and Onboarding Mode

Determine:
- repository name (from folder name and/or `git remote -v`)
- whether this repository identity is a template identity:
  - `ai-repo-template` or `mikejmckinney/ai-repo-template`
  - legacy `dotfiles` or `mikejmckinney/dotfiles`
- whether `README.md` or `AI_REPO_GUIDE.md` contains `TEMPLATE_PLACEHOLDER`

Set one mode:

### Mode A — Template Identity Repository
- Treat `README.md`, `AI_REPO_GUIDE.md`, and `CLAUDE.md` as template docs.
- Do **not** regenerate or overwrite those template docs.
- Continue with operational onboarding only.

### Mode B — Non-template Repository with Placeholders
- Treat placeholder docs as stubs.
- Replace `README.md` with repository-specific content.
- Regenerate `AI_REPO_GUIDE.md` from real project assets (`./.context/**`, `./docs/**`, code).
- If `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`, replace with the real `owner/repo`.

### Mode C — Existing Non-template Repository (No Placeholders)
- Keep current docs unchanged.
- Continue with operational onboarding only.

---

## Step 1 — Read Immediate Working Context
1. Read `.context/state/_active.md` if present.
2. Read relevant `task_*.md` files in `.context/state/` if present.
3. Extract:
   - active task
   - role
   - blockers
   - next actions

If missing, report: `No active task state file found.`

## Step 2 — Read Project Index and Constraints
1. Read `.context/00_INDEX.md` if present.
2. Read constraints from `.context/rules/**` relevant to the active task.
3. Identify process gates to honor (ownership, coordination, QA, doc sync, etc.).

## Step 3 — Read Recent Session Baton
1. Read `.context/sessions/latest_summary.md` if present.
2. Summarize recent decisions and carry-forward risks in up to 5 bullets.

## Step 4 — Environment Stability Check (Best-effort)
1. Run `git status --short` to detect unexpected working tree changes.
2. If `./scripts/verify-env.sh` exists and is executable, run it.
3. If missing/non-executable, report: `verify-env skipped (missing or non-executable).`

Classify environment:
- **Stable**: expected working tree + no environment check failures.
- **Unstable**: unexpected changes and/or environment check failure.

## Step 5 — Optional Secondary Onboarding Prompt
If `.github/prompts/copilot-onboarding.md` exists, run it after this prompt and merge findings.
If not present, continue.

---

## Required Output Format (Must Follow)

### Onboarding Report
- **Repository Type:** `[Template identity | Non-template]`
- **Onboarding Mode:** `[A | B | C]`
- **Truth Sources Used:** `[key .context/.docs/code paths]`
- **Active Task:** `[task name or "none found"]`
- **Role / Ownership Context:** `[role + owned paths or "not yet assigned"]`
- **Blockers:** `[list or "none"]`
- **Environment:** `[Stable | Unstable]` with one-line reason
- **Doc Actions Taken:** `[none | README replaced | AI_REPO_GUIDE regenerated | issue-template config updated]`
- **Next 1–3 Actions:** `[actionable bullets]`
- **Ready Statement:** `I have reviewed the context. Current task is [Task Name]. Environment is [Stable/Unstable]. Ready for instructions.`

## Safety Checks
- If sources conflict, call out the conflict and follow truth hierarchy.
- If required files are missing, continue best-effort and list missing files.
- Do not invent APIs, paths, or ownership mappings; mark unknowns explicitly.
