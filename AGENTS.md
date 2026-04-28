# AGENTS.md

<!-- AGENTS_MD_VERSION: 3 -->
<!-- Bump AGENTS_MD_VERSION whenever this file is materially edited so the
     handshake below proves agents loaded the *current* copy, not a stale one. -->

> **Pointer files**: [`CLAUDE.md`](CLAUDE.md) and
> [`.github/copilot-instructions.md`](.github/copilot-instructions.md) are
> thin pointers into this file. When you change a section heading here,
> verify their pointer tables still resolve — see
> `.context/rules/process_doc_maintenance.md`.

## Session handshake (read-receipt)
When you have read this file at the start of a session, open your first
substantive reply with the exact token `Session handshake v3` (matching
the `AGENTS_MD_VERSION` value above) on its own line before any other
content. Do not paraphrase, translate, or omit the token. The number is
the canary — if it doesn't match the version above, your AGENTS.md copy
is stale and you should re-read this file before proceeding.

This is a per-session signal, not a per-reply one. Emit it once at the
start of the session; suppress it on subsequent replies in the same
conversation. If a user explicitly says "skip the handshake," honor that
for the rest of the session.

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
- **Branch first, then commit per task boundary.** You MUST be on a non-default branch *before* making any non-trivial edit — branching is a precondition for the work, not a wrap-up step. You MUST also commit (and push, when a remote exists) at least once per task boundary, *not* only at the end of a multi-task session. Working directly on `main`/`master` is not acceptable, even for "I'll branch later" exploration. Branch naming: `feature/<role>-<task-id>` is defined in `docs/guides/multi-agent-coordination.md` §"Branch-Per-Role Model"; the `fix/<issue>-<slug>` form is shown by example in `.context/state/coordination.md` (no formal definition — follow the pattern). See ADR-012 for why this rule needs explicit statement.
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

The gate (ADR-005, broadened by ADR-014) fires on any issue proposing a
novel user-facing deliverable. Dispatch the Analyst role first and wait
for a passing Pre-Flight Report before writing any code.

**Trigger** (any one signal is sufficient):

1. Issue references `.github/prompts/NN-*.md` (two-digit project prompt
   like `01-init-project.md`, `05-portfolio-demo-app.md`) and the prompt
   describes a deliverable. (ADR-005.)
2. Issue uses `feature_request.md` template **and** carries the
   `enhancement` label. (ADR-014.)
3. Issue is an ADR proposing a new agent surface (role, webhook, external
   interface, automation mode). (ADR-014.)
4. Issue body contains action verbs (build, implement, ship, create) plus
   a user-facing noun (UI, dashboard, page, service, pipeline, dataset,
   demo, integration). (ADR-014.)

**Opt-out** (both required):

- Issue carries the `outcome-validated` label, **and**
- Issue body contains an inline outcome paragraph (one paragraph describing
  what a user will be able to *do* when shipped, not just what files will
  exist). The `feature_request.md` and `agent_init.md` templates include a
  "User outcome (15-minute test)" section for this. The label alone is
  not sufficient.

**Why this exists**: Issues that describe deliverables without specifying
user outcomes produce technically correct but scope-mismatched
implementations. Automated review catches code quality; it does not catch
"shipped the wrong artifact." The Analyst's Pre-Flight Report applies the
15-minute test before implementation begins, which is the only cheap point
to catch this failure mode.

**Procedure**:

1. Check the issue for an existing Pre-Flight Report comment matching the
   template in `.github/agents/analyst.agent.md` → "Pre-Flight Validation".
2. If one exists with verdict **PASS**, proceed to Architect handoff as normal.
3. If one exists with verdict **FAIL** or **HOLD**, stop. Do not implement.
   Address the mismatch or ambiguity first.
4. If no report exists, dispatch Analyst yourself (or, if you are running as
   Copilot's cloud agent, post a comment: "Dispatching Analyst for pre-flight
   validation before implementation" and proceed to run the analysis per
   the Analyst role file). Wait for the report. Then re-evaluate.

**Exemptions** (gate does NOT apply, no opt-out needed):

- `bug` label, `docs` label (no new behavior), `dependencies` label,
  reverts, `chore:*` labels, internal refactors with no user-facing change.
- Issues referencing only shared procedural prompts (`pr-resolve-all.md`,
  `repo-onboarding.md`, `expand-backlog-entry.md`)
  or prompt documentation (`README.md`) under `.github/prompts/` — those
  describe procedures, not deliverables.

Skipping this gate when it applies is a known failure mode. If you find
yourself reasoning "this issue looks clear enough, I'll skip pre-flight,"
that's the signal to run pre-flight anyway.

### Plan-as-comment requirement (REQUIRED before implementation)

Before writing implementation code for any non-exempt issue, post an
Implementation Plan as a comment on that issue using the template at
`.github/PLAN_TEMPLATE.md`. The plan captures the implementation lens
(approach, files, verification, risks) — complementary to the issue
template which captures the *what* and *why*. See ADR-011.

**Why this exists**: issue templates capture user-facing intent;
implementer-side decisions about approach, scope, and verification are
invisible until PR review. Posting the plan as an artifact catches three
recurring failure modes pre-implementation: wrong approach to the right
problem, hidden scope, and missing verification. v1 has no formal
approval gate (deferred to #155) — the plan is reviewed at PR time, but
the act of writing it forces the implementation thinking before code.

**Procedure**:

1. Pick up the issue. Read it end-to-end.
2. Post a comment using `.github/PLAN_TEMPLATE.md`. Sections that don't
   apply get `N/A — <one-phrase reason>`, never silent omission.
3. Implement. No waiting on approval in v1 — but if your actual diff
   diverges from the plan by more than ~30% in file count or scope,
   post a "Plan revision" comment on the same issue before pushing.
4. Open the PR. Body MUST link the issue or a parent PR (`Closes #NN`,
   `Refs #NN`, `Implements ADR-NNN`). Judge BLOCKs at diff-gate when
   no link is present and no exemption label applies. Populate the PR
   template's `## Plan` section with permalinks to the original plan
   and any revisions, plus a 1–2 sentence summary of the latest
   version. Judge advises (REQUEST_CHANGES) at diff-gate when this is
   missing or stale; it is not a v1 BLOCK.
5. If the plan is revised after the PR is open, edit the PR body's
   `## Plan` section in the same push as the divergent code, link the
   revision comment, and tick the matching box in `## Plan revision
   sync` so reviewers don't evaluate stale intent.

**Exemptions** (plan is NOT required):

- Issue is labeled `chore:no-plan` (the explicit opt-out).
- Author is Renovate, Dependabot, or another automation bot.
- Work is a `revert` of a prior PR (the prior PR's plan still applies).

The PR-must-link rule has the same exemptions plus PRs labeled
`smoke-test` (existing convention; smoke tests intentionally don't link
issues).

**Single template, no tiering**: there is no "minimal" vs "full" plan
mode. The template scales with the work — five lines for trivial fixes,
25–40 lines for typical work. Tiered modes invite agents to default to
the lower-effort option, which defeats the gate. When a section
genuinely doesn't apply, write `N/A — <reason>`. Explicit
acknowledgment beats silent omission.

**Relationship to the Analyst pre-flight gate**: ADR-005's Pre-Flight
Report (broadened by ADR-014 to ad-hoc deliverable issues) is a stricter
gate that runs *in addition to* the plan requirement on any issue meeting
the pre-flight trigger. It is not replaced or weakened by this requirement.
The two gates have different trigger conditions and will be unified in #155.

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
Keep agent working memory current so the next session (or next role) can resume cleanly. **Working state must live in `.context/state/`** — the LLM tool's in-conversation todo list and `/memories/session/` are agent-private scratch surfaces invisible to any other session, and are never substitutes for the checked-in files below. If your only record of in-progress work is in scratch surfaces, that work is lost the moment the session ends.

- **`.context/state/_active.md`** — rewrite (don't append) at every task boundary. Max ~20 lines. Schema: Active Task, File, Role, Blockers, Next 1–3 actions. Schema and examples in `.context/state/README.md`.
  - **What counts as a "task boundary"** for prompt-driven work: each `.github/prompts/NN-*.md` file is its own boundary. If you process prompts 02 → 03 → 04 in one session, that is *three* boundaries — rewrite `_active.md` between each, even if the same agent continues. Treating multiple prompts as one continuous task is a known failure mode (see ADR-012 + `docs/postmortems/postmortem-001-workflow-bypass.md`).
- **`.context/state/task_<slug>.md`** — create from `.context/state/task_template.md` at task start. Delete (or move to `.context/sessions/`) at task end.
- **Handoff trigger** — write a structured handoff to `.context/state/handoff_<slug>.md` (template: `.context/state/handoff_template.md`) and start a fresh session whenever ANY of the following fires:
  - A single agent conversation exceeds ~30 turns.
  - You're about to hand off to a different role/agent.
  - **The LLM runtime auto-summarizes your conversation mid-flight.** This is the loudest possible signal that you've blown past the ~30-turn threshold; treat it as an explicit trigger and write the handoff *before* responding to the next user message, not after.

  The handoff is the baton; the next session reads it instead of replaying the full chat.
- **Close-out (at session end OR task close-out, whichever comes first)** — the role that led the work updates `.context/sessions/latest_summary.md` with a 3–5 line entry: what shipped, what was harder than expected, what generalizes (→ open a follow-up to update rules/ADRs/guides if applicable). Do NOT defer this until merge — write it now even if the PR isn't merged yet, and amend later if the merge changes the outcome. The spirit of the rule is "leave the next session a baton," which applies at session-end regardless of merge status. PM verifies this entry exists before marking the task done in `coordination.md`.

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
