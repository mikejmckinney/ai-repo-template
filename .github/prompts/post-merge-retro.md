---
description: Post-merge retrospective — structured JSON follow-up issues only (no code/ADR edits).
agent: agent
---

# Post-merge retrospective review

You are performing a **post-merge retrospective** on a merged pull request. Your job is to review evidence and output **structured JSON only** — no Markdown prose outside the JSON object.

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
      "impact": "incorrect-behavior|dx-perf-doc|meta-harness",
      "trigger_likelihood": "common|edge|fringe",
      "fix_cost": "trivial|moderate|large",
      "regression_guard": false,
      "body": "markdown body",
      "evidence": ["string"],
      "repro_steps": ["step 1 to reproduce", "step 2 observe failure"],
      "dedupe_key": "stable-short-key"
    }
  ]
}
```

## Finding triage

Every row in **`follow_up_issues`** must include:

| Field | Values | Meaning |
|---|---|---|
| `impact` | `incorrect-behavior` \| `dx-perf-doc` \| `meta-harness` | Incorrect output on realistic input vs fails-safe DX/perf vs harness/sandbox meta |
| `trigger_likelihood` | `common` \| `edge` \| `fringe` | Fires on normal inputs vs unusual shape vs rare path |
| `fix_cost` | `trivial` \| `moderate` \| `large` | Implementation cost |
| `regression_guard` | `true` \| `false` (optional, default false) | `true` only for invariant/test/check rows that prevent silent regression |

**Do not emit** deprecated `severity` or derived `priority_band` — automation stamps `priority_band` at validate/merge time.

Rules:

- Use `fix_cost=trivial` + `regression_guard=true` **only** for cheap test/invariant guards — not for general small fixes.
- Do not set `regression_guard=true` when `trigger_likelihood=fringe`.

## Dedupe keys

- Use stable, short, kebab-case keys scoped to this PR (e.g. `pr382-missing-invariant-test`).
- Automation creates issues with marker `<!-- postmerge-retro:pr=<PR>:key=<dedupe_key> -->`.
- Re-runs must not duplicate issues — reuse the same key only for the same finding.

## An empty array is valid

If nothing actionable is found, return an empty `follow_up_issues` array and a short summary explaining why.
