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
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"
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

python3 "$SCRIPT_DIR/render-umbrella-findings.py" "$WEEKLY_JSON" "$REPO" "$HEAD_SHA" "$WORKDIR/findings.md"
python3 "$SCRIPT_DIR/render-umbrella-findings.py" \
  "$WEEKLY_JSON" "$REPO" "$HEAD_SHA" "$WORKDIR/triage-rows.md" --summary

find_issue() {
  bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK" 2>/dev/null || true
}

append_to_issue() {
  local issue_num="$1"
  local body body_with_provenance index key marker block_file row_file
  body="$(gh issue view "$issue_num" -R "$REPO" --json body --jq .body)"
  umbrella_require_marker "$body" "$MARKER" "$issue_num"
  printf '%s' "$body" >"$WORKDIR/existing-body.md"
  python3 "$SCRIPT_DIR/render-provider-provenance.py" \
    "$WEEKLY_JSON" --merge "$WORKDIR/existing-body.md" \
    >"$WORKDIR/existing-body-with-provenance.md"
  body_with_provenance="$(cat "$WORKDIR/existing-body-with-provenance.md")"

  : >"$WORKDIR/new-blocks.md"
  : >"$WORKDIR/new-rows.md"
  index=0
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    marker="<!-- weekly-review:finding:${key} -->"
    if grep -Fq "$marker" <<<"$body"; then
      echo "Skip append (exists): ${key}" >&2
      continue
    fi
    block_file="$WORKDIR/block-${index}.md"
    row_file="$WORKDIR/row-${index}.md"
    python3 "$SCRIPT_DIR/render-umbrella-findings.py" "$WEEKLY_JSON" "$REPO" "$HEAD_SHA" "$block_file" "$key"
    python3 "$SCRIPT_DIR/render-umbrella-findings.py" \
      "$WEEKLY_JSON" "$REPO" "$HEAD_SHA" "$row_file" "$key" --summary
    [[ -s "$block_file" ]] || continue
    cat "$block_file" >>"$WORKDIR/new-blocks.md"
    printf '\n' >>"$WORKDIR/new-blocks.md"
    cat "$row_file" >>"$WORKDIR/new-rows.md"
    index=$((index + 1))
  done < <(jq -r '.findings[].dedupe_key' "$WEEKLY_JSON")

  if [[ ! -s "$WORKDIR/new-blocks.md" ]]; then
    if [[ "$body_with_provenance" != "$body" ]]; then
      umbrella_edit_issue_body "$REPO" "$issue_num" "$WORKDIR/existing-body-with-provenance.md"
    fi
    echo "No new findings to append to issue #${issue_num}" >&2
    return 0
  fi

  python3 "$SCRIPT_DIR/merge-umbrella-content.py" \
    "$WORKDIR/existing-body-with-provenance.md" "$WORKDIR/new-rows.md" \
    "$WORKDIR/new-blocks.md" "$WORKDIR/merged-body.md"
  umbrella_edit_issue_body "$REPO" "$issue_num" "$WORKDIR/merged-body.md"
  echo "Appended findings to umbrella issue #${issue_num}" >&2
}

create_new_issue() {
  local title body_file findings_md triage_rows provenance issue_num
  title="Repository health review: ${RUN_WEEK} (main @ ${HEAD_SHA:0:7})"
  body_file="$WORKDIR/umbrella.md"
  findings_md="$(cat "$WORKDIR/findings.md")"
  triage_rows="$(cat "$WORKDIR/triage-rows.md")"
  provenance="$(python3 "$SCRIPT_DIR/render-provider-provenance.py" "$WEEKLY_JSON")"
  cp "$REPO_ROOT/.github/templates/weekly-review-umbrella.md" "$body_file"
  sed -i \
    -e "s/{{RUN_WEEK}}/${RUN_WEEK}/g" \
    -e "s/{{RUN_DATE}}/${RUN_DATE}/g" \
    -e "s/{{HEAD_SHA}}/${HEAD_SHA}/g" \
    -e "s|{{REPO}}|${REPO}|g" \
    -e "s|{{FIX_PR_LINK}}|${FIX_PR_LINK}|g" \
    "$body_file"
  python3 - "$body_file" "$triage_rows" "$findings_md" "$provenance" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text()
for placeholder, value in (
    ("{{TRIAGE_ROWS}}", sys.argv[2]),
    ("{{FINDING_BLOCKS}}", sys.argv[3]),
    ("{{PROVENANCE}}", sys.argv[4]),
):
    text = text.replace(
        placeholder,
        value.rstrip() + ("\n" if value.strip() else ""),
    )
p.write_text(text)
PY
  issue_num="$(umbrella_create_issue "$REPO" "$title" "$body_file" agent-suggested)"
  printf '%s' "$issue_num" >"$WORKDIR/issue-num.txt"
}

normalize_issue_num() {
  tr -d '[:space:]' <<<"${1:-}"
}

UMBRELLA_ISSUE="$(normalize_issue_num "$(find_issue)")"
if [[ -n "$UMBRELLA_ISSUE" ]]; then
  append_to_issue "$UMBRELLA_ISSUE"
else
  create_new_issue
  UMBRELLA_ISSUE="$(normalize_issue_num "$(cat "$WORKDIR/issue-num.txt")")"
fi

[[ "$UMBRELLA_ISSUE" =~ ^[0-9]+$ ]] || {
  echo "::error::Umbrella issue number invalid after create/find: '${UMBRELLA_ISSUE}'" >&2
  exit 1
}

bash "$SCRIPT_DIR/write-umbrella-issue-ref.sh" "$WEEKLY_JSON" "$UMBRELLA_ISSUE"
bash "$SCRIPT_DIR/post-weekly-review-json-comment.sh" "$WEEKLY_JSON" "$UMBRELLA_ISSUE"

echo "Umbrella issue step complete for ${RUN_WEEK} (#${UMBRELLA_ISSUE})"
