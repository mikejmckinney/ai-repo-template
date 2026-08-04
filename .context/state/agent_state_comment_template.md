# `agent-state:v1` comment template

Copy this template into a GitHub issue or PR comment. Keep one latest
comment current for the work item; update it instead of scattering live
state across multiple repo-local files.

Header fields: use `issue:NNN` for the linked issue. Use `pr:MMM` once a
PR exists, `pr:pending` before PR creation, or `pr:none` for issue-only
work with no planned PR.

For `Status`, use exactly one value from the template's enum. Do not
invent synonyms or add new values without updating ADR-025 and the
associated checks/docs.

```markdown
<!-- agent-state:v1 issue:NNN pr:pending branch:feature/example owner:implementer -->

**Status:** in_progress | awaiting_user_input | blocked | awaiting_review | done
**Updated:** YYYY-MM-DDTHH:MM:SSZ

## actions
fixed umbrella newline stripping
added bats case for summary callout

## Blockers / awaiting (Optional)

## Outcomes (Optional)
test.sh 1000/0
pushed 6315da1

## Lessons learned (Optional)
command substitution stripped trailing newline — wrote render output to file instead

## Next steps (Optional)
verify Summary block on sandbox #102

## References (Optional)
- Issue: https://github.com/OWNER/REPO/issues/NNN
- PR: https://github.com/OWNER/REPO/pull/MMM
- File: https://github.com/OWNER/REPO/blob/COMMIT/path/to/file
- Run: https://github.com/OWNER/REPO/actions/runs/RUN_ID

```

- **Required-minimal:** `status`, `updated`, `actions`.
- **Optional:** `blockers / awaiting`, `outcomes`, `lessons`, `next_steps`, `references`.
  These are empty when none apply.
- **`actions`** = what the turn did (per-turn by nature — deliberately not `task`/`objective`, which
  read as standing goals and would be copied identically every turn).
- When a turn changes repository-owned task files, commit and push first, then
  include the durable commit or PR URL in `outcomes`. Known failing tests remain
  explicit; they do not justify leaving task work only on local disk.
- **`outcomes`** = results the transcript redacts (highest recovery value). No enforcement: an agent
  narrating its turn states this naturally; a hard non-empty rule would induce fabrication on
  mid-flight turns (a fabricated outcome is worse than an absent one).
- **`lessons learned`** = concise recovery-relevant surprises; promote durable
  decisions or incidents to an ADR or postmortem.
- **`References`** = bounded pointers to the issue, PR, files, commits, or runs needed to continue.
  Use full GitHub URLs so references remain clickable across repositories; do not use bare IDs.
- Link every addressable GitHub resource on first mention in every section, not
  only under `References`. This applies to issues, PRs, comments, commits,
  branches, Actions runs, ADRs, and repository files. Local-only paths and
  commands remain inline code.

Do not add long decision history, full file lists, verification matrices,
here. Use plan comments, PR bodies, ADRs, CI for those.

## Optional opportunity notes

The comment may include opportunity notes using the eight
fields in `AGENTS.md`: title, evidence, impact, recommendation, scope,
suggested_next_action, confidence, and duplicate_check. These
notes are prose-governed and are not schema-validated. Maintainers may apply the
`agent-suggested` label to follow-up issues filed from this channel.
