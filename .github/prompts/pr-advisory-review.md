---
description: Non-blocking rolling advisory review snapshot for draft/WIP PRs (ai-review:live).
agent: agent
---

# Advisory review snapshot (non-blocking)

You are producing a **single advisory PR comment** for an in-progress pull request.
Apply the injected `shared-review-lenses.md` contract in one pass. This is **not** a formal PR review and **must not** block implementation or merge.

When repository or read-only GitHub tools are available, use them to inspect
relevant files, PR discussion, reviews, and checks beyond the bounded prompt
excerpt. Treat the supplied changed-file/evidence inventory as a minimum
coverage contract. Never use a GitHub write operation.

The automation appends `AGENTS.md`, the shared review lenses, task-triggered
governance context, and PR diff evidence below this prompt (Cursor/Gemini paths),
or mounts equivalent files (Antigravity path). Apply that context when reviewing
workflow and process changes.

## Hard constraints

- **Do not** mark anything blocking or require implementation to wait for this run.
- If an existing advisory snapshot is provided, **do not** repeat findings unless still present at head and material.
- Include the factual **Diff coverage** line in the snapshot header using automation-supplied numbers when provided.

## Output format (exact structure)

Return **only** one JSON object (no Markdown fence or preamble). Automation
validates AP11 fields, derives the priority band, and renders the non-blocking
Markdown envelope.

```json
{
  "findings": [
    {
      "id": "ADV-01",
      "lens": "Correctness",
      "area": "path or component",
      "finding": "Concrete failure mode with evidence and affected behavior.",
      "suggested_action": "Smallest credible correction.",
      "still_present_at_head": true,
      "triage_version": 2,
      "impact": "incorrect-behavior",
      "impact_magnitude": "material",
      "trigger_likelihood": "edge",
      "affected_scope": "limited",
      "reversibility": "moderate",
      "fix_cost": "moderate",
      "confidence": "high",
      "uncertainty": "none",
      "regression_guard": false
    }
  ]
}
```

When there are no findings, return `{ "findings": [] }`. Use shared lens names
and `ADV-NN` IDs. Follow the injected normalized AP11 observation contract;
never emit `severity`, `priority_band`, or a blocking action. Automation owns
classification, the final head, provider/model, diff coverage, and hidden memory.
