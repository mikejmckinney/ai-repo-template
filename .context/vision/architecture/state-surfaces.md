# State Surfaces

This diagram shows the ADR-025 split between canonical GitHub live-state surfaces and the repo-local reference or retrospective files that still exist in-tree.

```mermaid
flowchart TD
    subgraph GitHubLiveState[Canonical live coordination]
        Issue["GitHub issue body<br>Durable task contract"] --> PR["GitHub PR body<br>Implementation and verification contract"]
        PR --> Baton["Latest agent-state:v1 comment<br>Mutable live baton"]
        Baton --> Labels["Labels<br>agent:claimed / agent:blocked / agent:awaiting-review"]
    end

    subgraph RepoLocalReference[Repo-local reference and durable lessons]
        StateReadme[".context/state/README.md<br>Explains the GitHub-first model"]
        StateTemplate[".context/state/agent_state_comment_template.md<br>Copy/paste shape for the baton"]
        Sessions[".context/sessions/latest_summary.md<br>Durable lessons, not live state"]
    end

    StateReadme -. documents .-> Baton
    StateTemplate -. shapes .-> Baton
    Sessions -. retrospective input only .-> PR

        Removed["Removed repo-local boards and task files<br>Do not recreate `_active.md` claim boards"] -. historical warning .-> StateReadme
```

## Notes

- Only the four GitHub surfaces in the top lane carry normal live coordination state.
- The repo-local files in the lower lane are still useful, but they are reference or retrospective surfaces rather than a second live-state system.
- Onboarding and template-detection rules need to keep this distinction explicit so downstream repos do not inherit template-specific state assumptions.
