#!/usr/bin/env bash
# Create or append the daily umbrella issue from daily-retro.json.
# Usage: create-umbrella-issue.sh <daily-retro.json>
set -euo pipefail

usage() {
  echo "Usage: create-umbrella-issue.sh <daily-retro.json>" >&2
  exit 2
}

DAILY_JSON="${1:-}"
[[ -n "$DAILY_JSON" && -f "$DAILY_JSON" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py" "$DAILY_JSON"

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
RUN_DATE="$(jq -r .run_date "$DAILY_JSON")"
WINDOW_HOURS="$(jq -r '.window_hours // 24' "$DAILY_JSON")"
MARKER="<!-- postmerge-retro:daily:${RUN_DATE} -->"
WINDOW_END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FIX_PR_LINK="(pending — fix job)"

FINDINGS_COUNT="$(python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/count-daily-retro-findings.py" "$DAILY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings in daily retro; skipping umbrella issue"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

python3 - <<'PY' "$DAILY_JSON" "$WORKDIR/rows.txt"
import json
from pathlib import Path
import sys

data = json.loads(Path(sys.argv[1]).read_text())
rows = []
for f in data.get("findings") or []:
    title = str(f.get("title", "")).replace("|", "/")
    rows.append(
        f"| #{f['pr']} | {f['category']} | `{f['dedupe_key']}` | {f.get('severity') or 'medium'} | {title} | Review in draft fix PR |"
    )
Path(sys.argv[2]).write_text("\n".join(rows) + ("\n" if rows else ""))
PY

PR_LIST="$(jq -r '[.prs[] | "#" + (.|tostring)] | join(", ")' "$DAILY_JSON")"

find_issue() {
  gh search issues "postmerge-retro:daily:${RUN_DATE}" --repo "$REPO" --json number --limit 1 --jq '.[0].number // empty' 2>/dev/null || true
}

append_to_issue() {
  local issue_num="$1"
  local body merged
  body="$(gh issue view "$issue_num" -R "$REPO" --json body --jq .body)"
  grep -Fq "$MARKER" <<<"$body" || {
    echo "::error::Issue #${issue_num} missing daily marker"
    exit 1
  }

  new_rows=""
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    key="$(sed -n 's/.*`\([^`]*\)`.*/\1/p' <<<"$row")"
    [[ -z "$key" ]] && continue
    if grep -Fq "\`${key}\`" <<<"$body"; then
      echo "Skip append (exists): ${key}"
      continue
    fi
    new_rows+="${row}"$'\n'
  done <"$WORKDIR/rows.txt"

  if [[ -z "${new_rows//[$'\t\r\n ']}" ]]; then
    echo "No new rows to append to issue #${issue_num}"
    return 0
  fi

  printf '%s' "$new_rows" >"$WORKDIR/new-rows.txt"
  merged="$(python3 - "$body" "$WORKDIR/new-rows.txt" <<'PY'
import sys

body = open(sys.argv[1]).read()
new_rows = [ln for ln in open(sys.argv[2]).read().splitlines() if ln.strip()]
if "## Meta" in body:
    head, tail = body.split("## Meta", 1)
    print(head.rstrip() + "\n" + "\n".join(new_rows) + "\n\n## Meta" + tail)
else:
    print(body.rstrip() + "\n" + "\n".join(new_rows) + "\n")
PY
)"
  gh issue edit "$issue_num" -R "$REPO" --body "$merged"
  echo "Appended findings to umbrella issue #${issue_num}"
}

create_new_issue() {
  local title body_file rows
  title="Post-merge retro daily: ${RUN_DATE} (${PR_LIST})"
  body_file="$WORKDIR/umbrella.md"
  rows="$(cat "$WORKDIR/rows.txt")"
  cp "$REPO_ROOT/.github/templates/postmerge-retro-umbrella.md" "$body_file"
  sed -i \
    -e "s/{{RUN_DATE}}/${RUN_DATE}/g" \
    -e "s/{{WINDOW_HOURS}}/${WINDOW_HOURS}/g" \
    -e "s/{{WINDOW_END}}/${WINDOW_END}/g" \
    -e "s/{{PR_LIST}}/${PR_LIST}/g" \
    -e "s|{{REPO}}|${REPO}|g" \
    -e "s|{{FIX_PR_LINK}}|${FIX_PR_LINK}|g" \
    "$body_file"
  python3 - <<PY "$body_file" "$rows"
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text().replace(
    "{{FINDING_ROWS}}",
    sys.argv[2].rstrip() + ("\n" if sys.argv[2].strip() else ""),
)
p.write_text(text)
PY
  gh issue create -R "$REPO" --title "$title" --body-file "$body_file" --label agent-suggested
}

EXISTING_ISSUE="$(find_issue)"
if [[ -n "$EXISTING_ISSUE" ]]; then
  append_to_issue "$EXISTING_ISSUE"
else
  create_new_issue
fi

echo "Umbrella issue step complete for ${RUN_DATE}"
