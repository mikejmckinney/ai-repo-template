# Subagent Bootstrap — Reference Guide

> **Purpose**: Extended narrative, runtime observations, and schema-variance handling for ADR-026 subagent dispatch when role dispatch is used. Normative startup and compliance surfaces: [`AGENTS.md`](../../AGENTS.md), [`.context/rules/process_session_start.md`](../../.context/rules/process_session_start.md), and [`docs/compliance_schemas.md`](../compliance_schemas.md). Monolithic default: [ADR-031](../decisions/adr-031-agent-model-roi-benchmark-policy.md).

## Pass-back gold standard (PR #312)

PR #312's Architect dispatch returned byte-anchored patches in the failure response — the gold standard. The Docs dispatch returned nothing — the failure mode the pass-back contract prevents.

Granting subagents broader write/exec permissions is **not** the right remediation for runtime failures: that splits write authority across N runtimes, defeats OP's diff-gate role, and increases blast radius. Pass-back keeps OP as the single applier.

## Ghost-success empirical observation

A subagent that performs file edits and then claims `git commit` + `git push` from inside its own terminal can return a plausible success response when no commit landed on the remote. Parent OP detects this only by independently running `git fetch && git log origin/<branch> -1` after each dispatch.


**Verification snippet placement**: v1 schema has no `verification` field; record `git log origin/<branch> -1 --oneline` output inline in narrative above `subagent_compliance`, in `apply_replays[].anchor` prose, or in parent pass-through after replay.

## Schema variance (sandbox dogfood, May 2026)

Subagents sometimes emit richer blocks than `compliance_schemas.md` v1 — extra keys like `ownership_check`, `inputs_evaluated`, or nested evidence. First observed during Mode A dogfood against sandbox issue #2 (Judge round-1).

**Why extras belong in prose, not the block**: `scripts/lib/compliance_schema.py` `_reject_unknown_keys` hard-fails unknown keys in standalone blocks and in each `parent_compliance.subagents_dispatched[]` entry. Capture diagnostically-useful extras in adjacent PR/issue comment prose.

**Drift as feedback**: when the same extra field appears across multiple dispatches of the same role, file an issue against `compliance_schemas.md` proposing the addition rather than asking subagents to drop it.

## See also

- `docs/compliance_schemas.md` — canonical v1 schema and CI-MUST rules
- `scripts/lib/compliance_schema.py` — validator authority
- ADR-026 — compliance contracts ratification
