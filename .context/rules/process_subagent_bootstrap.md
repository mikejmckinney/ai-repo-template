# Subagent bootstrap and compliance return

> ADR-026 rule for parent dispatch packets, dispatched subagent startup, and `subagent_compliance` evidence. Extended narrative: [`docs/guides/subagent-bootstrap-reference.md`](../../docs/guides/subagent-bootstrap-reference.md).

## Positional output contract

**Exact-output subagents emit required first line before any handshake content.**

- Judge: `DECISION:` is literal first character sequence.
- Critic: `CRITIC DECISION:` is literal first character sequence.

After role body, append in order:

1. `## Subagent session handshake` — 8-field table from `process_session_start.md`.
2. `## Subagent context receipt` — file table from `process_session_start.md`.
3. `subagent_compliance` YAML block.

Non-exact-output roles may begin with `Role receipt v<N> — <role>`; encouraged to append handshake + receipt + compliance at end.

## Parent dispatch packet

Before dispatch, parent must provide:

- role name, goal/scope, expected output surface
- relevant issue/PR/plan/diff link
- required process files, ownership constraints, required gates
- current `AGENTS_MD_VERSION`, known deviations/exemptions
- **Judge**: `mode: plan-gate` or `mode: diff-gate` (parent documentation; Judge falls back per `.agents/judge.md` § Mode Selection when absent)

State unknowns explicitly. Do not let subagent infer missing state.

## Subagent startup order

1. `AGENTS.md` and `AGENTS_MD_VERSION`.
2. Canonical `.agents/<role>.md` and `role_contract_version`.
3. `process_role_selection.md`, `agent_ownership.md`.
4. Every process rule named in dispatch packet.
5. Task context from parent.

`subagent_compliance.context_files_used` must name files that affected output.

## Missing context behavior

Do not guess. Non-exact-output roles may return `NEEDS_CONTEXT`. Exact-output roles preserve first-line contract; use `REQUEST_CHANGES` and name `NEEDS_CONTEXT` in body. Append `subagent_compliance` when role contract and scope are identifiable.

## Receipt evidence

Non-exact-output roles may begin with `Role receipt v<role_contract_version> — <role>`. Exact-output roles record receipt in `subagent_compliance.receipt` with `mode: trailing-block`.

## Required return block

Every dispatched subagent ends with `subagent_compliance` matching `docs/compliance_schemas.md`.

Required discipline:

- `role_contract_version`, not `overlay_version`.
- Loaded `AGENTS_MD_VERSION` for `agents_md_version`.
- `files_modified` lists only files actually modified (empty for review-only).
- `pointers_skipped` only when consciously skipped with reason.
- `opportunity_notes` (9-field shape per `process_opportunity_feedback.md`) when subagent produced/modified files; `[]` permitted; read-only MAY omit; ≤3 cap.
- Do not claim runtime proof.

Missing `subagent_compliance` → output unusable as gate evidence (not proof dispatch failed).

## Parent handling of subagent evidence

Copy parsed compliance into `parent_compliance.subagents_dispatched`. Do not cite omitted-compliance output as gate evidence.

## Edit verification and pass-back contract

Subagent intending to modify files must, before `run_status: SUCCESS`, re-read each `files_modified` entry and confirm post-edit anchors.

On verification failure or runtime error:

1. Set `run_status` to `BLOCKED_ON_RUNTIME` or `PARTIAL`.
2. Populate `apply_replays[]` with `{path, anchor, replacement}` (anchor unique in file).
3. Leave `files_modified` empty for files whose edits did not land.

Pass-back keeps OP as single applier; broader subagent permissions are not the remediation.

## Parent handling of pass-back evidence

When `run_status != SUCCESS` with `apply_replays[]`:

1. Parent applies patches, verifies bytes, records in `parent_compliance.deviations[]` (`id: subagent-runtime-failure-replayed`).
2. Record parent-applied paths in `monolithic_justification` naming pass-back explicitly.
3. If anchor missing/conflict → `NEEDS_CONTEXT` follow-up, not silent re-implementation.

`BLOCKED_ON_RUNTIME` with empty `apply_replays[]` and no artifact → document `id: subagent-runtime-failure-without-replay` in deviations.

## Dispatched-subagent ghost-success

Subagent terminal `git push` claims may not reflect remote state. **Required discipline:**

1. **Prefer pass-back** over subagent push.
2. If subagent pushes, include post-push `git log origin/<branch> -1 --oneline` in response (see reference guide for placement).
3. **Parent defense**: after claimed push, `git fetch origin && git log origin/<branch> -1` and compare SHA; mismatch → replay or re-dispatch.

Runtime limitation in dispatch host, not contract change. Detail: [`docs/guides/subagent-bootstrap-reference.md`](../../docs/guides/subagent-bootstrap-reference.md) and `process_model_tier.md`.

## Subagent compliance schema variance

Validator authority: `scripts/lib/compliance_schema.py` (`validate_subagent`); schema wins on disagreement.

1. **Nine required keys** must be present: `role`, `role_contract_version`, `agents_md_version`, `receipt`, `context_files_used`, `pointers_skipped`, `task_scope`, `files_modified`, `gates_invoked`. Optional v1.1: `run_status`, `apply_replays`.
2. **Unknown keys hard-fail** — put extras in adjacent prose, not inside the block.
3. **Missing required field** → parent re-dispatches with reminder; only if impossible, narrative + BLOCK.
4. **Repeated extra fields** across dispatches → file schema amendment issue.

Detail and sandbox dogfood context: [`docs/guides/subagent-bootstrap-reference.md`](../../docs/guides/subagent-bootstrap-reference.md).
