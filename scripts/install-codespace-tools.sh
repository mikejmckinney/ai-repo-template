#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/.config/codespace-tools.json"
PREFIX="${CODESPACE_TOOLS_PREFIX:-$HOME/.local}"
PROFILE=default
VERIFY_ONLY=false

die() {
  printf 'codespace-tools: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --manifest)
      (($# >= 2)) || die "--manifest requires a path"
      MANIFEST="$2"
      shift 2
      ;;
    --prefix)
      (($# >= 2)) || die "--prefix requires a directory"
      PREFIX="$2"
      shift 2
      ;;
    --profile)
      (($# >= 2)) || die "--profile requires a name"
      PROFILE="$2"
      shift 2
      ;;
    --verify-only)
      VERIFY_ONLY=true
      shift
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"
jq -e '
  .schema_version == 1 and
  (.required_commands | type == "array") and
  (.apt_packages | type == "array") and
  (.profiles | type == "object") and
  (.tools | type == "object") and
  all(.profiles[]; all(.[]; . as $name | $name | type == "string"))
' "$MANIFEST" >/dev/null || die "invalid manifest: $MANIFEST"
jq -e --arg profile "$PROFILE" '.profiles | has($profile)' "$MANIFEST" >/dev/null \
  || die "unknown profile: $PROFILE"

mkdir -p "$PREFIX/bin" "$PREFIX/share"
export PATH="$PREFIX/bin:$PATH"

tool_matches() {
  local command_name="$1" expected="$2" output
  shift 2
  command -v "$command_name" >/dev/null 2>&1 || return 1
  output="$("$command_name" "$@" 2>&1 || true)"
  grep -Fq "$expected" <<<"$output"
}

binary_companions_match() {
  local name="$1" version="$2" companion command_name version_prefix output
  local -a version_args
  while IFS= read -r companion; do
    command_name="$(jq -r '.command' <<<"$companion")"
    version_prefix="$(jq -r '.version_prefix // empty' <<<"$companion")"
    mapfile -t version_args < <(jq -r '.version_args[]' <<<"$companion")
    command -v "$command_name" >/dev/null 2>&1 || return 1
    output="$("$command_name" "${version_args[@]}" 2>&1 || true)"
    grep -Fq "$version" <<<"$output" || return 1
    [[ -z "$version_prefix" || "$output" == "$version_prefix"* ]] || return 1
  done < <(jq -c --arg name "$name" '.tools[$name].companions[]?' "$MANIFEST")
}

apt_update() (
  local source sourceparts filtered_sourceparts
  sourceparts="${CODESPACE_APT_SOURCE_PARTS:-/etc/apt/sources.list.d}"
  filtered_sourceparts="$(mktemp -d "${TMPDIR:-/tmp}/codespace-apt-sources.XXXXXX")"
  trap 'rm -rf "$filtered_sourceparts"' EXIT

  if [[ -d "$sourceparts" ]]; then
    shopt -s nullglob
    for source in "$sourceparts"/*.list "$sourceparts"/*.sources; do
      if grep -Fq 'dl.yarnpkg.com/debian' "$source"; then
        printf 'codespace-tools: ignoring unrelated Yarn apt source during package installation\n'
        continue
      fi
      ln -s "$source" "$filtered_sourceparts/$(basename "$source")"
    done
  fi

  "$@" apt-get -o "Dir::Etc::sourceparts=$filtered_sourceparts" update -qq
)

install_deb_dependencies() {
  local dependency_file="$1"
  mapfile -t dependencies < <(grep -Ev '^[[:space:]]*(#|$)' "$dependency_file")
  [[ ${#dependencies[@]} -gt 0 ]] || return 0
  command -v apt-get >/dev/null 2>&1 || die "apt-get is required for Chrome runtime dependencies"
  if [[ "$(id -u)" == 0 ]]; then
    apt_update
    apt-get satisfy -y --no-install-recommends "${dependencies[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    apt_update sudo
    sudo apt-get satisfy -y --no-install-recommends "${dependencies[@]}"
  else
    die "root or sudo is required for Chrome runtime dependencies"
  fi
}

download_verified() {
  local name="$1" url="$2" expected_sha="$3" destination="$4"
  curl -fsSL "$url" -o "$destination"
  actual_sha="$(sha256sum "$destination" | cut -d' ' -f1)"
  [[ "$actual_sha" == "$expected_sha" ]] || die "checksum mismatch for $name"
}

install_binary() {
  local name="$1" command_name version archive url sha member temp extract_dir source
  local companion companion_command companion_member
  local -a members version_args
  command_name="$(jq -r --arg name "$name" '.tools[$name].command' "$MANIFEST")"
  version="$(jq -r --arg name "$name" '.tools[$name].version' "$MANIFEST")"
  mapfile -t version_args < <(jq -r --arg name "$name" '.tools[$name].version_args[]' "$MANIFEST")
  if tool_matches "$command_name" "$version" "${version_args[@]}" \
    && binary_companions_match "$name" "$version"; then
    printf 'codespace-tools: %s %s already installed\n' "$name" "$version"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name $version is missing or mismatched"

  archive="$(jq -r --arg name "$name" '.tools[$name].asset.archive' "$MANIFEST")"
  url="$(jq -r --arg name "$name" '.tools[$name].asset.url' "$MANIFEST")"
  sha="$(jq -r --arg name "$name" '.tools[$name].asset.sha256' "$MANIFEST")"
  member="$(jq -r --arg name "$name" '.tools[$name].asset.member // empty' "$MANIFEST")"
  temp="$(mktemp "${TMPDIR:-/tmp}/codespace-tool.XXXXXX")"
  extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/codespace-tool-extract.XXXXXX")"
  trap 'rm -f "$temp"; rm -rf "$extract_dir"' RETURN
  download_verified "$name" "$url" "$sha" "$temp"

  case "$archive" in
    raw) source="$temp" ;;
    tar.gz)
      mapfile -t members < <(
        jq -r --arg name "$name" \
          '[.tools[$name].asset.member, (.tools[$name].companions[]?.member)] | .[]' \
          "$MANIFEST"
      )
      tar -xzf "$temp" -C "$extract_dir" "${members[@]}"
      source="$extract_dir/$member"
      ;;
    *) die "unsupported binary archive for $name: $archive" ;;
  esac
  install -m 0755 "$source" "$PREFIX/bin/$command_name"
  while IFS= read -r companion; do
    companion_command="$(jq -r '.command' <<<"$companion")"
    companion_member="$(jq -r '.member' <<<"$companion")"
    install -m 0755 "$extract_dir/$companion_member" "$PREFIX/bin/$companion_command"
  done < <(jq -c --arg name "$name" '.tools[$name].companions[]?' "$MANIFEST")
  printf 'codespace-tools: installed %s %s\n' "$name" "$version"
}

install_archive() {
  local name="$1" command_name version archive url sha member temp install_dir
  command_name="$(jq -r --arg name "$name" '.tools[$name].command' "$MANIFEST")"
  version="$(jq -r --arg name "$name" '.tools[$name].version' "$MANIFEST")"
  mapfile -t version_args < <(jq -r --arg name "$name" '.tools[$name].version_args[]' "$MANIFEST")
  install_dir="$PREFIX/share/$name/$version"
  if tool_matches "$command_name" "$version" "${version_args[@]}"; then
    printf 'codespace-tools: %s %s already installed\n' "$name" "$version"
    return
  fi
  if [[ -f "$install_dir/chrome-linux64/deb.deps" && "$VERIFY_ONLY" == false ]]; then
    install_deb_dependencies "$install_dir/chrome-linux64/deb.deps"
    if tool_matches "$command_name" "$version" "${version_args[@]}"; then
      printf 'codespace-tools: %s %s already installed\n' "$name" "$version"
      return
    fi
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name $version is missing or mismatched"

  archive="$(jq -r --arg name "$name" '.tools[$name].asset.archive' "$MANIFEST")"
  url="$(jq -r --arg name "$name" '.tools[$name].asset.url' "$MANIFEST")"
  sha="$(jq -r --arg name "$name" '.tools[$name].asset.sha256' "$MANIFEST")"
  member="$(jq -r --arg name "$name" '.tools[$name].asset.member' "$MANIFEST")"
  temp="$(mktemp "${TMPDIR:-/tmp}/codespace-tool.XXXXXX")"
  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  download_verified "$name" "$url" "$sha" "$temp"
  case "$archive" in
    zip) unzip -q "$temp" -d "$install_dir" ;;
    tar.gz) tar -xzf "$temp" -C "$install_dir" ;;
    *) die "unsupported archive for $name: $archive" ;;
  esac
  if [[ -f "$install_dir/chrome-linux64/deb.deps" ]]; then
    install_deb_dependencies "$install_dir/chrome-linux64/deb.deps"
  fi
  ln -sfn "$install_dir/$member" "$PREFIX/bin/$command_name"
  rm -f "$temp"
  printf 'codespace-tools: installed %s %s\n' "$name" "$version"
}

ensure_open_design_node() {
  local lock_file required_node current_node nvm_script
  lock_file="$REPO_ROOT/$(jq -r '.tools["open-design"].lock' "$MANIFEST")"
  [[ -f "$lock_file" ]] || die "Open Design lock not found: $lock_file"
  required_node="$(awk -F: '$1 == "node" {gsub(/^[[:space:]]+/, "", $2); sub(/^~/, "", $2); print $2; exit}' "$lock_file")"
  [[ "$required_node" =~ ^[0-9]+$ ]] || die "invalid Open Design Node requirement in $lock_file"

  current_node="$(node --version 2>/dev/null || true)"
  [[ "$current_node" == "v${required_node}."* ]] && return

  nvm_script="${NVM_DIR:-}/nvm.sh"
  [[ -s "$nvm_script" ]] || die "Open Design requires Node.js $required_node; NVM script not found: $nvm_script"
  # shellcheck disable=SC1090
  source "$nvm_script"
  command -v nvm >/dev/null 2>&1 || die "Open Design requires Node.js $required_node; nvm is unavailable"
  nvm install "$required_node"
  nvm alias default "$required_node" >/dev/null
  nvm use "$required_node" >/dev/null

  current_node="$(node --version 2>/dev/null || true)"
  [[ "$current_node" == "v${required_node}."* ]] \
    || die "Open Design requires Node.js $required_node (found $current_node)"
}

install_npm() {
  local name="$1" command_name version package expected_integrity actual_integrity
  command_name="$(jq -r --arg name "$name" '.tools[$name].command' "$MANIFEST")"
  version="$(jq -r --arg name "$name" '.tools[$name].version' "$MANIFEST")"
  mapfile -t version_args < <(jq -r --arg name "$name" '.tools[$name].version_args[]' "$MANIFEST")
  if tool_matches "$command_name" "$version" "${version_args[@]}"; then
    printf 'codespace-tools: %s %s already installed\n' "$name" "$version"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name $version is missing or mismatched"
  package="$(jq -r --arg name "$name" '.tools[$name].package' "$MANIFEST")"
  expected_integrity="$(jq -r --arg name "$name" '.tools[$name].integrity' "$MANIFEST")"
  actual_integrity="$(npm view "$package" dist.integrity)"
  [[ "$actual_integrity" == "$expected_integrity" ]] || die "registry integrity mismatch for $name"
  npm install --global --prefix "$PREFIX" "$package"
  printf 'codespace-tools: installed %s %s\n' "$name" "$version"
}

install_open_design() {
  local name="$1" commit lock bootstrap source_root cli
  ensure_open_design_node
  commit="$(jq -r --arg name "$name" '.tools[$name].version' "$MANIFEST")"
  lock="$REPO_ROOT/$(jq -r --arg name "$name" '.tools[$name].lock' "$MANIFEST")"
  bootstrap="$REPO_ROOT/$(jq -r --arg name "$name" '.tools[$name].bootstrap' "$MANIFEST")"
  source_root="${OPEN_DESIGN_HOME:-$HOME/.local/share/open-design}"
  cli="$source_root/apps/daemon/bin/od.mjs"
  if { [[ -x "$cli" ]] || [[ -f "$cli" ]]; } \
    && [[ -f "$source_root/apps/web/package.json" ]] \
    && [[ -d "$source_root/design-systems" ]] \
    && [[ -d "$source_root/design-templates/hyperframes" ]] \
    && [[ -d "$source_root/skills" ]] \
    && [[ "$(git -C "$source_root" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]]; then
    printf 'codespace-tools: open-design %s already installed\n' "$commit"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "open-design $commit is missing or mismatched"
  bash "$bootstrap" --lock "$lock"
}

install_npm_project() {
  local name="$1" project_path project_dir
  project_path="$(jq -r --arg name "$name" '.tools[$name].path' "$MANIFEST")"
  if [[ "$project_path" == /* ]]; then
    project_dir="$project_path"
  else
    project_dir="$REPO_ROOT/$project_path"
  fi
  [[ -f "$project_dir/package-lock.json" ]] || die "$name lockfile not found: $project_dir/package-lock.json"
  if npm ls --prefix "$project_dir" --omit=dev --depth=0 >/dev/null 2>&1; then
    printf 'codespace-tools: %s lockfile dependencies already installed\n' "$name"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name lockfile dependencies are missing or mismatched"
  npm ci --prefix "$project_dir"
  printf 'codespace-tools: installed %s from lockfile\n' "$name"
}

install_vendor_channel() {
  local name="$1" command_name url package expected_integrity actual_integrity temp
  command_name="$(jq -r --arg name "$name" '.tools[$name].command' "$MANIFEST")"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'codespace-tools: %s current channel already installed\n' "$name"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name current channel is missing"
  package="$(jq -r --arg name "$name" '.tools[$name].package // empty' "$MANIFEST")"
  if [[ -n "$package" ]]; then
    expected_integrity="$(jq -r --arg name "$name" '.tools[$name].integrity' "$MANIFEST")"
    actual_integrity="$(npm view "$package" dist.integrity)"
    [[ "$actual_integrity" == "$expected_integrity" ]] || die "registry integrity mismatch for $name"
    npm install --global --prefix "$PREFIX" "$package"
    return
  fi
  url="$(jq -r --arg name "$name" '.tools[$name].installer_url' "$MANIFEST")"
  temp="$(mktemp "${TMPDIR:-/tmp}/codespace-vendor-installer.XXXXXX")"
  curl -fsSL "$url" -o "$temp"
  bash "$temp"
  rm -f "$temp"
}

install_apt_packages() {
  local missing=() command_name required_path package
  while IFS= read -r item; do
    command_name="$(jq -r '.command // empty' <<<"$item")"
    required_path="$(jq -r '.path // empty' <<<"$item")"
    package="$(jq -r '.package' <<<"$item")"
    if { [[ -n "$command_name" ]] && command -v "$command_name" >/dev/null 2>&1; } \
      || { [[ -n "$required_path" ]] && [[ -e "$required_path" ]]; }; then
      continue
    fi
    missing+=("$package")
  done < <(jq -c '.apt_packages[]' "$MANIFEST")
  [[ ${#missing[@]} -gt 0 ]] || return 0
  [[ "$VERIFY_ONLY" == false ]] || die "missing apt packages: ${missing[*]}"
  command -v apt-get >/dev/null 2>&1 || die "apt-get is required to install: ${missing[*]}"
  if [[ "$(id -u)" == 0 ]]; then
    apt_update
    apt-get install -y "${missing[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    apt_update sudo
    sudo apt-get install -y "${missing[@]}"
  else
    die "root or sudo is required to install: ${missing[*]}"
  fi
}

install_apt_tool() {
  local name="$1" command_name package
  command_name="$(jq -r --arg name "$name" '.tools[$name].command' "$MANIFEST")"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'codespace-tools: %s already installed\n' "$name"
    return
  fi
  [[ "$VERIFY_ONLY" == false ]] || die "$name is missing"
  package="$(jq -r --arg name "$name" '.tools[$name].package' "$MANIFEST")"
  command -v apt-get >/dev/null 2>&1 || die "apt-get is required to install: $package"
  if [[ "$(id -u)" == 0 ]]; then
    apt_update
    apt-get install -y "$package"
  elif command -v sudo >/dev/null 2>&1; then
    apt_update sudo
    sudo apt-get install -y "$package"
  else
    die "root or sudo is required to install: $package"
  fi
}

install_apt_packages
for command_name in $(jq -r '.required_commands[]' "$MANIFEST"); do
  command -v "$command_name" >/dev/null 2>&1 || die "required base command is missing: $command_name"
done

mapfile -t selected_tools < <(jq -r --arg profile "$PROFILE" \
  '.profiles[$profile][]' "$MANIFEST" | awk '!seen[$0]++')

for name in "${selected_tools[@]}"; do
  type="$(jq -r --arg name "$name" '.tools[$name].type' "$MANIFEST")"
  case "$type" in
    apt) install_apt_tool "$name" ;;
    binary) install_binary "$name" ;;
    archive) install_archive "$name" ;;
    npm) install_npm "$name" ;;
    open-design) install_open_design "$name" ;;
    npm-project) install_npm_project "$name" ;;
    vendor-channel) install_vendor_channel "$name" ;;
    *) die "unsupported tool type for $name: $type" ;;
  esac
done

if [[ "$PROFILE" == agents || "$PROFILE" == default ]]; then
  printf 'codespace-tools: agent CLIs installed; complete each vendor authentication flow separately\n'
fi
