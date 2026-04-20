# Expand Backlog Entry

> **Usage**: This prompt is invoked programmatically by
> `.github/workflows/backlog-to-issues.yml` when a backlog entry is missing
> its `body` or `acceptance_criteria` fields. It is not intended for manual
> invocation, but can be tested manually with
> `@claude follow .github/prompts/expand-backlog-entry.md`.

---

You are expanding a sparse backlog entry into a complete, actionable GitHub
issue. Your job is to read the provided context (entry YAML, role file, roadmap
phase, code quality rules) and produce a completed entry YAML with `body` and
`acceptance_criteria` filled in. Do not guess — reason from the provided
context only.

> **How to run this prompt**: Read this entire file before starting. Then
> execute Phase 1, Phase 2, Phase 3 in order. Do not interleave or skip phases.

## Phase 1: Read All Context

Before writing anything, read all four context blocks provided in the user
message:

1. **Entry YAML** — the sparse entry with `id`, `title`, and any other fields
   already set.
2. **Role context** — the matching `.github/agents/<role>.agent.md` file (may
   be "N/A" if no role is set). Use the Do/Don't list to constrain scope.
3. **Roadmap phase section** — the matching phase from `.context/roadmap.md`
   (may be empty for template placeholder repos). This is the primary source of
   requirements.
4. **Domain code quality rules** — `.context/rules/domain_code_quality.md`.
   Hard rules H1–H8 and Soft rules S1–S6 constrain all acceptance criteria.

After reading, determine if you have enough context to write a
meaningful, non-fabricated `body` and `acceptance_criteria`. If no,
proceed to Phase 3 and emit `needs_human: true` — do not invent requirements.

## Phase 2: Expand the Entry

If context is sufficient, produce an expanded YAML entry block containing:

- `body` — 2–4 sentences explaining what to build, why it matters, and how it
  fits into the roadmap phase. Must be grounded in the roadmap and role
  context. Do not fabricate technical specifics that are not in the provided
  context.
- `acceptance_criteria` — a list of 3–8 concrete, testable conditions that
  define "done" for this entry. Each criterion must:
  - Be falsifiable (can be demonstrated pass/fail)
  - Reference specific behaviors, not vague goals ("returns 200" not "works")
  - Align with the role's Do list and not violate the role's Don't list
  - Not contradict any Hard Rule from the quality rules file

**No-fabrication rule**: If the roadmap phase section is a template placeholder
(e.g., contains "TEMPLATE_PLACEHOLDER" or has only generic "Foundation" /
"Phase N" content without project-specific details), emit `needs_human: true`
rather than inventing project-specific requirements. It is better to hold the
entry for human review than to create a misleading issue.

## Phase 3: Output

Output **only** a fenced YAML code block (using the `yaml` language identifier) containing the completed entry.
Include all original fields from the input entry YAML, plus the newly-generated
`body` and `acceptance_criteria`. Do not add the `issue:` field — that is
written back by the workflow. Do not add fields not in the schema.

If Phase 1 determined `needs_human: true`, output only:

```yaml
needs_human: true
```

Otherwise output the complete expanded entry:

```yaml
id: <original id>
title: "<original title>"
role: <role if set>
phase: <phase if set>
labels: [<labels if set>]
depends_on: [<depends_on if set>]
auto_assign: <auto_assign if set>
body: |
  <2–4 sentence description grounded in roadmap + role context>
acceptance_criteria:
  - "<concrete, testable condition 1>"
  - "<concrete, testable condition 2>"
  - "<concrete, testable condition 3>"
```

## Rules

- **Do not fabricate requirements** not present in the roadmap, role file, or
  entry YAML. If the context is thin, say so with `needs_human: true`.
- **Do not add new fields** beyond those defined in
  `.context/backlog.schema.json` (id, title, role, phase, labels, depends_on,
  auto_assign, body, acceptance_criteria, issue).
- **Do not include the `issue:` field** — the workflow writes it back.
- **Do not include comments** in the output YAML — the workflow extracts the
  fenced YAML block from your response and parses it directly; comments are
  not preserved.
- **Output exactly one fenced YAML block** and nothing else after it. The
  workflow uses a regex to extract the YAML block from your response.
- **Keep body concise**: 2–4 sentences. Acceptance criteria are the place for
  detail, not the body.
- **Acceptance criteria must be testable**: reviewers should be able to verify
  each criterion by running a command, reading a file, or observing an API
  response — not by reading prose.
