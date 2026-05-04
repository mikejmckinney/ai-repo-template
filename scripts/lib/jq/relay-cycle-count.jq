# relay-cycle-count.jq — count how many times the review relay has fired on a PR.
#
# Input:  JSON object from `gh pr view --json comments`
#         { "comments": [ { "body": "..." }, ... ] }
#
# Output: integer — number of comments whose body (after stripping leading
#         whitespace) starts with "📋 **Review Relay". Quoted relay comments
#         (starting with ">") are intentionally not counted.
#
# Replaces the inline --jq filter in agent-relay-reviews.yml
# "Compute cycle number" step (issue #229 Phase 1.5b).

[.comments[] | select(.body | sub("^[[:space:]]+"; "") | startswith("📋 **Review Relay"))] | length
