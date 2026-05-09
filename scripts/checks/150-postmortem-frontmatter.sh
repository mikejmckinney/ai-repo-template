#!/usr/bin/env bash
# scripts/checks/150-postmortem-frontmatter.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Postmortem frontmatter check (ADR-015) ---
# Every docs/postmortems/postmortem-*.md must carry the YAML frontmatter
# block introduced by ADR-015. Required keys: postmortem_number, date,
# source_repo, source_commit, stacks, generalizes, follow_up_artifact,
# mirror_status. The template file is included intentionally — its
# frontmatter is the canonical example.
echo "Checking postmortem frontmatter (ADR-015)..."

REQUIRED_PM_KEYS=(
  "postmortem_number:"
  "date:"
  "source_repo:"
  "source_commit:"
  "stacks:"
  "generalizes:"
  "follow_up_artifact:"
  "mirror_status:"
)

for pm in docs/postmortems/postmortem-*.md; do
  [[ -f "$pm" ]] || continue
  # Extract the YAML frontmatter block.
  # Invariants enforced (per ADR-015 + bot review feedback on PR #218):
  #   1. Line 1 of the file MUST be `---`. The YAML-line-1 rule
  #      (commit 9c784ae) is what makes GitHub render the styled
  #      table view; anything before the opening delimiter — blank
  #      lines, HTML comments, BOMs — breaks that rendering. We
  #      enforce it strictly here so CI catches drift, not GitHub's
  #      preview.
  #   2. The block MUST be closed by a second `---`. Without this,
  #      a missing terminator would silently consume the rest of the
  #      file as "frontmatter" and key checks could pass on body text.
  # awk exit codes: 1 = line 1 is not `---`; 2 = no closing delim.
  awk_status=0
  fm=$(awk '
        BEGIN { in_fm = 0; saw_close = 0; bailed = 0 }
        NR == 1 {
            # Strip a UTF-8 BOM if present (some Windows editors add one).
            # Without this strip, the BOM bytes would make the line not
            # match `^---$` and CI would reject a file that GitHub still
            # renders the YAML table for, producing a confusing failure.
            sub(/^\357\273\277/, "")
            if ($0 !~ /^---[[:space:]]*$/) { bailed = 1; exit 1 }
            in_fm = 1
            next
        }
        in_fm && /^---[[:space:]]*$/ { saw_close = 1; exit }
        in_fm { print }
        END {
            # awk runs END even after a body `exit N`. Skip the
            # post-processing checks if we already bailed, otherwise
            # END would overwrite the body exit code.
            if (bailed) { exit 1 }
            if (NR == 0) { exit 1 }
            if (!saw_close) { exit 2 }
        }
    ' "$pm") || awk_status=$?
  if [[ $awk_status -eq 1 ]]; then
    fail "$pm does not begin with --- on line 1 (YAML frontmatter must be at line 1 for GitHub rendering; ADR-015)"
    continue
  elif [[ $awk_status -eq 2 ]]; then
    fail "$pm is missing the closing --- of its YAML frontmatter (ADR-015)"
    continue
  elif [[ $awk_status -ne 0 ]]; then
    fail "$pm frontmatter extraction failed with awk exit $awk_status (ADR-015)"
    continue
  fi
  if [[ -z "$fm" ]]; then
    fail "$pm has an empty YAML frontmatter block (ADR-015)"
    continue
  fi
  missing=""
  for key in "${REQUIRED_PM_KEYS[@]}"; do
    # grep -E with ^ anchor + key + exactly-one-space + non-space-non-comment:
    # enforces "key at BOL followed by exactly one space and immediately
    # a real value character" (the repo style guide convention for YAML
    # key-value formatting). Rejecting '#' as the first value character
    # prevents comment-only placeholders like 'source_commit: # TODO'
    # from passing: YAML parses those as null/empty even though they
    # look non-empty to a line-based grep. The key already includes the
    # trailing colon, so this catches wrong-position, wrong-spacing, and
    # comment-only placeholder drift in one check.
    if ! grep -qE "^${key} [^[:space:]#]" <<<"$fm"; then
      missing="$missing $key"
    fi
  done
  if [[ -n "$missing" ]]; then
    fail "$pm frontmatter missing keys:$missing"
  else
    pass "$pm has all required frontmatter keys"
  fi
  # Validate source_commit looks like a commit SHA (7-40 hex chars).
  # Values like 'main' or 'release/latest' are mutable branch refs and
  # weaken incident provenance (ADR-015 requires immutable SHA).
  # The template file legitimately holds the placeholder string
  # '<sha-at-time-of-incident>' — skip the SHA format check for it.
  if [[ "$pm" != *postmortem-template* ]]; then
    sc=$(grep -E '^source_commit: ' <<<"$fm" | sed 's/^source_commit: //' | tr -d '[:space:]')
    if [[ -z "$sc" ]]; then
      : # already caught by the required-keys loop above
    elif [[ ! "$sc" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
      fail "$pm source_commit '$sc' does not look like a commit SHA (need 7-40 hex chars; ADR-015)"
    else
      pass "$pm source_commit looks like a commit SHA"
    fi
  fi
  # Validate generalizes and follow_up_artifact canonical values (ADR-015).
  # These checks apply to all files including the template (which has
  # valid canonical defaults: generalizes: No, follow_up_artifact: none).
  gen=$(grep -E '^generalizes: ' <<<"$fm" | sed 's/^generalizes: //' | tr -d '[:space:]')
  if [[ "$gen" =~ ^(Yes|No|Unclear)$ ]]; then
    pass "$pm generalizes value is valid"
  else
    fail "$pm generalizes '$gen' is not one of Yes | No | Unclear (ADR-015)"
  fi
  fua=$(grep -E '^follow_up_artifact: ' <<<"$fm" | sed 's/^follow_up_artifact: //' | tr -d '[:space:]')
  if [[ "$fua" =~ ^(ADR-[0-9]+|issue-[0-9]+|PR-[0-9]+|none)$ ]]; then
    pass "$pm follow_up_artifact value matches canonical schema"
  else
    fail "$pm follow_up_artifact '$fua' does not match canonical schema ADR-NNN|issue-NNN|PR-NNN|none (ADR-015)"
  fi
  # Cross-field rule: follow_up_artifact must not be 'none' when
  # generalizes is Yes or Unclear (capture-postmortem.md Phase 4 /
  # mirror-postmortem.md Phase 1 policy).
  if [[ "$gen" =~ ^(Yes|Unclear)$ ]] && [[ "$fua" == "none" ]]; then
    fail "$pm follow_up_artifact must not be 'none' when generalizes is '$gen' (ADR-015)"
  fi
done

echo ""
