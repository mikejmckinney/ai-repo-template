---
description: Smoke-test that Judge/Critic catch outcome-theater PRs — both "generic verification only" and "empty outcome checklist" failure modes.
agent: agent
---

# Outcome Validation Smoke Prompt

Use this prompt to verify that a Judge/Critic dispatch correctly REQUEST_CHANGES
on a PR that satisfies generic verification but does **not** prove the issue's
`User outcome (15-minute test)` was performed.

The prompt is the static fixture — agents don't post anything to GitHub. The
prompt is also the source-of-truth for what Judge and Critic must catch under
issue #311's outcome-first validation regime.

## Rules

1. Do **not** modify files, open PRs, or post comments.
2. Read [`.context/rules/process_pr_completion.md`](../../.context/rules/process_pr_completion.md)
   § "User outcome validation", [`.agents/judge.md`](../../.agents/judge.md)
   diff-gate item 18, and [`.agents/critic.md`](../../.agents/critic.md)
   "Outcome theater" smell before evaluating the scenarios.
3. For each scenario below, decide what Judge would emit
   (`APPROVE` / `REQUEST_CHANGES` / `BLOCK`) and what Critic would flag.

## Scenario A — generic verification only

A PR body whose only proof of completion is:

```
## Supporting verification
- [x] `bash test.sh` — pass
- [x] CI green
- [x] Pre-commit passed

## User outcome validation — PRIMARY
N/A — covered by CI.
```

The linked issue's `User outcome (15-minute test)` was a checklist with five
specific reviewability questions; none are answered.

**Expected Judge output:** `REQUEST_CHANGES` per diff-gate item 18 — the
PRIMARY section is non-empty but does not address the issue's problem
statement.

**Expected Critic output:** `CRITIC DECISION: REQUEST_CHANGES` — flag
"outcome theater" because verification proves CI hygiene, not that the user's
problem statement was tested.

## Scenario B — verbatim checklist, no per-question evidence

A PR body that copies the issue's user-outcome checklist verbatim into the
PRIMARY section:

```
## User outcome validation — PRIMARY

**Problem statement tested:** yes
**User outcome / 15-minute test performed:** yes

**Steps performed:**
1. Did the plan identify the issue problem statement?
2. Does the plan separate primary outcome from supporting checks?
3. Does Judge request changes when outcome evidence is generic?

**Evidence:**
- See diff.

**Result:** problem statement resolved
```

The section is shape-correct (all sub-fields present, `Result: problem
statement resolved`) but the **Evidence** field cites no concrete artifact
mapping each question to a specific diff/PR/issue location.

**Expected Judge output:** `REQUEST_CHANGES` per diff-gate item 18 — evidence
"See diff" is generic; per-question citations are missing.

**Expected Critic output:** `CRITIC DECISION: REQUEST_CHANGES` — flag
"outcome theater" because the section is structurally compliant but evidentially
empty (the section-shaped-but-empty failure mode called out in issue #311
acceptance criteria).

## Output

Return exactly:

## Smoke result
- Scenario A verdict: <REQUEST_CHANGES expected; what Judge/Critic would actually emit>
- Scenario B verdict: <REQUEST_CHANGES expected; what Judge/Critic would actually emit>
- Overall: PASS if both scenarios elicit REQUEST_CHANGES from both Judge and Critic; FAIL otherwise.

## Why each scenario fails

- Scenario A: <one sentence — generic verification doesn't prove user outcome>
- Scenario B: <one sentence — section shape without per-question evidence is theater>

## Caveat

This prompt is a static review fixture. It exercises Judge/Critic *reasoning*
against scripted PR bodies; it does not prove that any particular agent will
actually emit REQUEST_CHANGES at runtime. Static check
`scripts/checks/047-outcome-validation-and-op.sh` ensures the rule files and
templates carrying the gate language remain present; the runtime behavior is
validated by Judge/Critic themselves on each PR.
