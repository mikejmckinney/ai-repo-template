# Role selection and context pack usage

> Extracted from AGENTS.md §"Role selection (multi-agent workflow)", §"Context pack usage", and §"Onboarding procedure" in PR for #253 (ADR-021).
> Read before claiming a task or making your first edit in a new session.

## Default role: Parent Orchestrator (OP)

If the user has not explicitly assigned you to one of the canonical roles in
this session, you are the Parent Orchestrator (OP).

**OP is an orchestration mode, not a canonical implementer role.** It has no
owned paths in `agent_ownership.md`; ownership still flows through the ten
canonical roles. The OP's work is dispatch, planning, and assembly — not
implementation. Do not claim OP-ownership over a path or concern that an
implementer role owns.

The OP's primary job is to orchestrate work through the repo's role, ownership,
gate, and subagent process. User instructions are directives to the orchestrator,
not implementation prescriptions. "Fix this," "continue," "go ahead," and
"finish the PR" mean: ensure the requested outcome is completed through the
correct repo process.

### When the OP may implement directly

Direct implementation requires positive justification, not absence of red flags.
The OP must dispatch unless **all** of the following hold:

- ≤ ~20 LOC changed,
- single file,
- single canonical role's owned path, and
- none of: `scripts/*.sh`, `.github/workflows/*.yml`, `.agents/*.md`, platform
  overlays (`.github/agents/*.agent.md`, `.claude/agents/*.md`), per-concern
  process rules (`.context/rules/process_*.md`, `.context/rules/domain_*.md`,
  `.context/rules/repo_*.md`, `.context/rules/agent_ownership.md`), `AGENTS.md`,
  `CLAUDE.md`, or `.github/copilot-instructions.md`.

This is the same role-sensitive surface list [`process_work_style.md`](process_work_style.md)
uses for the pre-push-review trigger; reuse it intentionally so both rules stay
aligned. If you change one list, change the other in the same PR.

### Before non-trivial implementation, the OP must

1. Identify which canonical roles own the affected paths or concerns.
2. Consult `agent_ownership.md`.
3. Decide whether subagents are required (apply the direct-implementation test
   above).
4. Dispatch one subagent per role-owned area when work spans multiple roles and
   `runSubagent` is available.
5. Record dispatch decisions in `parent_compliance` using the schema fields
   defined in [`docs/compliance_schemas.md`](../../docs/compliance_schemas.md)
   § "`parent_compliance` v1":
   - `applicable_roles: [<roles whose ownership applied to the final diff>]`
   - `subagents_dispatched: [<parsed subagent_compliance objects — one per
     dispatched role, including its receipt>]`
   - `monolithic_justification: "<reason, if dispatched_roles are a strict
     subset of applicable_roles or no subagents ran>"`
6. If `runSubagent` is not available in the current environment, document the
   missing capability as the explicit special case and proceed monolithically.

Each dispatch must resolve a concrete unresolved role-owned question or produce
a role-owned artifact. Before calling `runSubagent`, the OP must be able to
name the decision the dispatch will change and the expected output surface. If
the next step is already straightforward parent execution, stop dispatching and
do the work. Do not use subagents as scratchpads, wording micro-checks,
confidence pings, or no-op placeholders.

Treat "do not use subagents," "keep this in the default agent," or equivalent
wording as the explicit special case requiring user instruction.

Minimal diff is about limiting the scope of change, not limiting delegation.
"Make the PR smaller by not delegating" is not a valid reason to skip dispatch.

For the end-to-end issue→merge walkthrough, follow [`.github/prompts/op-issue-workflow.md`](../../.github/prompts/op-issue-workflow.md).

## Role selection (multi-agent workflow)

This template supports parallel role-specialized agents. Before editing any file:

1. Identify your role (or ask the user which role to adopt). Canonical role definitions live in [`.agents/`](../../.agents/) (platform-agnostic, ADR-023) — Analyst, Architect, Judge, Critic, PM, Frontend, Backend, QA, DevOps, Docs. Each role has thin platform overlays in [`.github/agents/<role>.agent.md`](../../.github/agents/) (Copilot SDK) and [`.claude/agents/<role>.md`](../../.claude/agents/) (Claude Code) that point back to the canonical.
2. Read `.context/rules/agent_ownership.md` to confirm which paths your role owns.
3. Read the assigned GitHub issue, linked PR (if any), latest `agent-state:v1` comment, and labels to see active claims before editing. Do not recreate repo-local claim boards or treat local markdown as the live coordination source; ADR-025's GitHub-first surfaces are canonical.
4. Stay inside your owned paths. Any cross-role edit requires PM coordination. **Never guess ownership silently** — escalate to PM.
5. Full workflow (analysis → plan-gate → dispatch → parallel implementation → QA → diff-gate → merge) is documented in [docs/guides/multi-agent-coordination.md](../../docs/guides/multi-agent-coordination.md).

## Subagent dispatch compliance

When dispatching or receiving role-specialized subagent work, also follow
[`.context/rules/process_subagent_bootstrap.md`](process_subagent_bootstrap.md).

Parent/default agents must include a dispatch packet with role, goal, expected
output, issue/PR/plan/diff context, required process files, ownership
constraints, required gates, current `AGENTS_MD_VERSION`, and known deviations.
Dispatched roles must report `role_contract_version` from their canonical
`.agents/<role>.md` file in `subagent_compliance`.

Do not add `overlay_version`; platform overlays are registration shims and do
not own the role contract.

## Context pack usage

- Start with `.context/00_INDEX.md` for project overview
- Check the assigned GitHub issue, linked PR, latest `agent-state:v1` comment, and labels for current work in progress
- Reference `.context/rules/` for constraints that must not be violated
- Use `.context/roadmap.md` to understand project phases
- Reference `.context/vision/` for design mockups and architecture

## Onboarding procedure

1. Read [`AI_REPO_GUIDE.md`](../../AI_REPO_GUIDE.md).
2. Read `.context/00_INDEX.md` if it exists.
3. Check the assigned GitHub issue, linked PR, latest `agent-state:v1` comment, and labels for cognitive handoff from previous sessions.
4. If AI_REPO_GUIDE.md missing or stale: follow [`.github/prompts/repo-onboarding.md`](../../.github/prompts/repo-onboarding.md) to rebuild context.
