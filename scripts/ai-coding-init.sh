#!/usr/bin/env bash
set -euo pipefail

# Canonical fresh-machine initializer for the AI-Coding platform.
# Target: Ubuntu 24.04 PDS / PDS-Lab.
#
# Machine bootstrap only: creates the gany development identity, /project
# workspace, stable LoopX 1.0 runtime and coding-tool surfaces. External account
# authentication and project Goal/Todo state remain explicit follow-up steps.

ROLE="pds"
DEV_USER="gany"
PROJECT_ROOT="/project"
PLATFORM_REPO="https://github.com/zkzchb/loopx.git"
PLATFORM_BRANCH="platform"
BASELINE_LABEL="1.0"
RESET_PASSWORD=0
SKIP_TOOL_INSTALL=0
GIT_NETWORK_RETRIES=4

usage() {
  cat <<'USAGE'
Usage: ai-coding-init.sh [options]

Options:
  --role pds|pds-lab       Node role (default: pds)
  --user USER              Development user (default: gany)
  --project-root PATH      Canonical Git workspace (default: /project)
  --baseline-label LABEL   Stable baseline label (default: 1.0)
  --reset-password         Prompt to reset the development user's password
  --skip-tool-install      Skip Codex/Qwen/Kiro installers
  -h, --help               Show this help

Run as root on a freshly reset Ubuntu host. The Unix password for the
development user is entered interactively on /dev/tty and is never stored.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:?missing role}"; shift 2 ;;
    --user) DEV_USER="${2:?missing user}"; shift 2 ;;
    --project-root) PROJECT_ROOT="${2:?missing project root}"; shift 2 ;;
    --baseline-label) BASELINE_LABEL="${2:?missing baseline label}"; shift 2 ;;
    --reset-password) RESET_PASSWORD=1; shift ;;
    --skip-tool-install) SKIP_TOOL_INSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$ROLE" != "pds" && "$ROLE" != "pds-lab" ]]; then
  echo "--role must be pds or pds-lab" >&2
  exit 2
fi
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this initializer as root." >&2
  exit 1
fi
if [[ ! "$DEV_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "unsafe development username: $DEV_USER" >&2
  exit 2
fi
if [[ ! "$BASELINE_LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "unsafe baseline label: $BASELINE_LABEL" >&2
  exit 2
fi

PLATFORM_ROOT="${PROJECT_ROOT%/}/loopx"
log() { printf '\n==> %s\n' "$*"; }

log "Install operating-system prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  sudo ca-certificates curl git git-lfs gh jq unzip xz-utils rsync \
  build-essential python3 python3-venv python3-pip python3-pytest \
  openssh-client lsof tmux

git lfs install --system >/dev/null 2>&1 || true

node_major=0
if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
fi
if [[ ! "$node_major" =~ ^[0-9]+$ ]] || (( node_major < 22 )); then
  log "Install Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

log "Create canonical development identity: $DEV_USER"
new_user=0
if ! id "$DEV_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEV_USER"
  new_user=1
fi
usermod -aG sudo "$DEV_USER"
DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
DEV_GROUP="$(id -gn "$DEV_USER")"

if [[ "$new_user" == "1" || "$RESET_PASSWORD" == "1" ]]; then
  if [[ ! -c /dev/tty ]]; then
    echo "A controlling TTY is required to set the $DEV_USER password." >&2
    exit 1
  fi
  echo
  echo "Set the Unix password for '$DEV_USER'. This password is not stored."
  passwd "$DEV_USER" </dev/tty >/dev/tty
fi

log "Create canonical Git workspace: $PROJECT_ROOT"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$PROJECT_ROOT"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$PROJECT_ROOT/.scratch"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$DEV_HOME/.local/bin"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$DEV_HOME/.config/ai-coding"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$DEV_HOME/.local/share/ai-coding"
install -d -m 0755 -o "$DEV_USER" -g "$DEV_GROUP" "$DEV_HOME/.local/share/loopx/releases"

# Preserve the cloud/VPS SSH access path without enabling password SSH. If the
# account that launched bootstrap already has authorized_keys and gany does not,
# copy that key set with strict ownership/modes.
ssh_source_home="/root"
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && id "$SUDO_USER" >/dev/null 2>&1; then
  ssh_source_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi
if [[ -s "$ssh_source_home/.ssh/authorized_keys" && ! -s "$DEV_HOME/.ssh/authorized_keys" ]]; then
  log "Copy existing SSH public-key access to $DEV_USER"
  install -d -m 0700 -o "$DEV_USER" -g "$DEV_GROUP" "$DEV_HOME/.ssh"
  install -m 0600 -o "$DEV_USER" -g "$DEV_GROUP" \
    "$ssh_source_home/.ssh/authorized_keys" "$DEV_HOME/.ssh/authorized_keys"
fi

as_gany() {
  sudo -u "$DEV_USER" -H env \
    HOME="$DEV_HOME" USER="$DEV_USER" LOGNAME="$DEV_USER" \
    PATH="$DEV_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    "$@"
}

gany_shell() {
  sudo -u "$DEV_USER" -H env HOME="$DEV_HOME" USER="$DEV_USER" LOGNAME="$DEV_USER" \
    bash -lc "export PATH='$DEV_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:\$PATH'; $*"
}

retry_delay() {
  local attempt="$1"
  local delay=$((3 * (1 << (attempt - 1))))
  (( delay > 24 )) && delay=24
  printf '%s' "$delay"
}

clone_platform_checkout() {
  local attempt delay
  for ((attempt=1; attempt<=GIT_NETWORK_RETRIES; attempt++)); do
    rm -rf "$PLATFORM_ROOT"
    if as_gany git clone \
      --filter=blob:none \
      --no-tags \
      --branch "$PLATFORM_BRANCH" \
      "$PLATFORM_REPO" "$PLATFORM_ROOT"; then
      return 0
    fi
    if (( attempt == GIT_NETWORK_RETRIES )); then
      break
    fi
    delay="$(retry_delay "$attempt")"
    echo "WARNING: Git clone attempt $attempt/$GIT_NETWORK_RETRIES failed; retrying in ${delay}s." >&2
    sleep "$delay"
  done
  echo "Failed to clone $PLATFORM_REPO after $GIT_NETWORK_RETRIES attempts." >&2
  return 1
}

fetch_platform_refs() {
  local attempt delay
  for ((attempt=1; attempt<=GIT_NETWORK_RETRIES; attempt++)); do
    if as_gany git -C "$PLATFORM_ROOT" fetch \
      --filter=blob:none \
      --no-tags \
      --prune \
      origin \
      +refs/heads/main:refs/remotes/origin/main \
      +refs/heads/platform:refs/remotes/origin/platform; then
      return 0
    fi
    if (( attempt == GIT_NETWORK_RETRIES )); then
      break
    fi
    delay="$(retry_delay "$attempt")"
    echo "WARNING: Git fetch attempt $attempt/$GIT_NETWORK_RETRIES failed; retrying in ${delay}s." >&2
    sleep "$delay"
  done
  echo "Failed to fetch main/platform after $GIT_NETWORK_RETRIES attempts." >&2
  return 1
}

log "Configure conservative Git defaults"
as_gany git config --global init.defaultBranch main
as_gany git config --global pull.ff only
as_gany git config --global fetch.prune true
as_gany git config --global credential.helper ""

log "Clone/update AI-Coding development checkout at $PLATFORM_ROOT"
if [[ ! -d "$PLATFORM_ROOT/.git" ]]; then
  clone_platform_checkout
else
  if [[ -n "$(as_gany git -C "$PLATFORM_ROOT" status --porcelain)" ]]; then
    echo "$PLATFORM_ROOT has local changes; refusing to overwrite it." >&2
    exit 1
  fi
fi
fetch_platform_refs
as_gany git -C "$PLATFORM_ROOT" checkout "$PLATFORM_BRANCH"
as_gany git -C "$PLATFORM_ROOT" merge --ff-only "origin/$PLATFORM_BRANCH"

if [[ "$SKIP_TOOL_INSTALL" != "1" ]]; then
  log "Install Codex CLI for $DEV_USER"
  if ! gany_shell 'command -v codex >/dev/null 2>&1'; then
    gany_shell 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
  fi

  log "Install Qwen Code CLI for $DEV_USER"
  if ! gany_shell 'command -v qwen >/dev/null 2>&1'; then
    gany_shell 'curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash'
  fi

  log "Install Kiro CLI for $DEV_USER"
  if ! gany_shell 'command -v kiro-cli >/dev/null 2>&1'; then
    gany_shell 'curl -fsSL https://cli.kiro.dev/install | bash'
  fi
fi

log "Write canonical node environment"
cat >"$DEV_HOME/.config/ai-coding/env.sh" <<EOF_ENV
# Generated by ai-coding-init.sh
export PATH="$DEV_HOME/.local/bin:\$PATH"
export AI_CODING_NODE_ROLE="$ROLE"
export AI_CODING_DEV_USER="$DEV_USER"
export AI_CODING_PROJECT_ROOT="$PROJECT_ROOT"
export AI_CODING_PROJECTS_ROOT="$PROJECT_ROOT"
export AI_CODING_SCRATCH_ROOT="$PROJECT_ROOT/.scratch"
export AI_CODING_PLATFORM_ROOT="$PLATFORM_ROOT"
export AI_CODING_LOOPX_RELEASES_ROOT="$DEV_HOME/.local/share/loopx/releases"
export AI_CODING_QWEN_MCP_RELEASES_ROOT="$DEV_HOME/.local/share/ai-coding/qwen-mcp/releases"
export LOOPX_RELEASES_DIR="$DEV_HOME/.local/share/loopx/releases"
export AI_CODING_LOOPX_DASHBOARD_HOST="127.0.0.1"
export AI_CODING_LOOPX_DASHBOARD_PORT="8767"
export AI_CODING_DASHBOARD_HOST="127.0.0.1"
export AI_CODING_DASHBOARD_PORT="8768"
export AI_CODING_QWEN_AGENT_ID="qwen-code"
export CODEX_HOME="$DEV_HOME/.codex"
export KIRO_HOME="$DEV_HOME/.kiro"
[ -f "$DEV_HOME/.config/ai-coding/runtime.env" ] && . "$DEV_HOME/.config/ai-coding/runtime.env"
EOF_ENV
chown "$DEV_USER:$DEV_GROUP" "$DEV_HOME/.config/ai-coding/env.sh"
chmod 0644 "$DEV_HOME/.config/ai-coding/env.sh"

cat >"$DEV_HOME/.config/ai-coding/node.env" <<EOF_NODE
AI_CODING_NODE_ROLE="$ROLE"
AI_CODING_DEV_USER="$DEV_USER"
AI_CODING_PROJECT_ROOT="$PROJECT_ROOT"
EOF_NODE
chown "$DEV_USER:$DEV_GROUP" "$DEV_HOME/.config/ai-coding/node.env"
chmod 0644 "$DEV_HOME/.config/ai-coding/node.env"

profile_line='[ -f "$HOME/.config/ai-coding/env.sh" ] && . "$HOME/.config/ai-coding/env.sh"'
for profile in "$DEV_HOME/.bashrc" "$DEV_HOME/.profile"; do
  touch "$profile"
  chown "$DEV_USER:$DEV_GROUP" "$profile"
  if ! grep -Fqx "$profile_line" "$profile"; then
    printf '%s\n' "$profile_line" >>"$profile"
  fi
done

log "Install immutable LoopX stable baseline from the development checkout"
source_commit="$(as_gany git -C "$PLATFORM_ROOT" rev-parse HEAD)"
short_commit="${source_commit:0:12}"
release_id="ai-coding-${BASELINE_LABEL}-${short_commit}"
as_gany env \
  HOME="$DEV_HOME" \
  PATH="$DEV_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
  CODEX_HOME="$DEV_HOME/.codex" \
  LOOPX_BIN_DIR="$DEV_HOME/.local/bin" \
  LOOPX_RELEASES_DIR="$DEV_HOME/.local/share/loopx/releases" \
  LOOPX_RELEASE_ID="$release_id" \
  LOOPX_PROMOTE_DEFAULT=1 \
  LOOPX_INSTALL_SLASH_COMMANDS=0 \
  bash "$PLATFORM_ROOT/scripts/install-local.sh"

loopx_target="$(readlink -f "$DEV_HOME/.local/bin/loopx" 2>/dev/null || true)"
if [[ -z "$loopx_target" || "$loopx_target" != */scripts/loopx ]]; then
  echo "Unable to resolve promoted LoopX stable runtime." >&2
  exit 1
fi
ACTIVE_RELEASE="$(dirname "$(dirname "$loopx_target")")"
if [[ ! -x "$ACTIVE_RELEASE/scripts/ai-coding-bind-runtime.sh" ]]; then
  echo "Stable release is missing AI-Coding runtime binder." >&2
  exit 1
fi

log "Bind Codex/Kiro/Qwen/helper surfaces to the stable release"
gany_shell "'$ACTIVE_RELEASE/scripts/ai-coding-bind-runtime.sh' --release '$ACTIVE_RELEASE'"

log "Install both Dashboard dependency trees for development/validation"
as_gany env HOME="$DEV_HOME" PATH="$DEV_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
  npm --prefix "$PLATFORM_ROOT/apps/presentation/dashboard" ci
as_gany env HOME="$DEV_HOME" PATH="$DEV_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
  npm --prefix "$PLATFORM_ROOT/apps/presentation/coding-dashboard" install

log "Write canonical Agent inventory"
codex_bin="$(gany_shell 'command -v codex || true')"
qwen_bin="$(gany_shell 'command -v qwen || true')"
kiro_bin="$(gany_shell 'command -v kiro-cli || true')"
cat >"$DEV_HOME/.config/ai-coding/agents.json" <<EOF_AGENTS
{
  "schema_version": "ai_coding_node_agents_v0",
  "node_role": "$ROLE",
  "development_user": "$DEV_USER",
  "project_root": "$PROJECT_ROOT",
  "platform_root": "$PLATFORM_ROOT",
  "stable_loopx_release": "$ACTIVE_RELEASE",
  "agents": {
    "codex": {
      "binary": "$codex_bin",
      "loopx_integration": "upstream",
      "loopx_agent_type": "codex-cli",
      "role": "primary_interaction_planning_review"
    },
    "kiro": {
      "binary": "$kiro_bin",
      "loopx_integration": "upstream",
      "loopx_agent_type": "kiro-cli",
      "role": "secondary_planning_execution"
    },
    "qwen-code": {
      "binary": "$qwen_bin",
      "loopx_integration": "ai_coding_extension",
      "loopx_runtime_profile": "generic_cli",
      "registered_agent_id": "qwen-code",
      "mcp_server": "loopx-ai-coding",
      "role": "worker"
    }
  }
}
EOF_AGENTS
chown "$DEV_USER:$DEV_GROUP" "$DEV_HOME/.config/ai-coding/agents.json"
chmod 0644 "$DEV_HOME/.config/ai-coding/agents.json"

log "Machine initialization complete"
printf '%s\n' \
  "role:              $ROLE" \
  "development user:  $DEV_USER" \
  "Git workspace:     $PROJECT_ROOT" \
  "development LoopX: $PLATFORM_ROOT" \
  "stable LoopX:      $ACTIVE_RELEASE" \
  "sudo:              enabled (password required)" \
  "GitHub CLI:         $(command -v gh)"

cat <<EOF_NEXT

Next:
  su - $DEV_USER

Authenticate interactively as $DEV_USER:
  gh auth login
  codex login
  qwen
  kiro-cli

Then verify:
  ai-coding-doctor
  ai-coding-loopx status

All future Git repositories belong under:
  $PROJECT_ROOT/<repository-name>

The development checkout at $PLATFORM_ROOT is NOT the stable runtime. Editing it
will not change the active LoopX/Qwen MCP/doctor surfaces until an explicit
validate + promote cycle succeeds.
EOF_NEXT
