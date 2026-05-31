# Multi-Agent Flow

This diagram is the template repo's current working model for issue-to-merge execution.
It summarizes the flow described in `docs/guides/multi-agent-coordination.md` and the role/prompt rules under `.context/rules/**`.

```mermaid
flowchart TD
    Request[User request or GitHub issue] --> OP[OP / default agent]
    OP --> Analyst[Analyst]
    Analyst --> Architect[Architect]
    Architect --> JudgePlan{Judge plan-gate}
    Architect --> CriticPlan[Critic plan review]
    CriticPlan --> JudgePlan{Judge plan-gate}
    JudgePlan -->|Approve| PM[PM dispatch + GitHub live state]
    JudgePlan -->|Request changes| Architect

    PM --> Frontend[Frontend]
    PM --> Backend[Backend]
    PM --> DevOps[DevOps]
    PM --> Docs[Docs]

    Frontend --> QA[QA]
    Backend --> QA
    DevOps --> QA
    Docs --> QA

    QA --> CriticDiff[Critic diff review]
    CriticDiff --> JudgeDiff{Judge diff-gate}
    JudgeDiff -->|Approve| Merge[Merge + close-out]
    JudgeDiff -->|Request changes| PM
```

## Notes

- PM is the dispatcher and coordination point between plan approval and role-owned implementation.
- Implementers may run in parallel when ownership boundaries and live-state claims permit it.
- QA, Critic, and Judge are separate delivery gates; green code alone is not approval.
