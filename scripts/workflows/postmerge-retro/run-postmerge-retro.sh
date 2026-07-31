#!/usr/bin/env bash
# scripts/workflows/postmerge-retro/run-postmerge-retro.sh — post-merge retro dispatch.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
CREATE_ISSUES="${2:-${CREATE_ISSUES:-true}}"

usage() {
  echo "Usage: run-postmerge-retro.sh <pr-number> [create_issues=true|false]" >&2
  exit 2
}

[[ -n "$PR" ]] || usage

parse_positive_int() {
  local name="$1" default="$2" raw="${3:-}"
  if [[ -z "$raw" ]]; then
    echo "$default"
    return
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ $((10#$raw)) -gt 0 ]]; then
    echo "$((10#$raw))"
    return
  fi
  echo "::warning::Invalid ${name}=${raw}; using default ${default}" >&2
  echo "$default"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
WORK_ROOT="$REPO_ROOT/.artifacts/postmerge-retro/work"
ARTIFACT_DIR="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${PR}"
mkdir -p "$WORK_ROOT"
WORKDIR="$(mktemp -d "$WORK_ROOT/pr-${PR}.XXXXXX")"
mkdir -p "$ARTIFACT_DIR"
rm -f "$ARTIFACT_DIR"/{retro.json,evidence-coverage.json,llm-output.txt,pr.json,changed-files.txt,retrieval-trace.json,provider-metadata.json}

persist_artifacts() {
  local rc=$?
  mkdir -p "$ARTIFACT_DIR"
  for name in retro.json evidence-coverage.json llm-output.txt pr.json changed-files.txt retrieval-trace.json provider-metadata.json; do
    [[ -f "$WORKDIR/$name" ]] && cp -f "$WORKDIR/$name" "$ARTIFACT_DIR/$name"
  done
  rm -rf "$WORKDIR"
  return "$rc"
}
trap persist_artifacts EXIT

DEFAULT_DIFF_LIMIT=300000
diff_limit="$(parse_positive_int POSTMERGE_RETRO_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${POSTMERGE_RETRO_DIFF_LIMIT:-}")"
DEFAULT_PROVIDER_TIMEOUT_SECONDS=900
provider_timeout_seconds="$(parse_positive_int POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS "$DEFAULT_PROVIDER_TIMEOUT_SECONDS" "${POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS:-}")"

# shellcheck source=../lib/postmerge-provider-timeout.sh
source "$LIB_DIR/postmerge-provider-timeout.sh"

bash "$SCRIPT_DIR/collect-postmerge-evidence.sh" "$PR" "$WORKDIR"

COVERAGE_JSON="$WORKDIR/evidence-coverage.json"
python3 "$SCRIPT_DIR/compute-evidence-coverage.py" "$WORKDIR" \
  --pr "$PR" \
  --repo-root "$REPO_ROOT" \
  --diff-limit "$diff_limit" \
  --head-file-cap 12000 \
  --head-total-cap 120000 \
  --warn \
  -o "$COVERAGE_JSON"

merged_at="$(jq -r '.merged_at // ""' "$WORKDIR/pr.json")"
if [[ -z "$merged_at" || "$merged_at" == "null" ]]; then
  echo "::error::PR #${PR} is not merged (merged_at=${merged_at})"
  exit 1
fi

MERGE_SHA="$(jq -r '.merge_commit_sha // .head.sha' "$WORKDIR/pr.json")"
jq -r '.body // ""' "$WORKDIR/pr.json" >"$WORKDIR/pr-body.md"

run_bounded_pass() {
  local provider="$1"
  if [[ "$provider" == "cursor" ]]; then
    run_postmerge_provider_with_timeout "$provider_timeout_seconds" cursor bounded \
      bash "$SCRIPT_DIR/run-postmerge-retro-bounded.sh" \
      "$PR" "$WORKDIR" "$llm_raw" "$COVERAGE_JSON" "$provider"
    return
  fi
  bash "$SCRIPT_DIR/run-postmerge-retro-bounded.sh" \
    "$PR" "$WORKDIR" "$llm_raw" "$COVERAGE_JSON" "$provider"
}

llm_raw="$WORKDIR/llm-output.txt"
provider_used=""
would_truncate="$(jq -r '.would_truncate // false' "$COVERAGE_JSON")"
prompt_file="$WORKDIR/prompt.md"
provider_metadata_file="$WORKDIR/provider-metadata.json"
normalized_provenance_file="$WORKDIR/provider-provenance.json"
export ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file"

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
init_advisory_provider_credentials
mapfile -t provider_candidates < <(list_advisory_providers retro)
if [[ ${#provider_candidates[@]} -eq 0 ]]; then
  echo "::error::No post-merge retro provider configured." >&2
  exit 1
fi

record_provider_attempt() {
  local provider="$1" status="$2" route="$3"
  python3 - "$COVERAGE_JSON" "$provider" "$status" "$route" "$normalized_provenance_file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
provider, status, route, provenance_path = sys.argv[2:]
record = json.loads(path.read_text(encoding="utf-8"))
record.setdefault("provider_attempts", []).append(
    {"provider": provider, "status": status, "evidence_route": route}
)
if status == "success":
    provenance = json.loads(Path(provenance_path).read_text(encoding="utf-8"))
    record["evidence_route"] = route
    context = record.setdefault("routing_context", {})
    context["provider_resolved"] = provenance["provider"]
    context["provenance"] = provenance
path.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

normalize_provider_metadata() {
  python3 "$LIB_DIR/provider-provenance.py" normalize \
    "$provider_metadata_file" >"$normalized_provenance_file"
}

run_full_evidence_provider() {
  local provider="$1"
  bash "$SCRIPT_DIR/assemble-retro-prompt.sh" "$PR" "$WORKDIR" full-evidence "$prompt_file"
  case "$provider" in
    opencode)
      OPENCODE_OUTPUT_SCHEMA="$REPO_ROOT/.github/schemas/postmerge-retro.schema.json" \
        OPENCODE_RETRIEVAL_TRACE_FILE="$WORKDIR/retrieval-trace.json" \
        invoke_advisory_llm \
        "$prompt_file" "$llm_raw" opencode "$REPO_ROOT/scripts/workflows/advisory-review" \
        "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
      ;;
    cursor)
      run_postmerge_provider_with_timeout "$provider_timeout_seconds" cursor full-evidence \
        "$LIB_DIR/run-with-provider-credentials.sh" cursor \
        env CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-cursor-grok-4.5-medium}}" \
        node "$SCRIPT_DIR/run-postmerge-retro-full-cursor.mjs" "$prompt_file" "$llm_raw"
      ;;
    gemini)
      [[ "$(jq -r '.routing_context.antigravity_available // false' "$COVERAGE_JSON")" == "true" ]] || return 1
      python3 "$SCRIPT_DIR/run-postmerge-retro-antigravity.py" \
        "$REPO_ROOT" "$WORKDIR" "$prompt_file" "$llm_raw"
      ;;
    *)
      return 1
      ;;
  esac
}

provider_succeeded=false
retro_json="$WORKDIR/retro.json"
candidate_json="$WORKDIR/retro-candidate.json"

validate_provider_output() {
  local -a validation_args=()
  rm -f "$candidate_json"
  if [[ "$route" == full-evidence-* ]]; then
    validation_args+=(--require-evidence-complete)
  fi
  python3 "$SCRIPT_DIR/extract-retro-json.py" "$llm_raw" "$PR" "$candidate_json" \
    && python3 "$SCRIPT_DIR/validate-postmerge-retro.py" "${validation_args[@]}" "$candidate_json" \
    && {
      [[ "$provider" != "opencode" || "$route" != full-evidence-* ]] \
        || python3 "$SCRIPT_DIR/validate-opencode-retrieval.py" \
          "$WORKDIR/retrieval-trace.json" "$WORKDIR" "$REPO_ROOT"
    }
}

for provider in "${provider_candidates[@]}"; do
  rm -f "$llm_raw" "$WORKDIR/retrieval-trace.json" \
    "$provider_metadata_file" "$normalized_provenance_file"
  if [[ "$would_truncate" == "true" ]]; then
    case "$provider" in
      opencode) route=full-evidence-opencode ;;
      cursor) route=full-evidence-cursor ;;
      gemini) route=full-evidence-antigravity ;;
      *) route=bounded-fallback ;;
    esac
    if run_full_evidence_provider "$provider" \
      && validate_provider_output \
      && normalize_provider_metadata; then
      provider_succeeded=true
    fi
  else
    route=bounded
    if run_bounded_pass "$provider" \
      && validate_provider_output \
      && normalize_provider_metadata; then
      provider_succeeded=true
    fi
  fi

  if [[ "$provider_succeeded" == "true" ]]; then
    provider_used="$(jq -r .provider "$normalized_provenance_file")"
    cp -f "$candidate_json" "$retro_json"
    record_provider_attempt "$provider_used" success "$route"
    break
  fi
  record_provider_attempt "$provider" failed "$route"
  echo "::warning::Post-merge retro provider ${provider} failed for PR #${PR}; trying next available provider" >&2
done

if [[ "$provider_succeeded" != "true" ]]; then
  echo "::error::Post-merge retro provider cascade exhausted for PR #${PR}" >&2
  exit 1
fi

jq --arg sha "$MERGE_SHA" '. + {merge_commit_sha: $sha}' "$retro_json" >"$WORKDIR/retro-with-sha.json"
mv "$WORKDIR/retro-with-sha.json" "$retro_json"
python3 "$SCRIPT_DIR/validate-postmerge-retro.py" --allow-derived-priority "$retro_json"

final_route="$(jq -r '.evidence_route // "bounded"' "$COVERAGE_JSON")"
cp -f "$retro_json" "$WORKDIR/retro.json.final"
echo "Post-merge retro JSON written for PR #${PR} route=${final_route} provider=${provider_used}"

if [[ "$CREATE_ISSUES" == "true" || "$CREATE_ISSUES" == "1" ]]; then
  bash "$SCRIPT_DIR/postmerge-retro-create-issues.sh" "$retro_json"
else
  echo "CREATE_ISSUES=${CREATE_ISSUES}; skipping issue creation"
  cat "$retro_json"
fi

echo "Post-merge retrospective complete for PR #${PR} @ merge ${MERGE_SHA} (route=${final_route})"
