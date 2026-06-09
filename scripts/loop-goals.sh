#!/usr/bin/env bash
# Local test loop without k8s (same logic as pod entrypoint).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GOAL_AGENTS_ROOT="$ROOT"
export GOAL_REPO_ROOT="${GOAL_REPO_ROOT:-$(pwd)}"
exec "$ROOT/scripts/local-goal-loop.sh"
