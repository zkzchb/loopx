#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="${LOOPX_UPSTREAM_URL:-https://github.com/huangruiteng/loopx.git}"
UPSTREAM_REMOTE="${LOOPX_UPSTREAM_REMOTE:-upstream}"
ORIGIN_REMOTE="${LOOPX_ORIGIN_REMOTE:-origin}"
PLATFORM_BRANCH="${LOOPX_PLATFORM_BRANCH:-platform}"
MAIN_BRANCH="${LOOPX_MAIN_BRANCH:-main}"
MODE="${1:-all}"

if [[ "$MODE" != "all" && "$MODE" != "main-only" && "$MODE" != "fetch-only" ]]; then
  echo "usage: $0 [all|main-only|fetch-only]" >&2
  exit 2
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "error: run this command inside the LoopX git checkout" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean; commit/stash changes before syncing" >&2
  exit 1
fi

ORIGINAL_BRANCH="$(git branch --show-current)"
if [[ -z "$ORIGINAL_BRANCH" ]]; then
  echo "error: detached HEAD is not supported by this helper" >&2
  exit 1
fi

if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  CURRENT_UPSTREAM="$(git remote get-url "$UPSTREAM_REMOTE")"
  if [[ "$CURRENT_UPSTREAM" != "$UPSTREAM_URL" ]]; then
    echo "error: remote '$UPSTREAM_REMOTE' already points to: $CURRENT_UPSTREAM" >&2
    echo "expected: $UPSTREAM_URL" >&2
    exit 1
  fi
else
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "==> fetching $UPSTREAM_REMOTE"
git fetch "$UPSTREAM_REMOTE" --prune

if [[ "$MODE" == "fetch-only" ]]; then
  echo "done: fetched upstream only"
  exit 0
fi

echo "==> fast-forwarding $MAIN_BRANCH from $UPSTREAM_REMOTE/$MAIN_BRANCH"
git switch "$MAIN_BRANCH"
git merge --ff-only "$UPSTREAM_REMOTE/$MAIN_BRANCH"
git push "$ORIGIN_REMOTE" "$MAIN_BRANCH"

if [[ "$MODE" == "main-only" ]]; then
  git switch "$ORIGINAL_BRANCH"
  echo "done: synchronized $MAIN_BRANCH"
  exit 0
fi

echo "==> integrating $MAIN_BRANCH into $PLATFORM_BRANCH"
git switch "$PLATFORM_BRANCH"
git merge --no-edit "$MAIN_BRANCH"

echo "==> platform now contains latest upstream; run compatibility smoke tests before pushing"

git switch "$ORIGINAL_BRANCH"
echo "done: upstream synchronized locally; platform merge is NOT pushed automatically"
