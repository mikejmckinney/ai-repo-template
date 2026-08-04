# State Surfaces

This diagram shows the ADR-025 split between canonical GitHub state and the
repo-local reference files that define its contract.

```mermaid
flowchart TD
    subgraph GitHubLiveState[Canonical live coordination]
        Issue["GitHub issue body<br>Durable task contract"] --> PR["GitHub PR body<br>Implementation and verification contract"]
        PR --> Baton["Latest agent-state:v1 comment<br>Mutable live baton"]
        Baton --> Labels["Labels<br>agent:claimed / agent:blocked / agent:awaiting-review"]
    end

    subgraph RepoLocalReference[Repo-local reference]
        StateReadme[".context/state/README.md<br>Explains the GitHub-first model"]
        StateTemplate[".context/state/agent_state_comment_template.md<br>Copy/paste shape for the baton"]
    end

    StateReadme -. documents .-> Baton
    StateTemplate -. shapes .-> Baton
    Removed["Removed repo-local state files<br>Do not recreate state mirrors"] -. historical warning .-> StateReadme
```

## Notes

- Only the four GitHub surfaces in the top lane carry normal live coordination state.
- The repo-local files in the lower lane define the contract rather than
  carrying a second copy of task state.
- Onboarding and template-detection rules need to keep this distinction explicit so downstream repos do not inherit template-specific state assumptions.
