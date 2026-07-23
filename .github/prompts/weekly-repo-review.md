---
description: Weekly repo review — structured JSON follow-up issues only (full-repo static scan).
agent: agent
---

# Weekly repository review

You are performing a **weekly full-repo health review** on the current `main` branch. Your job is to inspect the repository and output **structured JSON only** — no Markdown prose outside the JSON object.

Use repository tools for source evidence and read-only GitHub tools for relevant
issues, pull requests, and workflow runs when available. The supplied context
pack is startup context, not the review boundary. Never use a GitHub write
operation.

The automation appends a **context pack** containing `AGENTS.md` plus task-specific governance context. That pack is **rules and process**, not the full codebase. **You must read the repository working tree** (Cursor local mode) or mounted workspace sources (Antigravity path) to review code, scripts, workflows, checks, docs, and tests.

## Cadence-specific rules

- Review the **repository state on `main`** — not individual open PRs.
- **Inspect files as needed.** Every finding must cite concrete paths (and lines when possible) from the repo.
- **`repro_steps` required** on every `follow_up_issues` row — concrete steps to reproduce the bug. If you cannot define reproduction steps, do not emit the finding.
- **Do not** suggest broad rewrites unless evidence shows a recurring failure pattern.
- Output **valid JSON only** — no preamble, no markdown fences, no commentary after the JSON.

## Lenses

Apply the injected `shared-review-lenses.md` contract before categorizing findings.

Emit actionable bug, process, test, documentation, and invariant follow-ups in
`follow_up_issues`. Do not emit separate ADR or context-pack candidate buckets;
those are ordinary follow-up issues when they identify a concrete defect.

Align with [`AGENTS.md`](../../AGENTS.md) §"Opportunity feedback" and [ADR-027](../../docs/decisions/adr-027-opportunity-feedback-channel.md): high-impact, evidence-backed, bounded scope.

## Required JSON shape

```json
{
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
      "dedupe_key": "repo-invariant-example"
    }
  ]
}
```

Follow the injected normalized AP11 observation contract.
`priority_band` is derived by automation; do not emit it. `severity` is deprecated.

## Dedupe keys

- Use stable, short, kebab-case keys scoped to the **repository** (not the weekly workflow): `repo-<area>-<short-desc>` (e.g. `repo-invariant-052-missing-link`, `repo-advisory-stale-context`).
- Do **not** prefix keys with `weekly-` — the batch cadence is already captured by `run_week`.
- Each finding **must** include `evidence[]` with at least one **repo-relative file path** (e.g. `scripts/checks/040-file-content.sh`) so automation can link evidence in the umbrella issue.
- The `body` field must explain the finding in full (what is wrong, why it matters, suggested fix). The umbrella issue renders `body` + linked evidence — do not rely on the title alone.

## An empty array is valid

If nothing actionable is found, return an empty `follow_up_issues` array and a short summary explaining why.
