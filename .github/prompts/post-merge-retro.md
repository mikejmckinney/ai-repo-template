---
description: Post-merge retrospective — structured JSON follow-up issues only (no code/ADR edits).
agent: agent
---

# Post-merge retrospective review

You are performing a **post-merge retrospective** on a merged pull request. Your job is to review evidence and output **structured JSON only** — no Markdown prose outside the JSON object.

When repository or read-only GitHub tools are available, use them to retrieve
omitted or truncated PR diffs, discussion, reviews, checks, and current files.
Treat the automation evidence inventory as a minimum coverage contract. Never
use a GitHub write operation.

For a `full-evidence` run, the prompt contains addresses and byte counts rather
than inline source bodies. Read the listed local evidence files and relevant
current repository paths, then use read-only GitHub tools to close inventory
gaps. Do not emit a finding from an excerpt when its full source is addressable.

## Cadence-specific rules

- Review the **merged PR only** — do not propose changes to the working tree.
- Compare merged-PR evidence against **Current main (HEAD) state for PR-touched paths** (automation-supplied). **Do not emit a finding** when the problem is already resolved on `main` HEAD.
- **`repro_steps` required** on every `follow_up_issues` row — concrete steps to reproduce the bug before a fix. If you cannot define reproduction steps, do not emit the finding.
- **Do not** suggest broad rewrites unless evidence shows a recurring failure pattern.
- Output **valid JSON only** — no preamble, no markdown fences, no commentary after the JSON.

## Lenses

Apply the injected `shared-review-lenses.md` contract before categorizing findings.

Emit actionable bug, process, test, and documentation follow-ups in
`follow_up_issues`. Do not emit separate ADR or context-pack candidate buckets;
those are ordinary follow-up issues when they identify a concrete defect.

Align with [`AGENTS.md`](../../AGENTS.md) §"Opportunity feedback" and [ADR-027](../../docs/decisions/adr-027-opportunity-feedback-channel.md): high-impact, evidence-backed, bounded scope.

## Required JSON shape

```json
{
  "pr": 123,
  "summary": "brief summary",
  "follow_up_issues": [
    {
      "title": "string",
      "labels": ["agent-suggested"],
      "triage_version": 2,
      "impact": "incorrect-behavior|dx-perf-doc|meta-harness",
      "impact_magnitude": "bounded|material|critical",
      "trigger_likelihood": "common|edge|fringe",
      "affected_scope": "isolated|limited|broad",
      "reversibility": "easy|moderate|hard",
      "fix_cost": "trivial|moderate|large",
      "confidence": "low|medium|high",
      "uncertainty": "none or a concise statement of missing evidence",
      "regression_guard": false,
      "body": "markdown body",
      "evidence": ["string"],
      "repro_steps": ["step 1 to reproduce", "step 2 observe failure"],
      "dedupe_key": "stable-short-key"
    }
  ]
}
```

Omit `evidence_complete` in bounded mode. Full-evidence prompt assembly adds the
field only when the provider can read every required local source, the complete
diff, and the current versions of all PR-touched paths. An incomplete
full-evidence review is a failed run, not an empty-finding result.

## Finding triage

Every row in **`follow_up_issues`** must follow the injected normalized AP11
observation contract. **Do not emit** deprecated `severity` or derived
`priority_band`; automation validates observations and stamps `priority_band`
at validate/merge time.

Rules:

- Use `fix_cost=trivial` + `regression_guard=true` **only** for cheap test/invariant guards — not for general small fixes.
- Do not set `regression_guard=true` when `trigger_likelihood=fringe`.

## Dedupe keys

- Use stable, short, kebab-case keys scoped to this PR (e.g. `pr382-missing-invariant-test`).
- Automation creates issues with marker `<!-- postmerge-retro:pr=<PR>:key=<dedupe_key> -->`.
- Re-runs must not duplicate issues — reuse the same key only for the same finding.

## An empty array is valid

If nothing actionable is found, return an empty `follow_up_issues` array and a short summary explaining why.
