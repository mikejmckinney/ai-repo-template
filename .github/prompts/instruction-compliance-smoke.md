---
description: Smoke-test agent startup, pointer loading, role dispatch, and ADR-026 compliance evidence without making code changes.
agent: agent
---

# Instruction Compliance Smoke Prompt

Use this prompt when you need a low-risk check that an agent can load the
repository instruction chain, make a role-dispatch decision, and emit ADR-026
compliance evidence without editing files.

## Rules

1. Do **not** modify files, open PRs, or post comments unless the user
   explicitly asks you to after the smoke output.
2. Start with the parent `Session handshake v<N>` token from `AGENTS.md` unless
   the session already emitted it or the user explicitly skipped it.
3. Read the relevant pointer chain:
   - `AGENTS.md`
   - `.github/copilot-instructions.md` when running under Copilot
   - `AI_REPO_GUIDE.md`
   - `.context/00_INDEX.md`
   - `.context/rules/process_subagent_bootstrap.md`
4. Identify which role would own the requested hypothetical task by consulting
   `.context/rules/process_role_selection.md` and
   `.context/rules/agent_ownership.md`.
5. If the task naturally requires a role subagent, describe the dispatch packet
   you would send. Do not actually dispatch unless the user asks for a live
   subagent run.
6. Do not claim that CI or this prompt proves runtime dispatch. It only checks
   declared evidence shape and instruction-chain reasoning.

## Output

Return exactly these sections:

## Smoke result

- Verdict: PASS | NEEDS_CONTEXT | FAIL
- Hypothetical task: <one sentence>
- Owning role(s): <roles>
- Would dispatch subagent(s): <yes/no + why>

## Pointer evidence

- <resource> — <why applicable> — <decision affected>

## Dispatch packet preview

- Role: <role or N/A>
- Goal: <goal or N/A>
- Expected output: <artifact or N/A>
- Issue/PR/plan/diff link: <link or NEEDS_CONTEXT>
- Process files: <files>
- Ownership constraints: <constraints>
- Gate state: <state>
- AGENTS_MD_VERSION: <N>
- Allowed deviations: <none or list>

## Compliance preview

```yaml
parent_compliance:
  handshake_token: Session handshake v<N>
  agents_md_version: <N>
  runtime_pointer:
    path: .github/copilot-instructions.md
    loaded: true
    decision_affected: Used Copilot-specific dispatch guidance for the smoke check.
  applicable_roles:
    - <role>
  subagents_dispatched: []
  monolithic_justification: Smoke prompt previews dispatch only; no subagent output was used as gate evidence.
  plan_gate:
    status: exempt
    link: null
    gate_status:
      triggered: false
      applied: false
  diff_gate:
    status: exempt
    link: null
    gate_status:
      triggered: false
      applied: false
  adr_required:
    required: false
    link: null
  deviations: []
  verification_results:
    - command: instruction-compliance-smoke
      result: pass
      evidence: Pointer evidence and dispatch preview included above.
```

If context is missing, set `Verdict: NEEDS_CONTEXT` and list the missing
issue/PR/plan/diff link or task details instead of guessing.
