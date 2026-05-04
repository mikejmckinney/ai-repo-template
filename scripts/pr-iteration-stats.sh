#!/usr/bin/env bash
# pr-iteration-stats.sh — Rolling PR review-loop metrics (issue #229 Phase 1).
#
# Queries merged PRs closed in the past <window> days and counts per PR:
#   total_rounds    — number of PR comments whose body matches the
#                     "## Resolution Report" header (any author).
#   fix_rounds      — Resolution Reports where "Fixed in this pass" > 0.
#   rejected_rounds — Resolution Reports where "Fixed in this pass" = 0
#                     AND "Total items found" > 0 (agent rejected all findings).
#   threads_opened  — total review threads opened on the PR.
#   threads_resolved — review threads marked resolved.
#
# Usage
# -----
#   bash scripts/pr-iteration-stats.sh [--window <days>] [--json] [--help]
#
# Flags
#   --window <days>   Look-back window in days (default: 14).
#   --json            Emit one JSON object per PR + a trailing "averages" object.
#   --help            Print this help and exit.
#
# Requirements
# ------------
#   gh (GitHub CLI) authenticated against the target repository.
#   Run from the repository root or any subdirectory; the script detects the
#   remote repo automatically via `gh repo view`.
#
# Output (default, human-readable)
# ---------------------------------
#   PR #NNN  total=T  fix=F  rejected=R  threads=opened/resolved
#   ...
#   --- 14-day rolling averages ---
#   total_rounds: T.T  fix_rounds: F.F  rejected_rounds: R.R
#
# Output (--json)
# ---------------
#   {"pr":NNN,"total_rounds":T,"fix_rounds":F,"rejected_rounds":R,
#    "threads_opened":O,"threads_resolved":V}
#   ... (one per PR)
#   {"averages":{"total_rounds":T.T,"fix_rounds":F.F,"rejected_rounds":R.R,
#                "threads_opened":O.O,"threads_resolved":V.V}}

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
WINDOW_DAYS=14
JSON_MODE=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        printf 'Error: --window requires a positive integer\n' >&2
        exit 1
      fi
      WINDOW_DAYS="$2"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --help | -h)
      sed -n '2,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# gh auth check — emit a friendly hint if not authenticated
# ---------------------------------------------------------------------------
if ! gh auth status &>/dev/null; then
  printf 'Error: gh is not authenticated.\n' >&2
  printf 'Run: gh auth login\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve owner/repo from the current git remote
# ---------------------------------------------------------------------------
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null) || {
  printf 'Error: could not determine repository from current directory.\n' >&2
  printf 'Run from inside the git repository or set GH_REPO.\n' >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Date range — ISO-8601 cutoff for closed-since filter
# GNU date (Linux): `date -d "N days ago"`.
# BSD date (macOS): `date -v -Nd` where N is a positive integer.
# WINDOW_DAYS is validated as a positive integer above, so the expansion is
# safe. The GNU form is tried first; BSD form is the fallback.
# ---------------------------------------------------------------------------
SINCE=$(date -u -d "${WINDOW_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -v "-${WINDOW_DAYS}d" '+%Y-%m-%dT%H:%M:%SZ')

# ---------------------------------------------------------------------------
# Inline Python helpers written to temp files so they can receive piped JSON
# (combining a heredoc with pipe-stdin on the same python3 invocation is not
# valid — SC2259; separate temp files avoid the issue cleanly).
# ---------------------------------------------------------------------------
TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# fetcher.py — paginates PRs with early-exit and follows per-PR cursors for
# reviewThreads and comments so counts are never capped at 100 nodes.
cat >"$TMP_DIR/fetcher.py" <<'PYEOF'
import subprocess, sys, json

owner, repo, since = sys.argv[1], sys.argv[2], sys.argv[3]


def gql(query, *extra_args):
    result = subprocess.run(
        ['gh', 'api', 'graphql', '-f', f'query={query}'] + list(extra_args),
        stdout=subprocess.PIPE, text=True, check=True,
    )
    return json.loads(result.stdout)


PR_QUERY = '''
query($owner:String!,$repo:String!,$endCursor:String) {
  repository(owner:$owner,name:$repo) {
    pullRequests(
      states:MERGED
      orderBy:{field:UPDATED_AT,direction:DESC}
      first:50
      after:$endCursor
    ) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number closedAt updatedAt
        reviewThreads(first:100) {
          totalCount
          pageInfo { hasNextPage endCursor }
          nodes { isResolved }
        }
        comments(first:100) {
          pageInfo { hasNextPage endCursor }
          nodes { body author { login } }
        }
      }
    }
  }
}
'''

THREAD_QUERY = '''
query($owner:String!,$repo:String!,$number:Int!,$endCursor:String!) {
  repository(owner:$owner,name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100,after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { isResolved }
      }
    }
  }
}
'''

COMMENT_QUERY = '''
query($owner:String!,$repo:String!,$number:Int!,$endCursor:String!) {
  repository(owner:$owner,name:$repo) {
    pullRequest(number:$number) {
      comments(first:100,after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { body author { login } }
      }
    }
  }
}
'''

prs = []
cursor = None

while True:
    call_args = ['-f', f'owner={owner}', '-f', f'repo={repo}']
    if cursor:
        call_args += ['-f', f'endCursor={cursor}']
    data = gql(PR_QUERY, *call_args)
    page = data['data']['repository']['pullRequests']

    nodes = page['nodes']
    for pr in nodes:
        if pr['closedAt'] < since:
            continue

        # Follow reviewThreads cursor if there are more than 100 nodes.
        rt = pr['reviewThreads']
        while rt['pageInfo']['hasNextPage']:
            more = gql(THREAD_QUERY,
                       '-f', f'owner={owner}', '-f', f'repo={repo}',
                       '-F', f'number={pr["number"]}',
                       '-f', f'endCursor={rt["pageInfo"]["endCursor"]}',
                       )['data']['repository']['pullRequest']['reviewThreads']
            rt['nodes'].extend(more['nodes'])
            rt['pageInfo'] = more['pageInfo']

        # Follow comments cursor if there are more than 100 nodes.
        cm = pr['comments']
        while cm['pageInfo']['hasNextPage']:
            more = gql(COMMENT_QUERY,
                       '-f', f'owner={owner}', '-f', f'repo={repo}',
                       '-F', f'number={pr["number"]}',
                       '-f', f'endCursor={cm["pageInfo"]["endCursor"]}',
                       )['data']['repository']['pullRequest']['comments']
            cm['nodes'].extend(more['nodes'])
            cm['pageInfo'] = more['pageInfo']

        prs.append(pr)

    if not page['pageInfo']['hasNextPage']:
        break
    # Safe early-exit: ordered by updatedAt DESC; since updatedAt >= closedAt,
    # once the oldest PR on this page has updatedAt < since, all remaining
    # pages also have updatedAt < since (and therefore closedAt < since).
    if nodes and nodes[-1]['updatedAt'] < since:
        break
    cursor = page['pageInfo']['endCursor']

print(json.dumps(prs))
PYEOF

# parser.py — converts raw PR JSON to per-PR metric rows
cat >"$TMP_DIR/parser.py" <<'PYEOF'
import sys, json, re

data = json.load(sys.stdin)
results = []

REPORT_HEADER_RE = re.compile(
    r'^##\s+Resolution\s+Report(?:\s*[\u2014\-]+\s*Round)?', re.MULTILINE | re.I
)
# [*:\s]+ handles both plain text ('Fixed in this pass: 2') and the
# canonical markdown-bold form ('**Fixed in this pass**: 2').
FIXED_RE = re.compile(r'fixed in this pass[*:\s]+(\d+)', re.I)
TOTAL_RE = re.compile(r'total items found[*:\s]+(\d+)', re.I)

for pr in data:
    number = pr['number']
    threads_opened = pr['reviewThreads']['totalCount']
    threads_resolved = sum(
        1 for t in pr['reviewThreads']['nodes'] if t['isResolved']
    )

    total_rounds = 0
    fix_rounds = 0
    rejected_rounds = 0

    for comment in pr['comments']['nodes']:
        body = comment.get('body') or ''
        is_report = REPORT_HEADER_RE.search(body)
        if not is_report:
            continue

        total_rounds += 1

        fixed_match = FIXED_RE.search(body)
        total_match = TOTAL_RE.search(body)
        fixed_count = int(fixed_match.group(1)) if fixed_match else 0
        total_count = int(total_match.group(1)) if total_match else 0

        if fixed_count > 0:
            fix_rounds += 1
        elif total_count > 0:
            rejected_rounds += 1

    results.append({
        'pr': number,
        'total_rounds': total_rounds,
        'fix_rounds': fix_rounds,
        'rejected_rounds': rejected_rounds,
        'threads_opened': threads_opened,
        'threads_resolved': threads_resolved,
    })

print(json.dumps(results))
PYEOF

# averages.py — computes rolling averages from metric rows JSON
cat >"$TMP_DIR/averages.py" <<'PYEOF'
import sys, json

rows = json.load(sys.stdin)
if not rows:
    print(json.dumps({"total_rounds": 0.0, "fix_rounds": 0.0,
                      "rejected_rounds": 0.0, "threads_opened": 0.0,
                      "threads_resolved": 0.0}))
    sys.exit(0)

n = len(rows)
avgs = {k: round(sum(r[k] for r in rows) / n, 2)
        for k in ('total_rounds', 'fix_rounds', 'rejected_rounds',
                  'threads_opened', 'threads_resolved')}
print(json.dumps(avgs))
PYEOF

# ---------------------------------------------------------------------------
# Fetch merged PRs closed within the window.
# fetcher.py handles outer pagination with early-exit (stops when a full page
# has no PRs within the window) and follows per-PR cursors for reviewThreads
# and comments so no data is silently truncated at the first-100 cap.
# ---------------------------------------------------------------------------
PR_JSON=$(python3 "$TMP_DIR/fetcher.py" "${REPO%%/*}" "${REPO##*/}" "${SINCE}")

# ---------------------------------------------------------------------------
# Parse and accumulate per-PR metrics
# ---------------------------------------------------------------------------
STATS_JSON=$(printf '%s' "$PR_JSON" | python3 "$TMP_DIR/parser.py")

# ---------------------------------------------------------------------------
# Compute rolling averages
# ---------------------------------------------------------------------------
AVERAGES=$(printf '%s' "$STATS_JSON" | python3 "$TMP_DIR/averages.py")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
PR_COUNT=$(printf '%s' "$STATS_JSON" \
  | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s' "$STATS_JSON" \
    | python3 -c '
import sys, json
rows = json.load(sys.stdin)
for r in rows:
    print(json.dumps(r))
'
  printf '%s' "$AVERAGES" \
    | python3 -c '
import sys, json
avgs = json.load(sys.stdin)
print(json.dumps({"averages": avgs}))
'
else
  printf 'PR review-loop stats — last %d days (%d PRs)\n' \
    "$WINDOW_DAYS" "$PR_COUNT"
  printf '%s' "$STATS_JSON" \
    | python3 -c '
import sys, json
rows = json.load(sys.stdin)
for r in rows:
    print("PR #{pr}  total={total_rounds}  fix={fix_rounds}"
          "  rejected={rejected_rounds}"
          "  threads={threads_opened}/{threads_resolved}".format(**r))
'
  printf '\n--- %d-day rolling averages ---\n' "$WINDOW_DAYS"
  printf '%s' "$AVERAGES" \
    | python3 -c '
import sys, json
a = json.load(sys.stdin)
print("total_rounds: {total_rounds}  fix_rounds: {fix_rounds}"
      "  rejected_rounds: {rejected_rounds}"
      "  threads: {threads_opened}/{threads_resolved}".format(**a))
'
fi
