# Problem Framing

Use this guide for net-new product behavior, consequential scope decisions,
market-facing choices, or work where competing approaches could produce
different user outcomes.

Do not use it as mandatory ceremony for routine bugs, dependency updates,
reverts, or behavior-neutral maintenance. `AGENTS.md` owns the normative trigger
and clarification behavior; this guide supplies the conditional procedure and
output scaffold.

## Procedure

1. Define the affected actor, problem, and job-to-be-done.
2. State the user outcome and a pragmatic 15-minute test.
3. Identify realistic use cases and non-goals.
4. Record evidence and load-bearing assumptions.
5. Compare repository-native and external alternatives.
6. Perform audience, competitive, and impact analysis only when those
   dimensions could change the decision.
7. Recommend go, pivot, or stop.

## Evidence discipline

- Cite sources for external products, market claims, adoption, pricing, and
  capabilities.
- Distinguish verified facts from estimates and state confidence for each
  estimate.
- Describe audiences by observable role and need. Do not collect or infer
  demographic characteristics unless they are relevant, necessary, and
  supported by appropriate evidence.
- Treat impact scores as comparison aids, not facts. Do not average the
  dimensions: a composite can hide a severe low-reach problem or unsupported
  assumptions.

## Output template

Use only the sections needed by the triggered analysis. Omit conditional market
sections when they cannot change the decision.

```markdown
ANALYSIS: <short title>

PROBLEM STATEMENT:
<What problem exists, who experiences it, and why it matters.>

USER OUTCOME:
<What the user will be able to do. Do not describe only deliverables.>

15-MINUTE TEST:
<How someone can pragmatically verify that the outcome was achieved.>

USE CASES:
- <realistic workflow>
- <realistic workflow>

NON-GOALS:
- <explicitly excluded outcome>

EVIDENCE:
- <verified fact and source>
- <uncertain claim, source, and confidence>

LOAD-BEARING ASSUMPTIONS:
- <assumption> - <how it was or will be validated>

TARGET AUDIENCE:
- Primary: <observable role and need>
- Secondary: <observable role and need>
- Estimated reach: <estimate, source, and confidence>

COMPETITIVE LANDSCAPE:
| Solution | Strengths | Weaknesses | Relevant gap |
|---|---|---|---|
| <solution> | <evidence> | <evidence> | <opportunity> |

IMPACT ASSESSMENT:
| Dimension | Score | Evidence | Confidence |
|---|---:|---|---|
| Reach | 1-5 | <basis> | low/medium/high |
| Severity | 1-5 | <basis> | low/medium/high |
| Feasibility | 1-5 | <basis> | low/medium/high |
| Differentiation | 1-5 | <basis> | low/medium/high |

STAKEHOLDER FEEDBACK:
- <feedback> - <how it changed the assumptions or outcome>

RECOMMENDATION:
<go / pivot / stop> - <specific rationale and next action>
```

## Interpreting impact

Score only dimensions that help compare real alternatives. Explain the basis
for each score and any material uncertainty. Do not let high reach cancel a
severe safety or correctness concern, and do not let low differentiation erase
a necessary reliability fix.

The recommendation should follow from the problem, evidence, assumptions, and
user outcome. When it does not, pivot the framing or stop rather than designing
an implementation for the wrong problem.
