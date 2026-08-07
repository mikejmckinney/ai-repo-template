#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/sandbox-candidate.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sandbox-candidate-test.XXXXXX")"
  SEED="$TEST_ROOT/seed"
  UPSTREAM="$TEST_ROOT/project.git"
  SANDBOX="$TEST_ROOT/project-sandbox.git"
  WORKTREE="$TEST_ROOT/worktree"

  git init -q -b main "$SEED"
  git -C "$SEED" config user.name "Sandbox Candidate Test"
  git -C "$SEED" config user.email "sandbox-candidate@example.invalid"
  printf 'baseline\n' >"$SEED/state.txt"
  git -C "$SEED" add state.txt
  git -C "$SEED" -c commit.gpgsign=false commit -q -m baseline

  git clone -q --bare "$SEED" "$UPSTREAM"
  git clone -q "$UPSTREAM" "$WORKTREE"
  git clone -q --bare "$SEED" "$SANDBOX"
  git -C "$WORKTREE" config user.name "Sandbox Candidate Test"
  git -C "$WORKTREE" config user.email "sandbox-candidate@example.invalid"
  git -C "$WORKTREE" remote add sandbox "$SANDBOX"

  BASELINE="$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)"
  git -C "$WORKTREE" switch -q -c feature/candidate
  printf 'candidate\n' >"$WORKTREE/state.txt"
  git -C "$WORKTREE" add state.txt
  git -C "$WORKTREE" -c commit.gpgsign=false commit -q -m candidate
  CANDIDATE="$(git -C "$WORKTREE" rev-parse HEAD)"
  CANDIDATE_REF="refs/heads/feature/candidate"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

stage_candidate() {
  git -C "$WORKTREE" push -q origin "$CANDIDATE_REF"
  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote sandbox --candidate "$CANDIDATE"
  [ "$status" -eq 0 ]
  STAGE_JSON="$output"
  BACKUP_REF="$(jq -r .backupRef <<<"$STAGE_JSON")"
}

@test "stage refuses a candidate that is not the current upstream branch tip" {
  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote sandbox --candidate "$CANDIDATE"

  [ "$status" -eq 2 ]
  [[ "$stderr" == *"candidate is not the upstream branch tip"* ]]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$BASELINE" ]
}

@test "stage publishes the exact candidate and a recoverable baseline ref" {
  stage_candidate

  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$CANDIDATE" ]
  [ "$(git --git-dir="$SANDBOX" rev-parse "$BACKUP_REF")" = "$BASELINE" ]
  [ "$(jq -r .candidate <<<"$STAGE_JSON")" = "$CANDIDATE" ]
  [ "$(jq -r .baseline <<<"$STAGE_JSON")" = "$BASELINE" ]
  [ "$(jq -r .sourceRef <<<"$STAGE_JSON")" = "$CANDIDATE_REF" ]
  [ "$(jq -r .state <<<"$STAGE_JSON")" = staged ]
}

@test "stage refuses the upstream origin remote" {
  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote origin --candidate "$CANDIDATE"

  [ "$status" -eq 2 ]
  [[ "$stderr" == *"refusing upstream remote"* ]]
  [ "$(git --git-dir="$UPSTREAM" rev-parse refs/heads/main)" = "$BASELINE" ]
}

@test "stage refuses a remote that is not the upstream sandbox sibling" {
  OTHER="$TEST_ROOT/project-staging.git"
  git clone -q --bare "$SEED" "$OTHER"
  git -C "$WORKTREE" remote add staging "$OTHER"

  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote staging --candidate "$CANDIDATE"

  [ "$status" -eq 2 ]
  [[ "$stderr" == *"not the sandbox sibling"* ]]
  [ "$(git --git-dir="$OTHER" rev-parse refs/heads/main)" = "$BASELINE" ]
}

@test "stage refuses a sandbox remote with an upstream push destination" {
  git -C "$WORKTREE" push -q origin "$CANDIDATE_REF"
  git -C "$WORKTREE" remote set-url --add --push sandbox "$UPSTREAM"

  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote sandbox --candidate "$CANDIDATE"

  [ "$status" -eq 2 ]
  [[ "$stderr" == *"push destination is not the sandbox sibling"* ]]
  [ "$(git --git-dir="$UPSTREAM" rev-parse refs/heads/main)" = "$BASELINE" ]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$BASELINE" ]
}

@test "stage refuses a same-named sandbox under another owner" {
  OTHER_OWNER="$TEST_ROOT/other"
  mkdir "$OTHER_OWNER"
  OTHER="$OTHER_OWNER/project-sandbox.git"
  git clone -q --bare "$SEED" "$OTHER"
  git -C "$WORKTREE" remote add lookalike "$OTHER"
  git -C "$WORKTREE" push -q origin "$CANDIDATE_REF"

  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote lookalike --candidate "$CANDIDATE"

  [ "$status" -eq 2 ]
  [[ "$stderr" == *"not the sandbox sibling"* ]]
  [ "$(git --git-dir="$OTHER" rev-parse refs/heads/main)" = "$BASELINE" ]
}

@test "stage rejects a stale lease when sandbox main changes during the push" {
  git -C "$WORKTREE" push -q origin "$CANDIDATE_REF"
  printf 'drift\n' >"$WORKTREE/state.txt"
  git -C "$WORKTREE" add state.txt
  git -C "$WORKTREE" -c commit.gpgsign=false commit -q -m drift
  DRIFT="$(git -C "$WORKTREE" rev-parse HEAD)"
  git -C "$WORKTREE" push -q sandbox "$DRIFT:refs/heads/drift-source"
  git -C "$WORKTREE" push -q sandbox :refs/heads/drift-source
  HOOK_COUNTER="$TEST_ROOT/pre-push-count"
  HOOK_DIR="$TEST_ROOT/hooks"
  mkdir "$HOOK_DIR"
  git -C "$WORKTREE" config core.hooksPath "$HOOK_DIR"
  HOOK="$HOOK_DIR/pre-push"
  cat >"$HOOK" <<EOF
#!/usr/bin/env bash
count=0
[[ ! -f "$HOOK_COUNTER" ]] || count=\$(cat "$HOOK_COUNTER")
count=\$((count + 1))
printf '%s\n' "\$count" >"$HOOK_COUNTER"
if [[ "\$count" -eq 2 ]]; then
  git --git-dir="$SANDBOX" update-ref refs/heads/main "$DRIFT"
fi
EOF
  chmod +x "$HOOK"

  run --separate-stderr bash "$SCRIPT" stage \
    --repo "$WORKTREE" --remote sandbox --candidate "$CANDIDATE"

  [ "$status" -eq 3 ]
  [[ "$stderr" == *"sandbox main changed before candidate staging"* ]]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$DRIFT" ]
}

@test "status distinguishes staged and restored sandbox main" {
  stage_candidate

  run bash "$SCRIPT" status --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 0 ]
  [ "$(jq -r .state <<<"$output")" = staged ]

  run bash "$SCRIPT" restore --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 0 ]

  run bash "$SCRIPT" status --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 0 ]
  [ "$(jq -r .state <<<"$output")" = restored ]
}

@test "restore rejects drift instead of overwriting a newer sandbox main" {
  stage_candidate
  printf 'drift\n' >"$WORKTREE/state.txt"
  git -C "$WORKTREE" add state.txt
  git -C "$WORKTREE" -c commit.gpgsign=false commit -q -m drift
  DRIFT="$(git -C "$WORKTREE" rev-parse HEAD)"
  git -C "$WORKTREE" push -q --force sandbox "$DRIFT:refs/heads/main"

  run --separate-stderr bash "$SCRIPT" restore --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"

  [ "$status" -eq 3 ]
  [[ "$stderr" == *"sandbox main drifted"* ]]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$DRIFT" ]
}

@test "restore uses the saved baseline and retains evidence until cleanup" {
  stage_candidate

  run bash "$SCRIPT" restore --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"

  [ "$status" -eq 0 ]
  [ "$(jq -r .state <<<"$output")" = restored ]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$BASELINE" ]
  [ "$(git --git-dir="$SANDBOX" rev-parse "$BACKUP_REF")" = "$BASELINE" ]
}

@test "cleanup deletes only the verified backup after restoration" {
  stage_candidate

  run --separate-stderr bash "$SCRIPT" cleanup --repo "$WORKTREE" --remote sandbox \
    --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"restore sandbox main before cleanup"* ]]

  run bash "$SCRIPT" restore --repo "$WORKTREE" --remote sandbox \
    --candidate "$CANDIDATE" --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 0 ]

  run bash "$SCRIPT" cleanup --repo "$WORKTREE" --remote sandbox \
    --baseline "$BASELINE" --backup-ref "$BACKUP_REF"
  [ "$status" -eq 0 ]
  [ "$(jq -r .state <<<"$output")" = cleaned ]
  run git --git-dir="$SANDBOX" show-ref --verify --quiet "$BACKUP_REF"
  [ "$status" -ne 0 ]
  [ "$(git --git-dir="$SANDBOX" rev-parse refs/heads/main)" = "$BASELINE" ]
}
