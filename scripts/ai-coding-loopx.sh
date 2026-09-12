#!/usr/bin/env bash
set -euo pipefail

# Stable-runtime lifecycle for the downstream AI-Coding LoopX platform.
# Source checkout (/project/loopx) and promoted runtime are deliberately separate.

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ai-coding"
state_dir="$HOME/.local/share/ai-coding/loopx-runtime"
receipt_dir="$state_dir/promotion-receipts"
bin_dir="$HOME/.local/bin"
mkdir -p "$state_dir" "$receipt_dir" "$bin_dir"

[[ -f "$config_dir/env.sh" ]] && source "$config_dir/env.sh"
[[ -f "$config_dir/runtime.env" ]] && source "$config_dir/runtime.env"

platform_root="${AI_CODING_PLATFORM_ROOT:-/project/loopx}"
releases_dir="${LOOPX_RELEASES_DIR:-$HOME/.local/share/loopx/releases}"
previous_file="$state_dir/previous-release"
history_file="$state_dir/history.tsv"

usage() {
  cat <<'USAGE'
Usage: ai-coding-loopx <command> [options]

Commands:
  status                  Show stable runtime and development checkout state.
  canary                  Point loopx-canary at the current development checkout.
  validate                Validate current checkout and write a promotion receipt.
  promote --label LABEL   Install+promote current validated commit as a stable release.
  rollback [RELEASE]      Roll back to previous release, or an explicit release id/path.
  releases                List locally retained stable releases.

Promotion policy:
- source checkout must be clean;
- downstream diff from origin/main must remain additive-only;
- canary installation doctor and AI-Coding checks must pass;
- promote requires a validation receipt for the exact source commit and exact
  currently active stable release.
USAGE
}

active_release() {
  local resolved=""
  if [[ -L "$bin_dir/loopx" ]]; then
    resolved="$(readlink -f "$bin_dir/loopx" 2>/dev/null || true)"
  fi
  if [[ -n "$resolved" && "$resolved" == */scripts/loopx ]]; then
    dirname "$(dirname "$resolved")"
  fi
}

release_id_of() { basename "$1"; }

require_platform() {
  if [[ ! -d "$platform_root/.git" ]]; then
    echo "Development checkout not found: $platform_root" >&2
    exit 1
  fi
}

require_clean() {
  require_platform
  if [[ -n "$(git -C "$platform_root" status --porcelain)" ]]; then
    echo "Development checkout is dirty; commit/stash changes before validation or promotion." >&2
    exit 1
  fi
}

source_head() {
  git -C "$platform_root" rev-parse HEAD
}

atomic_link() {
  local target="$1" link="$2"
  python3 - "$target" "$link" <<'PY'
from pathlib import Path
import os
import sys

target, link = sys.argv[1], Path(sys.argv[2])
link.parent.mkdir(parents=True, exist_ok=True)
tmp = link.with_name(link.name + f".tmp.{os.getpid()}")
try:
    tmp.unlink()
except FileNotFoundError:
    pass
os.symlink(target, tmp)
os.replace(tmp, link)
PY
}

bind_release() {
  local release="$1"
  "$release/scripts/ai-coding-bind-runtime.sh" --release "$release"
}

record_history() {
  local action="$1" from="$2" to="$3"
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$from" "$to" >>"$history_file"
}

cmd_status() {
  require_platform
  local active="$(active_release)"
  printf 'AI-Coding LoopX runtime\n'
  printf '=======================\n'
  printf 'development checkout: %s\n' "$platform_root"
  printf 'development branch:   %s\n' "$(git -C "$platform_root" branch --show-current 2>/dev/null || true)"
  printf 'development commit:   %s\n' "$(source_head)"
  if [[ -n "$(git -C "$platform_root" status --porcelain)" ]]; then
    printf 'development state:    DIRTY\n'
  else
    printf 'development state:    clean\n'
  fi
  printf 'stable release:       %s\n' "${active:-unresolved}"
  if [[ -n "$active" && -f "$active/release.json" ]]; then
    printf 'stable release id:    %s\n' "$(release_id_of "$active")"
    if command -v jq >/dev/null 2>&1; then
      printf 'stable source commit: %s\n' "$(jq -r '.source.git_commit // "unknown"' "$active/release.json")"
    fi
  fi
  printf 'canary executable:    %s\n' "$(readlink -f "$bin_dir/loopx-canary" 2>/dev/null || echo unconfigured)"
  printf 'previous release:     %s\n' "$(cat "$previous_file" 2>/dev/null || echo none)"
}

cmd_canary() {
  require_clean
  LOOPX_PROMOTE_DEFAULT=0 \
  LOOPX_INSTALL_SLASH_COMMANDS=0 \
  LOOPX_BIN_DIR="$bin_dir" \
    "$platform_root/scripts/install-local.sh"
  "$bin_dir/loopx-canary" --format json doctor --deep --installation-only >/dev/null
  echo "Canary ready from $(source_head)"
}

check_additive_boundary() {
  local base_ref="refs/remotes/origin/main"
  if ! git -C "$platform_root" rev-parse "$base_ref" >/dev/null 2>&1; then
    echo "Missing $base_ref. Fetch origin/main before validation." >&2
    exit 1
  fi
  local violations
  violations="$(git -C "$platform_root" diff --name-status "$base_ref"...HEAD | awk '$1 !~ /^A/ {print}')"
  if [[ -n "$violations" ]]; then
    echo "Promotion blocked: downstream is no longer additive-only relative to origin/main." >&2
    echo "$violations" >&2
    echo "A dedicated state/schema compatibility plan is required before promotion." >&2
    exit 1
  fi
}

cmd_validate() {
  require_clean
  check_additive_boundary
  cmd_canary >/dev/null

  bash -n "$platform_root/scripts/ai-coding-init.sh"
  bash -n "$platform_root/scripts/ai-coding-doctor.sh"
  bash -n "$platform_root/scripts/ai-coding-bind-runtime.sh"
  bash -n "$platform_root/scripts/ai-coding-loopx.sh"
  python3 -m compileall -q "$platform_root/loopx/extensions/ai_coding"

  if python3 -m pytest --version >/dev/null 2>&1; then
    python3 -m pytest -q \
      "$platform_root/tests/extensions/test_ai_coding_qwen_code_adapter.py" \
      "$platform_root/tests/extensions/test_ai_coding_node_inventory.py"
  else
    echo "pytest is required for promotion validation." >&2
    exit 1
  fi

  npm --prefix "$platform_root/apps/presentation/coding-dashboard" run build >/dev/null
  "$bin_dir/loopx-canary" --format json doctor --deep --installation-only >/dev/null

  local head active active_id receipt base_commit now
  head="$(source_head)"
  active="$(active_release)"
  if [[ -z "$active" ]]; then
    echo "No stable LoopX runtime is active; initialize the node first." >&2
    exit 1
  fi
  active_id="$(release_id_of "$active")"
  base_commit="$(git -C "$platform_root" rev-parse refs/remotes/origin/main)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  receipt="$receipt_dir/$head.json"
  python3 - "$receipt" "$head" "$base_commit" "$active_id" "$now" <<'PY'
import json
from pathlib import Path
import os
import sys

path, head, base, stable, now = sys.argv[1:]
payload = {
    "schema_version": "ai_coding_promotion_receipt_v0",
    "source_commit": head,
    "base_main_commit": base,
    "validated_against_release": stable,
    "validated_at": now,
    "compatibility_mode": "additive_only",
}
target = Path(path)
tmp = target.with_name(target.name + f".tmp.{os.getpid()}")
tmp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
os.replace(tmp, target)
PY
  echo "Validation passed for $head"
  echo "Promotion receipt: $receipt"
}

require_receipt() {
  local head="$1" active_id="$2" receipt="$receipt_dir/$head.json"
  if [[ ! -f "$receipt" ]]; then
    echo "No promotion receipt for $head. Run: ai-coding-loopx validate" >&2
    exit 1
  fi
  python3 - "$receipt" "$head" "$active_id" <<'PY'
import json
import sys

path, head, active = sys.argv[1:]
data = json.load(open(path, encoding="utf-8"))
if data.get("source_commit") != head:
    raise SystemExit("promotion receipt source commit mismatch")
if data.get("validated_against_release") != active:
    raise SystemExit("promotion receipt was validated against a different stable release")
if data.get("compatibility_mode") != "additive_only":
    raise SystemExit("unsupported promotion compatibility mode")
PY
}

cmd_promote() {
  local label=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label) label="${2:?missing label}"; shift 2 ;;
      *) echo "unknown promote argument: $1" >&2; exit 2 ;;
    esac
  done
  if [[ -z "$label" || ! "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "promote requires --label with a safe value, for example --label 1.1" >&2
    exit 2
  fi

  require_clean
  check_additive_boundary
  local head short active active_id release_id new_active
  head="$(source_head)"
  short="${head:0:12}"
  active="$(active_release)"
  if [[ -z "$active" ]]; then
    echo "No active stable release." >&2
    exit 1
  fi
  active_id="$(release_id_of "$active")"
  require_receipt "$head" "$active_id"
  release_id="ai-coding-${label}-${short}"

  LOOPX_PROMOTE_DEFAULT=1 \
  LOOPX_RELEASE_ID="$release_id" \
  LOOPX_INSTALL_SLASH_COMMANDS=0 \
  LOOPX_BIN_DIR="$bin_dir" \
    "$platform_root/scripts/install-local.sh"

  new_active="$(active_release)"
  if [[ -z "$new_active" || "$new_active" == "$active" ]]; then
    echo "Promotion did not produce a new active release." >&2
    exit 1
  fi

  if ! bind_release "$new_active"; then
    echo "Host-surface binding failed; rolling back to $active_id" >&2
    atomic_link "$active/scripts/loopx" "$bin_dir/loopx"
    [[ -x "$active/scripts/loopx-apply-rrule" ]] && atomic_link "$active/scripts/loopx-apply-rrule" "$bin_dir/loopx-apply-rrule"
    bind_release "$active" || true
    exit 1
  fi

  printf '%s\n' "$active" >"$previous_file"
  record_history promote "$active" "$new_active"
  echo "Promoted stable LoopX runtime: $(release_id_of "$new_active")"
}

resolve_release_arg() {
  local arg="$1"
  if [[ -d "$arg" ]]; then
    (cd "$arg" && pwd)
  elif [[ -d "$releases_dir/$arg" ]]; then
    (cd "$releases_dir/$arg" && pwd)
  else
    return 1
  fi
}

cmd_rollback() {
  local target_arg="${1:-}"
  local current target
  current="$(active_release)"
  if [[ -z "$current" ]]; then
    echo "No active stable release." >&2
    exit 1
  fi
  if [[ -z "$target_arg" ]]; then
    target_arg="$(cat "$previous_file" 2>/dev/null || true)"
  fi
  if [[ -z "$target_arg" ]] || ! target="$(resolve_release_arg "$target_arg")"; then
    echo "Rollback target not found: ${target_arg:-<none>}" >&2
    exit 1
  fi
  if [[ "$target" == "$current" ]]; then
    echo "Rollback target is already active." >&2
    exit 1
  fi
  if [[ ! -x "$target/scripts/loopx" || ! -x "$target/scripts/ai-coding-bind-runtime.sh" ]]; then
    echo "Target is not an AI-Coding stable release: $target" >&2
    exit 1
  fi

  atomic_link "$target/scripts/loopx" "$bin_dir/loopx"
  [[ -x "$target/scripts/loopx-apply-rrule" ]] && atomic_link "$target/scripts/loopx-apply-rrule" "$bin_dir/loopx-apply-rrule"
  if ! bind_release "$target"; then
    echo "Rollback binding failed; restoring current release." >&2
    atomic_link "$current/scripts/loopx" "$bin_dir/loopx"
    [[ -x "$current/scripts/loopx-apply-rrule" ]] && atomic_link "$current/scripts/loopx-apply-rrule" "$bin_dir/loopx-apply-rrule"
    bind_release "$current" || true
    exit 1
  fi
  printf '%s\n' "$current" >"$previous_file"
  record_history rollback "$current" "$target"
  echo "Rolled back stable LoopX runtime to: $(release_id_of "$target")"
}

cmd_releases() {
  local current previous marker
  current="$(active_release)"
  previous="$(cat "$previous_file" 2>/dev/null || true)"
  shopt -s nullglob
  for release in "$releases_dir"/*; do
    [[ -f "$release/release.json" ]] || continue
    marker=" "
    [[ "$release" == "$current" ]] && marker="*"
    [[ "$release" == "$previous" && "$marker" != "*" ]] && marker="-"
    printf '%s %s\n' "$marker" "$(basename "$release")"
  done
}

command_name="${1:-}"
[[ $# -gt 0 ]] && shift || true
case "$command_name" in
  status) cmd_status "$@" ;;
  canary) cmd_canary "$@" ;;
  validate) cmd_validate "$@" ;;
  promote) cmd_promote "$@" ;;
  rollback) cmd_rollback "$@" ;;
  releases) cmd_releases "$@" ;;
  -h|--help|help|"") usage ;;
  *) echo "unknown command: $command_name" >&2; usage >&2; exit 2 ;;
esac
