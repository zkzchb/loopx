#!/usr/bin/env bash
set -euo pipefail

# Safe project-onboarding helper. Default mode is preview-only; --execute may
# create LoopX project state but still does not auto-select/take over an existing
# Goal or agent identity.

GOAL_TEXT=""
EXECUTE=0
HOST_SURFACE="codex-cli-tui"
PROJECT="."

usage() {
  cat <<'EOF'
Usage: ai-coding-project-init.sh --goal-text TEXT [options]

Options:
  --project PATH             Git project root (default: .)
  --goal-text TEXT           Intended project goal (required)
  --host-surface SURFACE     Initial visible host (default: codex-cli-tui)
  --execute                  Apply safe connect step after preview
  -h, --help                 Show help

This helper does not auto-takeover existing agents and does not automatically
claim Todo work. Qwen is registered later as the explicit peer id `qwen-code`
for Goals that should use the worker lane.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?missing value for --project}"; shift 2 ;;
    --goal-text) GOAL_TEXT="${2:?missing value for --goal-text}"; shift 2 ;;
    --host-surface) HOST_SURFACE="${2:?missing value for --host-surface}"; shift 2 ;;
    --execute) EXECUTE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${GOAL_TEXT// }" ]]; then
  echo "--goal-text is required" >&2
  exit 2
fi

PROJECT="$(cd "$PROJECT" && pwd)"
if ! git -C "$PROJECT" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "not a Git project: $PROJECT" >&2
  exit 1
fi

cd "$PROJECT"

echo "==> Read-only preflight"
git status --short --branch
loopx --version
loopx doctor

echo "==> LoopX connect preview"
loopx connect --dry-run

if [[ "$EXECUTE" == "1" ]]; then
  echo "==> Apply LoopX connect"
  loopx connect
else
  echo "==> Preview only; pass --execute to apply the safe connect step"
fi

echo "==> Guided goal transaction preview"
loopx start-goal \
  --guided \
  --project . \
  --goal-text "$GOAL_TEXT" \
  --host-surface "$HOST_SURFACE"

cat <<'EOF'

Next identity rule:
- Do not automatically take over an existing registered agent.
- Codex/Kiro use their exact upstream host types when selected.
- For a Goal that should use Qwen Code, explicitly register the public-safe
  peer id `qwen-code`; its MCP bridge refuses to bind unless that identity is
  registered on the selected Goal.
- Execute the guided transaction only after resolving any Goal/identity Gate.
EOF
