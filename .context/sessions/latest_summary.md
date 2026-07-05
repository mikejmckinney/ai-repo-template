# Session: 2026-07-05 — weekly/fix-2026-W27 — OP

**Status**: in_progress
**Issue/PR**: [#467](https://github.com/mikejmckinney/ai-repo-template/issues/467) umbrella / weekly fix pass 2026-W27
**Started**: 2026-07-05T08:00:00Z

## What Was Accomplished

- Weekly review fix pass: retargeted ADR-031-removed bootstrap pointers in role files, Copilot instructions, `00_INDEX.md`, and instruction-compliance-smoke prompt.
- Restored production `role:<name>` multi-dispatch scope via `.agents/*.md` `owned_paths` fallback (`scripts/load-role-owned-paths.sh`).
- Added `076-bootstrap-surface-pointers.sh` invariant; rotated stale `latest_summary.md` archive.

## What Shipped

Pending PR merge — consumer migration for ADR-031 slim catalog and multi-dispatch role-glob fallback.

## Harder Than Expected

nothing notable

## Generalizable Lessons

When slimming `.context/rules/`, update bootstrap consumers in the same change set or add a `test.sh` invariant immediately — context-pack manifest updates alone do not prevent ghost-path drift.

## Files Modified

- `.agents/*.md`, `.github/copilot-instructions.md`, `.context/00_INDEX.md`, `.github/prompts/instruction-compliance-smoke.md`
- `scripts/load-role-owned-paths.sh`, `scripts/multi-dispatch-safety.sh`, `scripts/checks/076-bootstrap-surface-pointers.sh`

## Open Items / Next

1. Human review of `weekly/fix-2026-W27` draft PR
2. Sandbox workflow proof for `agent-parallelism-report.yml` ownership source (still reads `agent_ownership.md` when present)
