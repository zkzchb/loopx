#!/usr/bin/env bash
set -uo pipefail

# Read-only health report for one AI-Coding platform node.

failures=0
warnings=0
ok() { printf 'OK    %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ai-coding"
env_file="$config_dir/env.sh"
runtime_file="$config_dir/runtime.env"
node_file="$config_dir/node.env"
[[ -f "$env_file" ]] && source "$env_file"
[[ -f "$runtime_file" ]] && source "$runtime_file"
[[ -f "$node_file" ]] && source "$node_file"

printf 'AI-Coding node doctor\n'
printf '=====================\n'
info "role=${AI_CODING_NODE_ROLE:-unconfigured}"
info "development_user=${AI_CODING_DEV_USER:-unconfigured}"
info "platform=${AI_CODING_PLATFORM_ROOT:-unconfigured}"
info "projects=${AI_CODING_PROJECTS_ROOT:-unconfigured}"
info "stable_release=${AI_CODING_LOOPX_ACTIVE_RELEASE:-unconfigured}"
info "loopx_dashboard=${AI_CODING_LOOPX_DASHBOARD_HOST:-127.0.0.1}:${AI_CODING_LOOPX_DASHBOARD_PORT:-8767}"
info "coding_dashboard=${AI_CODING_DASHBOARD_HOST:-127.0.0.1}:${AI_CODING_DASHBOARD_PORT:-8768}"

check_command() {
  local name="$1" required="${2:-1}"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name -> $(command -v "$name")"
  elif [[ "$required" == "1" ]]; then
    fail "$name is not on PATH"
  else
    warn "$name is not on PATH"
  fi
}

check_version() {
  local name="$1"; shift
  if command -v "$name" >/dev/null 2>&1; then
    local output
    output="$("$name" "$@" 2>&1 | head -n 1 || true)"
    info "$name version: ${output:-unknown}"
  fi
}

for cmd in git gh curl jq python3 node npm loopx codex qwen kiro-cli ai-coding-loopx; do
  check_command "$cmd"
done
check_version python3 --version
check_version node --version
check_version npm --version
check_version loopx --version
check_version codex --version
check_version qwen --version
check_version kiro-cli --version

if command -v python3 >/dev/null 2>&1; then
  python_version="$(python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"
  if python3 - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
  then ok "Python $python_version >= 3.11"; else fail "Python $python_version is below LoopX minimum 3.11"; fi
fi

if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 22 )); then
    ok "Node.js major $node_major is suitable for the platform"
  else
    fail "Node.js 22+ is required for the standardized node image"
  fi
fi

# Stable runtime must be an immutable promoted release, not /project/loopx.
active_release="${AI_CODING_LOOPX_ACTIVE_RELEASE:-}"
loopx_target="$(readlink -f "$(command -v loopx 2>/dev/null)" 2>/dev/null || true)"
if [[ -n "$active_release" && -f "$active_release/release.json" ]]; then
  ok "stable LoopX release manifest exists"
else
  fail "stable LoopX release is unresolved or missing release.json"
fi
if [[ -n "$active_release" && "$loopx_target" == "$active_release/scripts/loopx" ]]; then
  ok "loopx executable is bound to stable release"
else
  fail "loopx executable is not bound to AI_CODING_LOOPX_ACTIVE_RELEASE"
fi
if [[ -n "${AI_CODING_PLATFORM_ROOT:-}" && -n "$loopx_target" && "$loopx_target" == "${AI_CODING_PLATFORM_ROOT}"/* ]]; then
  fail "stable loopx executable leaks into development checkout"
fi

for helper in ai-coding-doctor ai-coding-loopx ai-coding-project-init; do
  helper_path="$(command -v "$helper" 2>/dev/null || true)"
  [[ -z "$helper_path" ]] && continue
  helper_target="$(readlink -f "$helper_path" 2>/dev/null || true)"
  if [[ -n "$active_release" && "$helper_target" == "$active_release/scripts/"* ]]; then
    ok "$helper is bound to stable release"
  else
    fail "$helper is not bound to stable release"
  fi
done

if [[ -n "${AI_CODING_PLATFORM_ROOT:-}" && -d "${AI_CODING_PLATFORM_ROOT}/.git" ]]; then
  ok "development checkout exists"
  branch="$(git -C "$AI_CODING_PLATFORM_ROOT" branch --show-current 2>/dev/null || true)"
  info "development branch=${branch:-unknown}"
  [[ "$branch" == "platform" ]] || warn "development checkout is expected on branch 'platform'"
else
  fail "AI_CODING_PLATFORM_ROOT is missing or is not a Git checkout"
fi

for dir in "${AI_CODING_PROJECTS_ROOT:-}" "${AI_CODING_SCRATCH_ROOT:-}" "$HOME/.codex" "$HOME/.kiro" "$HOME/.qwen"; do
  [[ -z "$dir" ]] && continue
  [[ -d "$dir" ]] && ok "directory exists: $dir" || warn "directory missing: $dir"
done

codex_skill="$HOME/.codex/skills/loopx/SKILL.md"
kiro_home="${KIRO_HOME:-$HOME/.kiro}"
kiro_skill="$kiro_home/skills/loopx/SKILL.md"
qwen_skill="$HOME/.qwen/skills/loopx/SKILL.md"
[[ -f "$codex_skill" ]] && ok "Codex LoopX skill installed" || warn "Codex LoopX skill not found at $codex_skill"
[[ -f "$kiro_skill" ]] && ok "Kiro LoopX skill installed" || warn "Kiro LoopX skill not found at $kiro_skill"
[[ -f "$qwen_skill" ]] && ok "Qwen LoopX skill installed" || fail "Qwen LoopX skill not found at $qwen_skill"

qwen_settings="$HOME/.qwen/settings.json"
if [[ -f "$qwen_settings" ]] && grep -q 'loopx-ai-coding' "$qwen_settings"; then
  ok "Qwen user MCP entry loopx-ai-coding is configured"
else
  fail "Qwen user MCP entry loopx-ai-coding is not configured"
fi

qwen_mcp_python="${AI_CODING_QWEN_MCP_PYTHON:-}"
if [[ -x "$qwen_mcp_python" ]]; then
  marker="$(dirname "$qwen_mcp_python")/.source-release"
  marker_value="$(cat "$marker" 2>/dev/null || true)"
  if [[ "$marker_value" == "${AI_CODING_LOOPX_ACTIVE_RELEASE_ID:-}" ]]; then
    ok "Qwen MCP runtime matches stable release ${marker_value}"
  else
    fail "Qwen MCP runtime release marker does not match stable LoopX release"
  fi
  if "$qwen_mcp_python" - <<'PY' >/dev/null 2>&1
import mcp
import loopx
from loopx.extensions.ai_coding import qwen_code_mcp
PY
  then ok "Qwen MCP runtime imports LoopX and mcp"; else fail "Qwen MCP runtime cannot import LoopX/mcp adapter"; fi
else
  fail "Qwen MCP Python runtime missing: ${qwen_mcp_python:-unconfigured}"
fi

if command -v loopx >/dev/null 2>&1; then
  tmp="/tmp/ai-coding-loopx-doctor.$$"
  if loopx doctor >"$tmp" 2>&1; then ok "loopx doctor passed"; else warn "loopx doctor reported issues; inspect output below"; fi
  sed 's/^/      /' "$tmp" 2>/dev/null | tail -n 40 || true
  rm -f "$tmp"
fi

if command -v codex >/dev/null 2>&1; then
  tmp="/tmp/ai-coding-codex-login.$$"
  if codex login status >"$tmp" 2>&1; then ok "Codex login status is healthy"; else warn "Codex is installed but login may still be required"; fi
  sed 's/^/      /' "$tmp" 2>/dev/null | head -n 8 || true
  rm -f "$tmp"
fi

printf '\nSummary: failures=%d warnings=%d\n' "$failures" "$warnings"
(( failures == 0 )) || exit 1
exit 0
