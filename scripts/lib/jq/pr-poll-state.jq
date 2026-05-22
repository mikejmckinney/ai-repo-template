# pr-poll-state.jq — derive the helper's snapshot state from GitHub data.
#
# Inputs supplied by scripts/pr-resolve-all-poll.sh:
#   --argjson allowlist <normalized allow-list array>
#   --slurpfile head <head.json>
#   --slurpfile reviews <reviews.json>
#   --slurpfile pr_comments <comments.json>
#   --slurpfile threads <threads.json>
#
# Output: JSON object with head metadata, participating bots, and per-bot
# terminal state. Replaces the large inline jq program in
# scripts/pr-resolve-all-poll.sh.

def normalize_login:
  (. // "")
  | ascii_downcase
  | sub("\\[bot\\]$"; "");

def allowlisted($set):
  (normalize_login as $n | ($set | index($n)) != null);

def compact:
  map(select(. != null and . != ""));

($head[0].data.repository.pullRequest) as $pr
| ($pr.commits.nodes[0].commit.committedDate // null) as $head_commit_ts
| ($pr.headRefOid // "") as $head_sha
| (($threads[0] // [])
   | map(
       . + {
         root_author: (.comments.nodes[0].author.login // ""),
         root_author_normalized: ((.comments.nodes[0].author.login // "") | normalize_login)
       }
     )) as $thread_rows
| ({
     head: $head_sha,
     head_committed_at: $head_commit_ts,
     reviews: ($reviews[0] // []),
     pr_comments: ($pr_comments[0] // []),
     threads: $thread_rows
   }) as $src
| ($src.reviews
   | map(select((.author.login // "") | allowlisted($allowlist)) | (.author.login | normalize_login))
   + ($src.pr_comments
      | map(select((.author.login // "") | allowlisted($allowlist)) | (.author.login | normalize_login)))
   + ($src.threads
      | map(.comments.nodes // [])
      | add // []
      | map(select((.author.login // "") | allowlisted($allowlist)) | (.author.login | normalize_login)))
   | unique
  ) as $participating
| ($src.threads
   | map(select(.isResolved == false and (.root_author | allowlisted($allowlist))))
  ) as $unresolved_bot_threads
| ($src.reviews
   | map(.submittedAt)
   + ($src.pr_comments
      | map(.createdAt))
   + ($src.threads
      | map(.comments.nodes // [])
      | add // []
      | map(.createdAt))
   + [$head_commit_ts]
   | compact
   | sort
   | last
  ) as $latest_actionable
| {
    head: $head_sha,
    head_committed_at: $head_commit_ts,
    latest_actionable: $latest_actionable,
    latest_actionable_epoch: (
      if $latest_actionable == null or $latest_actionable == "" then null
      else (try ($latest_actionable | fromdateiso8601) catch null)
      end
    ),
    participating_bots: $participating,
    unresolved_threads: ($unresolved_bot_threads | length),
    bots: (
      $participating
      | map(. as $bot
  | ($src.reviews
     | map(select(
         (.author.login // "" | normalize_login) == $bot
         and (
           (
             (.state // "") == "PENDING"
             and (
               (.commit.oid // "") == $head_sha
               or (.commit == null)
             )
           )
           or ((.commit.oid // "") == $head_sha)
         )
       ))
    ) as $current_head_reviews
          | ($current_head_reviews
             | map(select((.state // "") == "PENDING"))
             | length > 0
            ) as $has_pending_current_head_review
          | ($current_head_reviews
             | map(select(
                 ((.state // "") == "APPROVED"
                  or (.state // "") == "CHANGES_REQUESTED"
                  or (.state // "") == "COMMENTED"
                  or (.state // "") == "DISMISSED")
               ))
             | sort_by(.submittedAt // "")
             | last // {}
            ) as $latest_current_head_review
          | ($has_pending_current_head_review
             | if . then "PENDING" else ($latest_current_head_review.state // "") end
            ) as $current_head_review_state
          | {
            login: $bot,
            participating: true,
            unresolved_root_threads: (
              $unresolved_bot_threads
              | map(select(.root_author_normalized == $bot))
              | length
            ),
            current_head_pending: $has_pending_current_head_review,
            current_head_review_state: $current_head_review_state,
            current_head_review: (
              ($has_pending_current_head_review | not)
              and (
                $current_head_review_state == "APPROVED"
                or $current_head_review_state == "CHANGES_REQUESTED"
                or $current_head_review_state == "COMMENTED"
              )
            ),
          })
        | map(
            . + {
              terminal: (.current_head_review and (.unresolved_root_threads == 0))
            }
          )
      )
  }
