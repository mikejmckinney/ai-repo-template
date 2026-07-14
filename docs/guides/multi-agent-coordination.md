# Optional Multi-Agent Coordination

> **Status:** Optional specialty guidance. Routine implementation is monolithic
> by default under ADR-031.

## Default

Use one implementing agent for routine issue and PR work. The model-ROI
benchmark found no favorable crossover for the multi-role pipeline on the
benchmarked task classes: pipelines were generally slower, often costlier, and
did not materially improve simple Class A quality.

Role files under `.agents/` describe specialties and output formats. They do not
create mandatory path ownership, dispatch stages, handoffs, or compliance
receipts.

## When To Dispatch

Dispatch another agent only when at least one condition applies:

- The user explicitly requests a role or independent review.
- Isolation from the implementing context materially improves review quality.
- Specialized expertise is required and not available in the current agent.
- A high-impact decision justifies independent consensus despite additional
  time and cost.

Do not dispatch merely because a role file exists.

## Registered Specialties

Canonical guidance lives under `.agents/<role>.md`. Platform overlays remain
thin registration shims:

| Platform | Overlay path |
|---|---|
| GitHub Copilot | `.github/agents/<role>.agent.md` |
| Claude Code | `.claude/agents/<role>.md` |
| Cursor | `.cursor/agents/<role>.md` |
| Codex | `.codex/agents/<role>.toml` |

The current specialties are Analyst, Architect, Backend, Critic, DevOps, Docs,
Frontend, Judge, PM, and QA. A caller may use any role independently; no fixed
Analyst-to-Judge pipeline is required.

## Adding Or Changing A Role

Update the canonical role file, each first-class platform overlay, the install
inventory, mirror checks, this guide, and `AI_REPO_GUIDE.md` in the same PR.
Descriptions shared by canonical and overlay files must remain byte-identical.

`owned_paths` and `handoff_targets` in canonical frontmatter are optional hints.
They are not enforced ownership or automatic handoff contracts.

## Parallel Safety

Prefer sequencing when two tasks may edit the same files. The remaining safety
automation uses explicit file lists and exact changed-path overlap:

- `scripts/multi-dispatch-safety.sh` reads an explicit
  `<!-- architect-plan-files -->` fenced path list when present.
- Exact shared paths are a hard overlap and should be sequenced.
- Different paths are not classified through inferred role ownership.
- `.github/workflows/agent-parallelism-report.yml` posts an advisory exact-path
  comparison against other open PRs.

Role labels do not infer file scope. If parallel dispatch is necessary, provide
explicit file lists or coordinate manually.

## State And Handoffs

The assigned issue and linked PR are the durable task contract. Use the latest
`agent-state:v1` comment only when work is paused, blocked, awaiting review, or
handed off. Keep it short: status, blocker, next actions, and receiver.

Do not create committed claim boards or duplicate task-state systems.

## Review

Judge and Critic remain available as independent reviewers. Their exact first
lines are `DECISION:` and `CRITIC DECISION:`. Review outputs do not require
structured compliance or receipt blocks.

## Related Decisions

- [ADR-023](../decisions/adr-023-shared-subagent-canonical.md): canonical role
  bodies and thin platform overlays.
- [ADR-026](../decisions/adr-026-compliance-contracts.md): structured compliance
  contracts retired by the 2026-07-13 amendment.
- [ADR-031](../decisions/adr-031-agent-model-roi-benchmark-policy.md): monolithic
  implementation default and benchmark evidence.
