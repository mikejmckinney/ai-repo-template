---
description: Post-merge retrospective — structured JSON follow-up issues only (no code/ADR edits).
agent: agent
---

# Post-merge retrospective review

You are performing a **post-merge retrospective** on a merged pull request. Your job is to review evidence and output **structured JSON only** — no Markdown prose outside the JSON object.

## Hard rules

- Review the **merged PR only** — do not propose changes to the working tree.
- **Do not** edit code, ADRs, or context-pack files in this job.
- **Do not** open pull requests.
- **Prefer no issue over a speculative issue.** Every suggestion must cite concrete evidence from the supplied artifacts.
- Compare merged-PR evidence against **Current main (HEAD) state for PR-touched paths** (automation-supplied). **Do not emit a finding** when the problem is already resolved on `main` HEAD.
- **`repro_steps` required** on every `follow_up_issues` row — concrete steps to reproduce the bug before a fix. If you cannot define reproduction steps, do not emit the finding.
- **Do not** suggest broad rewrites unless evidence shows a recurring failure pattern.
- Output **valid JSON only** — no preamble, no markdown fences, no commentary after the JSON.

## Lenses

Separate your analysis into three buckets in the JSON output:

1. **`follow_up_issues`** — actionable bug/process/test/doc follow-ups with evidence.
2. **`adr_updates`** — ADR amendment **candidates** (create follow-up issues only; do not edit ADRs).
3. **`context_pack_updates`** — context-pack tuning candidates (rules, indexes, prompts) with paths to add/remove.

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
  ],
  "adr_updates": [
    {
      "adr": "docs/decisions/adr-019-per-role-model-tiering.md",
      "title": "string",
      "body": "markdown body",
      "impact": "incorrect-behavior|dx-perf-doc|meta-harness",
      "trigger_likelihood": "common|edge|fringe",
      "fix_cost": "trivial|moderate|large",
      "regression_guard": false,
      "dedupe_key": "stable-short-key"
    }
  ],
  "context_pack_updates": [
    {
      "pack": "string",
      "reason": "string",
      "add": ["path"],
      "remove": ["path"],
      "evidence": ["string"],
      "impact": "incorrect-behavior|dx-perf-doc|meta-harness",
      "trigger_likelihood": "common|edge|fringe",
      "fix_cost": "trivial|moderate|large",
      "regression_guard": false,
      "dedupe_key": "stable-short-key"
    }
  ]
}
```

## Finding triage (all buckets)

Every row in **`follow_up_issues`**, **`adr_updates`**, and **`context_pack_updates`** must include:

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

## Session handshake / context receipt

Pointer only — do **not** mirror full templates here. Follow the startup contract in [`AGENTS.md`](../../AGENTS.md). **Your final output must still be JSON only**; do not emit the handshake in the JSON file.

## Empty arrays are valid

If nothing actionable is found, return empty arrays and a short summary explaining why.
