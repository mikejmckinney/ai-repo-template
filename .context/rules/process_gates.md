# Pre-implementation gates

> Extracted from AGENTS.md §"Analyst pre-flight gate" and §"Plan-as-comment requirement" in PR for #253 (ADR-021).
> Both gates apply *before* you write any implementation code on a non-exempt issue.

## Analyst pre-flight gate (REQUIRED before implementation)

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
   template in [`.agents/analyst.md`](../../.agents/analyst.md) → "Pre-Flight Validation".
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
  `repo-onboarding.md`, `expand-backlog-entry.md`, `capture-postmortem.md`,
  `mirror-postmortem.md`) or prompt documentation (`README.md`) under
  `.github/prompts/` — those describe procedures, not deliverables.

Skipping this gate when it applies is a known failure mode. If you find
yourself reasoning "this issue looks clear enough, I'll skip pre-flight,"
that's the signal to run pre-flight anyway.

## Plan-as-comment requirement (REQUIRED before implementation)

Before writing implementation code for any non-exempt issue, post an
Implementation Plan as a comment on that issue using the template at
[`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md). The plan captures the implementation lens
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
2. Post a comment using [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md). Sections that don't
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
6. **Before requesting review**, populate the PR template's
   `## Supporting verification results` section with a result entry
   (`✅ pass`, `❌ fail`, `⏭️ sandbox-deferred — see Phase 2`, or
   `⏭️ N/A — <reason>`) for every command listed in the plan's
   `### Supporting verification`. CI is a backstop, not a substitute
   for local verification — Judge BLOCKs at diff-gate when this
   section is missing or claims pass for a command that demonstrably
   never ran (`.agents/judge.md` item 16).

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

**Relationship to the [Analyst pre-flight gate](#analyst-pre-flight-gate-required-before-implementation)**: ADR-005's Pre-Flight
Report (broadened by ADR-014 to ad-hoc deliverable issues) is a stricter
gate that runs *in addition to* the plan requirement on any issue meeting
the pre-flight trigger. It is not replaced or weakened by this requirement.
The two gates have different trigger conditions and will be unified in #155.
