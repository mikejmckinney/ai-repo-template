#!/usr/bin/env bash
# Create or append the weekly umbrella issue from weekly-review.json.
# Usage: create-umbrella-issue.sh <weekly-review.json>
set -euo pipefail

usage() {
  echo "Usage: create-umbrella-issue.sh <weekly-review.json>" >&2
  exit 2
}

WEEKLY_JSON="${1:-}"
[[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$REPO_ROOT/scripts/workflows/weekly-review/validate-weekly-review-batch.py" "$WEEKLY_JSON"

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
RUN_WEEK="$(jq -r .run_week "$WEEKLY_JSON")"
RUN_DATE="$(jq -r .run_date "$WEEKLY_JSON")"
HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
MARKER="<!-- weekly-review:${RUN_WEEK} -->"
FIX_PR_LINK="(pending — fix job)"

FINDINGS_COUNT="$(python3 "$REPO_ROOT/scripts/workflows/weekly-review/count-weekly-findings.py" "$WEEKLY_JSON")"
if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
  echo "Zero findings in weekly review; skipping umbrella issue"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

python3 - "$WEEKLY_JSON" "$WORKDIR/rows.txt" <<'PY'
import json
from pathlib import Path
import sys

data = json.loads(Path(sys.argv[1]).read_text())
rows = []
for f in data.get("findings") or []:
    scope = f.get("scope") or ("repo" if int(f.get("pr") or 0) == 0 else f"#{f['pr']}")
    title = str(f.get("title", "")).replace("|", "/")
    rows.append(
        f"| {scope} | {f['category']} | `{f['dedupe_key']}` | {f.get('severity') or 'medium'} | {title} | Review in draft fix PR |"
    )
Path(sys.argv[2]).write_text("\n".join(rows) + ("\n" if rows else ""))
PY

find_issue() {
  bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK" 2>/dev/null || true
}

append_to_issue() {
  local issue_num="$1"
  local body merged
  body="$(gh issue view "$issue_num" -R "$REPO" --json body --jq .body)"
  grep -Fq "$MARKER" <<<"$body" || {
    echo "::error::Issue #${issue_num} missing weekly marker"
    exit 1
  }

  new_rows=""
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    key="$(sed -n 's/.*`\([^`]*\)`.*/\1/p' <<<"$row")"
    [[ -z "$key" ]] && continue
    if grep -Fq "\`${key}\`" <<<"$body"; then
      echo "Skip append (exists): ${key}" >&2
      continue
    fi
    new_rows+="${row}"$'\n'
  done <"$WORKDIR/rows.txt"

  if [[ -z "${new_rows//[$'\t\r\n ']/}" ]]; then
    echo "No new rows to append to issue #${issue_num}" >&2
    return 0
  fi

  printf '%s' "$new_rows" >"$WORKDIR/new-rows.txt"
  printf '%s' "$body" >"$WORKDIR/existing-body.md"
  merged="$(
    python3 - "$WORKDIR/existing-body.md" "$WORKDIR/new-rows.txt" <<'PY'
import sys

body = open(sys.argv[1], encoding="utf-8").read()
new_rows = [ln for ln in open(sys.argv[2], encoding="utf-8").read().splitlines() if ln.strip()]
if "## Meta" in body:
    head, tail = body.split("## Meta", 1)
    print(head.rstrip() + "\n" + "\n".join(new_rows) + "\n\n## Meta" + tail)
else:
    print(body.rstrip() + "\n" + "\n".join(new_rows) + "\n")
PY
  )"
  gh issue edit "$issue_num" -R "$REPO" --body "$merged"
  echo "Appended findings to umbrella issue #${issue_num}" >&2
}

create_new_issue() {
  local title body_file rows issue_url issue_num
  title="Weekly repo review: ${RUN_WEEK} (main @ ${HEAD_SHA:0:7})"
  body_file="$WORKDIR/umbrella.md"
  rows="$(cat "$WORKDIR/rows.txt")"
  cp "$REPO_ROOT/.github/templates/weekly-review-umbrella.md" "$body_file"
  sed -i \
    -e "s/{{RUN_WEEK}}/${RUN_WEEK}/g" \
    -e "s/{{RUN_DATE}}/${RUN_DATE}/g" \
    -e "s/{{HEAD_SHA}}/${HEAD_SHA}/g" \
    -e "s|{{REPO}}|${REPO}|g" \
    -e "s|{{FIX_PR_LINK}}|${FIX_PR_LINK}|g" \
    "$body_file"
  python3 - "$body_file" "$rows" <<PY
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text().replace(
    "{{FINDING_ROWS}}",
    sys.argv[2].rstrip() + ("\n" if sys.argv[2].strip() else ""),
)
p.write_text(text)
PY
  issue_url="$(gh issue create -R "$REPO" --title "$title" --body-file "$body_file")"
  issue_num="${issue_url##*/}"
  if gh issue edit "$issue_num" -R "$REPO" --add-label agent-suggested 2>/dev/null; then
    echo "Created umbrella issue #${issue_num} (agent-suggested)" >&2
  else
    echo "::notice::Umbrella issue #${issue_num} created without agent-suggested label (missing label or permissions)" >&2
  fi
  echo "$issue_num"
}

normalize_issue_num() {
  tr -d '[:space:]' <<<"${1:-}"
}

UMBRELLA_ISSUE="$(normalize_issue_num "$(find_issue)")"
if [[ -n "$UMBRELLA_ISSUE" ]]; then
  append_to_issue "$UMBRELLA_ISSUE"
else
  UMBRELLA_ISSUE="$(normalize_issue_num "$(create_new_issue)")"
fi

[[ "$UMBRELLA_ISSUE" =~ ^[0-9]+$ ]] || {
  echo "::error::Umbrella issue number invalid after create/find: '${UMBRELLA_ISSUE}'" >&2
  exit 1
}

bash "$SCRIPT_DIR/write-umbrella-issue-ref.sh" "$WEEKLY_JSON" "$UMBRELLA_ISSUE"
bash "$SCRIPT_DIR/post-weekly-review-json-comment.sh" "$WEEKLY_JSON" "$UMBRELLA_ISSUE"

echo "Umbrella issue step complete for ${RUN_WEEK} (#${UMBRELLA_ISSUE})"
