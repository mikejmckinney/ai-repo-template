---
description: Weekly repo review — structured JSON follow-up issues only (full-repo static scan).
agent: agent
---

# Weekly repository review

You are performing a **weekly full-repo health review** on the current `main` branch. Your job is to inspect the repository and output **structured JSON only** — no Markdown prose outside the JSON object.

The automation appends a **context pack** containing `AGENTS.md` plus task-specific governance context. That pack is **rules and process**, not the full codebase. **You must read the repository working tree** (Cursor local mode) or mounted workspace sources (Antigravity path) to review code, scripts, workflows, checks, docs, and tests.

## Hard rules

- Review the **repository state on `main`** — not individual open PRs.
- **Inspect files as needed.** Every finding must cite concrete paths (and lines when possible) from the repo.
- **Do not** edit code, ADRs, or context-pack files in this job.
- **Do not** open pull requests.
- **Prefer no issue over a speculative issue.** Speculation from injected rules alone is insufficient — cite repo evidence.
- **`repro_steps` required** on every `follow_up_issues` row — concrete steps to reproduce the bug. If you cannot define reproduction steps, do not emit the finding.
- **Do not** suggest broad rewrites unless evidence shows a recurring failure pattern.
- Output **valid JSON only** — no preamble, no markdown fences, no commentary after the JSON.

## Lenses

Apply the injected `shared-review-lenses.md` contract before categorizing findings.

Separate your analysis into three buckets in the JSON output:

1. **`follow_up_issues`** — actionable bug/process/test/doc/invariant follow-ups with evidence.
2. **`adr_updates`** — ADR amendment **candidates** (create follow-up issues only; do not edit ADRs).
3. **`context_pack_updates`** — context-pack tuning candidates (rules, indexes, prompts) with paths to add/remove.

Align with [`AGENTS.md`](../../AGENTS.md) §"Opportunity feedback" and [ADR-027](../../docs/decisions/adr-027-opportunity-feedback-channel.md): high-impact, evidence-backed, bounded scope.

## Required JSON shape

```json
{
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
      "dedupe_key": "repo-invariant-example"
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
      "dedupe_key": "repo-invariant-example"
    }
  ],
  "context_pack_updates": [
    {
      "pack": "string",
      "reason": "string",
      "impact": "incorrect-behavior|dx-perf-doc|meta-harness",
      "trigger_likelihood": "common|edge|fringe",
      "fix_cost": "trivial|moderate|large",
      "regression_guard": false,
      "add": ["path"],
      "remove": ["path"],
      "evidence": ["string"],
      "dedupe_key": "repo-invariant-example"
    }
  ]
}
```

`priority_band` is derived by automation. Do not emit it. `severity` is deprecated.

## Dedupe keys

- Use stable, short, kebab-case keys scoped to the **repository** (not the weekly workflow): `repo-<area>-<short-desc>` (e.g. `repo-invariant-052-missing-link`, `repo-advisory-stale-context`).
- Do **not** prefix keys with `weekly-` — the batch cadence is already captured by `run_week`.
- Each finding **must** include `evidence[]` with at least one **repo-relative file path** (e.g. `scripts/checks/040-file-content.sh`) so automation can link evidence in the umbrella issue.
- The `body` field must explain the finding in full (what is wrong, why it matters, suggested fix). The umbrella issue renders `body` + linked evidence — do not rely on the title alone.

## Session handshake

Pointer only — do **not** mirror full templates here. Follow the startup contract in [`AGENTS.md`](../../AGENTS.md). **Your final output must still be JSON only**.

## Empty arrays are valid

If nothing actionable is found, return empty arrays and a short summary explaining why.
