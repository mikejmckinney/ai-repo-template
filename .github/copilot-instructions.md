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

## Analyst pre-flight (before implementing work from a prompt file)

When an issue assigned to you references a project implementation prompt
(any file matching `.github/prompts/NN-*.md`, e.g. `02-infrastructure-terraform.md`,
`05-portfolio-demo-app.md`), run Analyst pre-flight validation **before**
writing any code.

This does NOT apply when:
- The issue body is ad-hoc instructions with no prompt file reference.
- The prompt file is a shared procedure (`pr-resolve-all.md`,
  `repo-onboarding.md`, `copilot-onboarding.md`).
- The task is a simple bug fix, dependency bump, or doc typo.

### Procedure

1. Read `.github/agents/analyst.agent.md` — specifically the "Prompt Pre-Flight
   Validation" section. This defines the 15-minute test and the Pre-Flight
   Report template.
2. Check the issue for an existing Pre-Flight Report comment with verdict PASS.
3. If none exists, you act as the Analyst role for this step: read the
   referenced prompt file, apply the 15-minute test, and post a Pre-Flight
   Report as a comment on the issue using the exact template in the Analyst
   role file.
4. If your report's verdict is PASS, proceed with implementation.
5. If FAIL (scope mismatch), stop. Post the mismatch explanation and wait
   for the issue author to rewrite the prompt.
6. If HOLD (ambiguities), stop. Post the ambiguities as a numbered list and
   wait for answers.

### Why this matters

Prompts that describe deliverables without specifying user outcomes produce
technically correct implementations that deliver the wrong artifact. A prompt
that says "build 6 React pages about the architecture" is a deliverable
description; "build a demo a client can interact with that proves the
solution works" is an outcome. The first ships a presentation; the second
ships a working demo. Automated review catches code quality but not this
distinction.

The 15-minute test is: "If a user spent 15 minutes with the final
deliverable, would they *experience* the outcome, or would they *read about*
it?" Answer must match the request's intent. If a portfolio demo fails the
"experience" bar, the prompt is wrong, not the implementation.

If you are tempted to skip pre-flight because the prompt "looks clear
enough," that is the signal to run it anyway.

## Following referenced prompt files
When a user's comment or issue body contains the pattern `@copilot follow <path>`
(e.g. `@copilot follow .github/prompts/pr-resolve-all.md`):

1. Only one `@copilot follow <path>` reference is supported per comment (only
   the first one will be processed). If the path doesn't exist or isn't under
   `.github/prompts/`, post a single comment explaining that and stop.
2. Read the entire file at `<path>` before doing anything else after that validation.
3. Treat that file's contents as your primary task instructions for this run,
   overriding any shorter instruction in the mention.
4. Execute every phase/step in the referenced file in order. Do not skip phases.
5. If the file's "Rules" or "Verification" section conflicts with defaults
   elsewhere in this repo, the referenced file wins for this task.
6. If your cumulative response would exceed GitHub's per-comment size limit
   (approximately 65 KB of raw comment body text), split it across multiple
   sequential PR comments labeled `Part 1/N`, `Part 2/N`, ... rather than
   truncating. Post each part as soon as it's ready so the author can read along.

This mirrors the `@claude follow <path>` convention wired through
`.github/workflows/claude.yml`, so either agent can be invoked with the same
one-liner.

## Onboarding / refresh instructions (only when needed)
- If this file (`.github/copilot-instructions.md`) is missing or clearly generic/stale: follow `.github/prompts/copilot-onboarding.md` to regenerate it *after* AI_REPO_GUIDE.md is accurate.

## Quality bar
- Don't guess APIs/behavior; cite repo files.
- Run verification commands (prefer those in AI_REPO_GUIDE.md).
- If your changes affect commands/layout/conventions/troubleshooting: update AI_REPO_GUIDE.md (or state "no changes required").
