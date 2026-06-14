---
description: Weekly repo review — structured JSON follow-up issues only (full-repo static scan).
agent: agent
---

# Weekly repository review

You are performing a **weekly full-repo health review** on the current `main` branch. Your job is to review supplied evidence and output **structured JSON only** — no Markdown prose outside the JSON object.

## Hard rules

- Review the **repository state on main** — not individual open PRs.
- **Do not** edit code, ADRs, or context-pack files in this job.
- **Do not** open pull requests.
- **Prefer no issue over a speculative issue.** Every suggestion must cite concrete evidence from the supplied artifacts.
- **Do not** suggest broad rewrites unless evidence shows a recurring failure pattern.
- Output **valid JSON only** — no preamble, no markdown fences, no commentary after the JSON.

## Lenses

Separate your analysis into three buckets in the JSON output:

1. **`follow_up_issues`** — actionable bug/process/test/doc/invariant follow-ups with evidence.
2. **`adr_updates`** — ADR amendment **candidates** (create follow-up issues only; do not edit ADRs).
3. **`context_pack_updates`** — context-pack tuning candidates (rules, indexes, prompts) with paths to add/remove.

Align with [`.context/rules/process_opportunity_feedback.md`](../../.context/rules/process_opportunity_feedback.md) and [ADR-027](../../docs/decisions/adr-027-opportunity-feedback-channel.md): high-impact, evidence-backed, bounded scope.

## Required JSON shape

```json
{
  "summary": "brief summary",
  "follow_up_issues": [
    {
      "title": "string",
      "labels": ["agent-suggested"],
      "severity": "low|medium|high",
      "body": "markdown body",
      "evidence": ["string"],
      "dedupe_key": "stable-short-key"
    }
  ],
  "adr_updates": [
    {
      "adr": "docs/decisions/adr-019-per-role-model-tiering.md",
      "title": "string",
      "body": "markdown body",
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
      "dedupe_key": "stable-short-key"
    }
  ]
}
```

## Dedupe keys

- Use stable, short, kebab-case keys scoped to the repo (e.g. `weekly-invariant-052-missing-link`).
- Automation creates umbrella rows with marker `<!-- weekly-review:key=<dedupe_key> -->` in follow-up text when issues are opened manually later.
- Re-runs the same ISO week must not duplicate rows — reuse the same key only for the same finding.

## Session handshake / context receipt

Pointer only — do **not** mirror full templates here. If you need them for reasoning, follow [`.context/rules/process_session_start.md`](../../.context/rules/process_session_start.md). **Your final output must still be JSON only**.

## Empty arrays are valid

If nothing actionable is found, return empty arrays and a short summary explaining why.
