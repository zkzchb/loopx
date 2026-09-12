#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a fresh Ubuntu PDS/PDS-Lab node for the downstream AI-Coding
# platform. Machine setup is intentionally separate from per-project LoopX
# Goal/Todo state.

ROLE="pds"
TARGET_USER="${SUDO_USER:-$(id -un)}"
PLATFORM_ROOT="/opt/ai-coding/loopx"
PLATFORM_REPO="https://github.com/zkzchb/loopx.git"
PLATFORM_BRANCH="platform"
PROJECTS_ROOT=""
SCRATCH_ROOT="/srv/ai-coding/scratch"
INSTALL_APT=1
INSTALL_DASHBOARD_DEPS=1
UPGRADE_TOOLS=0

usage() {
  cat <<'EOF'
Usage: ai-coding-bootstrap.sh [options]

Options:
  --role pds|pds-lab         Node role (default: pds)
  --user USER                Runtime user (default: SUDO_USER/current user)
  --platform-root PATH       LoopX platform checkout (default: /opt/ai-coding/loopx)
  --repo URL                 Platform Git repository
  --branch NAME              Platform branch (default: platform)
  --skip-apt                 Do not install apt/Node prerequisites
  --skip-dashboard-deps      Do not install Dashboard npm dependencies
  --upgrade-tools            Re-run official Codex/Qwen/Kiro installers
  -h, --help                 Show help

The script never stores API keys or performs interactive logins. Authentication
is a post-install step performed by the runtime user.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE="${2:?missing value for --role}"
      shift 2
      ;;
    --user)
      TARGET_USER="${2:?missing value for --user}"
      shift 2
      ;;
    --platform-root)
      PLATFORM_ROOT="${2:?missing value for --platform-root}"
      shift 2
      ;;
    --repo)
      PLATFORM_REPO="${2:?missing value for --repo}"
      shift 2
      ;;
    --branch)
      PLATFORM_BRANCH="${2:?missing value for --branch}"
      shift 2
      ;;
    --skip-apt)
      INSTALL_APT=0
      shift
      ;;
    --skip-dashboard-deps)
      INSTALL_DASHBOARD_DEPS=0
      shift
      ;;
    --upgrade-tools)
      UPGRADE_TOOLS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$ROLE" != "pds" && "$ROLE" != "pds-lab" ]]; then
  echo "--role must be pds or pds-lab" >&2
  exit 2
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 && "$TARGET_USER" == "root" ]] && id ubuntu >/dev/null 2>&1; then
    TARGET_USER="ubuntu"
  else
    echo "runtime user does not exist: $TARGET_USER" >&2
    exit 2
  fi
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
USER_BIN="$TARGET_HOME/.local/bin"
CONFIG_DIR="$TARGET_HOME/.config/ai-coding"
STATE_DIR="$TARGET_HOME/.local/share/ai-coding"
QWEN_MCP_VENV="$STATE_DIR/qwen-mcp"
QWEN_MCP_PYTHON="$QWEN_MCP_VENV/bin/python"
CODEX_HOME="$TARGET_HOME/.codex"
KIRO_HOME="$TARGET_HOME/.kiro"
QWEN_HOME="$TARGET_HOME/.qwen"

if [[ -z "$PROJECTS_ROOT" ]]; then
  if [[ "$ROLE" == "pds" ]]; then
    PROJECTS_ROOT="/srv/ai-coding/projects"
  else
    PROJECTS_ROOT="/srv/ai-coding/lab-projects"
  fi
fi

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }

have_sudo=0
if [[ "$(id -u)" -eq 0 ]]; then
  have_sudo=1
elif command -v sudo >/dev/null 2>&1; then
  have_sudo=1
fi

root_run() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

as_user() {
  if [[ "$(id -un)" == "$TARGET_USER" ]]; then
    HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" "$@"
  else
    sudo -u "$TARGET_USER" -H env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" "$@"
  fi
}

user_shell() {
  as_user bash -c "export PATH='$USER_BIN:/usr/local/bin:/usr/bin:/bin:\$PATH'; $*"
}

require_privilege() {
  if [[ "$have_sudo" != "1" ]]; then
    echo "this bootstrap needs root or sudo for /opt, /srv, apt, and Node.js setup" >&2
    exit 1
  fi
}

install_user_file() {
  local src="$1"
  local dest="$2"
  local mode="${3:-0644}"
  root_run install -d -o "$TARGET_USER" -g "$TARGET_GROUP" "$(dirname "$dest")"
  root_run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m "$mode" "$src" "$dest"
}

require_privilege

log "Preflight"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "OS: ${PRETTY_NAME:-unknown}"
  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "the standardized image targets Ubuntu 24.04; continuing on ${PRETTY_NAME:-unknown}"
  fi
fi
echo "role: $ROLE"
echo "runtime user: $TARGET_USER ($TARGET_HOME)"
echo "platform root: $PLATFORM_ROOT"
echo "projects root: $PROJECTS_ROOT"

if [[ "$INSTALL_APT" == "1" ]]; then
  log "Install base packages"
  root_run apt-get update
  DEBIAN_FRONTEND=noninteractive root_run apt-get install -y \
    ca-certificates curl git jq unzip xz-utils build-essential \
    python3 python3-venv python3-pip openssh-client lsof gh

  node_major=0
  if command -v node >/dev/null 2>&1; then
    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  fi
  if [[ ! "$node_major" =~ ^[0-9]+$ ]] || (( node_major < 22 )); then
    log "Install Node.js 22"
    if [[ "$(id -u)" -eq 0 ]]; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    else
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    fi
    DEBIAN_FRONTEND=noninteractive root_run apt-get install -y nodejs
  fi
fi

log "Create standardized directories"
root_run install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$(dirname "$PLATFORM_ROOT")" \
  "$PROJECTS_ROOT" \
  "$SCRATCH_ROOT"
as_user mkdir -p \
  "$USER_BIN" "$CONFIG_DIR" "$STATE_DIR" \
  "$CODEX_HOME" "$KIRO_HOME" "$QWEN_HOME/skills"

log "Install or update platform checkout"
if [[ ! -d "$PLATFORM_ROOT/.git" ]]; then
  as_user git clone --branch "$PLATFORM_BRANCH" --single-branch "$PLATFORM_REPO" "$PLATFORM_ROOT"
else
  origin="$(as_user git -C "$PLATFORM_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin" ]]; then
    echo "$PLATFORM_ROOT has no Git origin" >&2
    exit 1
  fi
  if [[ -n "$(as_user git -C "$PLATFORM_ROOT" status --porcelain)" ]]; then
    echo "$PLATFORM_ROOT has local changes; refusing to overwrite a dirty platform checkout" >&2
    exit 1
  fi
  as_user git -C "$PLATFORM_ROOT" fetch origin "$PLATFORM_BRANCH"
  as_user git -C "$PLATFORM_ROOT" checkout "$PLATFORM_BRANCH"
  as_user git -C "$PLATFORM_ROOT" merge --ff-only "origin/$PLATFORM_BRANCH"
fi

install_tool_if_needed() {
  local name="$1"
  local install_command="$2"
  if user_shell "command -v '$name' >/dev/null 2>&1" && [[ "$UPGRADE_TOOLS" != "1" ]]; then
    echo "$name already installed: $(user_shell "command -v '$name'")"
    return 0
  fi
  log "Install $name"
  user_shell "$install_command"
}

install_tool_if_needed codex "curl -fsSL https://chatgpt.com/codex/install.sh | sh"
install_tool_if_needed qwen "curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash"
install_tool_if_needed kiro-cli "curl -fsSL https://cli.kiro.dev/install | bash"

log "Install LoopX platform release from the platform checkout"
as_user env \
  PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
  CODEX_HOME="$CODEX_HOME" \
  LOOPX_BIN_DIR="$USER_BIN" \
  LOOPX_PROMOTE_DEFAULT=1 \
  LOOPX_INSTALL_SLASH_COMMANDS=0 \
  bash "$PLATFORM_ROOT/scripts/install-local.sh"

LOOPX_BIN="$USER_BIN/loopx"
if [[ ! -x "$LOOPX_BIN" ]]; then
  LOOPX_BIN="$(user_shell 'command -v loopx')"
fi
if [[ -z "$LOOPX_BIN" || ! -x "$LOOPX_BIN" ]]; then
  echo "LoopX install did not produce an executable" >&2
  exit 1
fi

log "Install LoopX host surfaces"
as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" CODEX_HOME="$CODEX_HOME" \
  "$LOOPX_BIN" slash-commands --install --surface codex
as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" KIRO_HOME="$KIRO_HOME" \
  "$LOOPX_BIN" slash-commands --install --surface kiro-cli

log "Install Qwen Code LoopX Skill"
root_run install -d -o "$TARGET_USER" -g "$TARGET_GROUP" "$QWEN_HOME/skills/loopx"
root_run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
  "$PLATFORM_ROOT/skills/ai-coding-qwen-loopx/SKILL.md" \
  "$QWEN_HOME/skills/loopx/SKILL.md"

log "Create isolated Qwen MCP runtime"
if [[ ! -x "$QWEN_MCP_VENV/bin/python" ]]; then
  as_user python3 -m venv "$QWEN_MCP_VENV"
fi
as_user "$QWEN_MCP_VENV/bin/python" -m pip install --upgrade pip
as_user "$QWEN_MCP_VENV/bin/python" -m pip install \
  -e "$PLATFORM_ROOT" \
  "mcp==1.28.1"

QWEN_BIN="$USER_BIN/qwen"
if [[ ! -x "$QWEN_BIN" ]]; then
  QWEN_BIN="$(user_shell 'command -v qwen')"
fi
if [[ -z "$QWEN_BIN" || ! -x "$QWEN_BIN" ]]; then
  echo "Qwen Code is not available after installation" >&2
  exit 1
fi

log "Configure Qwen user-scope LoopX MCP"
as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
  "$QWEN_BIN" mcp remove --scope user loopx-ai-coding >/dev/null 2>&1 || true
as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
  "$QWEN_BIN" mcp add --scope user --transport stdio \
  --description "LoopX control plane for the AI-Coding Qwen worker lane" \
  loopx-ai-coding "$QWEN_MCP_PYTHON" -m loopx.extensions.ai_coding.qwen_code_mcp

log "Write node environment and agent manifest"
tmp_env="$(mktemp)"
cat >"$tmp_env" <<EOF
# Generated by ai-coding-bootstrap.sh. Safe to source from interactive shells.
export PATH="$USER_BIN:\$PATH"
export AI_CODING_NODE_ROLE="$ROLE"
export AI_CODING_PLATFORM_ROOT="$PLATFORM_ROOT"
export AI_CODING_PROJECTS_ROOT="$PROJECTS_ROOT"
export AI_CODING_SCRATCH_ROOT="$SCRATCH_ROOT"
export AI_CODING_LOOPX_DASHBOARD_HOST="127.0.0.1"
export AI_CODING_LOOPX_DASHBOARD_PORT="8767"
export AI_CODING_DASHBOARD_HOST="127.0.0.1"
export AI_CODING_DASHBOARD_PORT="8768"
export AI_CODING_QWEN_AGENT_ID="qwen-code"
export AI_CODING_QWEN_MCP_PYTHON="$QWEN_MCP_PYTHON"
export CODEX_HOME="$CODEX_HOME"
export KIRO_HOME="$KIRO_HOME"
EOF
install_user_file "$tmp_env" "$CONFIG_DIR/env.sh" 0644
rm -f "$tmp_env"

tmp_node="$(mktemp)"
cat >"$tmp_node" <<EOF
AI_CODING_NODE_ROLE='$ROLE'
AI_CODING_PLATFORM_ROOT='$PLATFORM_ROOT'
AI_CODING_PROJECTS_ROOT='$PROJECTS_ROOT'
AI_CODING_SCRATCH_ROOT='$SCRATCH_ROOT'
AI_CODING_LOOPX_DASHBOARD_HOST='127.0.0.1'
AI_CODING_LOOPX_DASHBOARD_PORT='8767'
AI_CODING_DASHBOARD_HOST='127.0.0.1'
AI_CODING_DASHBOARD_PORT='8768'
EOF
install_user_file "$tmp_node" "$CONFIG_DIR/node.env" 0644
rm -f "$tmp_node"

tmp_agents="$(mktemp)"
cat >"$tmp_agents" <<EOF
{
  "schema_version": "ai_coding_node_agents_v0",
  "node_role": "$ROLE",
  "agents": {
    "codex": {
      "binary": "$USER_BIN/codex",
      "loopx_integration": "upstream",
      "loopx_agent_type": "codex-cli",
      "role": "primary_interaction_planning_review"
    },
    "kiro": {
      "binary": "$USER_BIN/kiro-cli",
      "loopx_integration": "upstream",
      "loopx_agent_type": "kiro-cli",
      "role": "secondary_planning_execution"
    },
    "qwen-code": {
      "binary": "$USER_BIN/qwen",
      "loopx_integration": "ai_coding_extension",
      "loopx_runtime_profile": "generic_cli",
      "registered_agent_id": "qwen-code",
      "mcp_server": "loopx-ai-coding",
      "role": "worker"
    }
  }
}
EOF
install_user_file "$tmp_agents" "$CONFIG_DIR/agents.json" 0644
rm -f "$tmp_agents"

profile_line='[ -f "$HOME/.config/ai-coding/env.sh" ] && . "$HOME/.config/ai-coding/env.sh"'
for profile in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.profile"; do
  as_user touch "$profile"
  if ! as_user grep -Fqx "$profile_line" "$profile"; then
    printf '%s\n' "$profile_line" | as_user tee -a "$profile" >/dev/null
  fi
done

root_run ln -sfn "$PLATFORM_ROOT/scripts/ai-coding-doctor.sh" "$USER_BIN/ai-coding-doctor"
root_run chown -h "$TARGET_USER:$TARGET_GROUP" "$USER_BIN/ai-coding-doctor"

if [[ "$INSTALL_DASHBOARD_DEPS" == "1" ]]; then
  log "Install Dashboard dependencies"
  as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
    npm --prefix "$PLATFORM_ROOT/apps/presentation/dashboard" ci
  as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
    npm --prefix "$PLATFORM_ROOT/apps/presentation/coding-dashboard" install --no-package-lock
fi

log "Run installation health checks"
set +e
as_user env HOME="$TARGET_HOME" PATH="$USER_BIN:/usr/local/bin:/usr/bin:/bin" \
  AI_CODING_NODE_ROLE="$ROLE" \
  AI_CODING_PLATFORM_ROOT="$PLATFORM_ROOT" \
  AI_CODING_PROJECTS_ROOT="$PROJECTS_ROOT" \
  AI_CODING_SCRATCH_ROOT="$SCRATCH_ROOT" \
  AI_CODING_QWEN_MCP_PYTHON="$QWEN_MCP_PYTHON" \
  bash "$PLATFORM_ROOT/scripts/ai-coding-doctor.sh"
doctor_rc=$?
set -e

cat <<EOF

AI-Coding node bootstrap finished.

Node role:        $ROLE
Runtime user:     $TARGET_USER
Platform:         $PLATFORM_ROOT
Projects:         $PROJECTS_ROOT
Scratch:          $SCRATCH_ROOT
LoopX Dashboard:  127.0.0.1:8767
Coding Dashboard: 127.0.0.1:8768

Interactive authentication is intentionally not automated:
  1. Codex:     codex   (or codex login, then verify with: codex login status)
  2. Qwen Code: qwen    then use /auth
  3. Kiro CLI:  kiro-cli and complete its sign-in flow

After authentication, run:
  source ~/.config/ai-coding/env.sh
  ai-coding-doctor

The bootstrap does NOT create or mutate project Goal/Todo state.
EOF

if [[ "$doctor_rc" -ne 0 ]]; then
  warn "bootstrap completed, but ai-coding-doctor still reports required failures"
  exit "$doctor_rc"
fi
