#!/usr/bin/env bash
# Always-on goal loop: git sync → advance goal → Ollama → verify → commit → gate check.
set -euo pipefail

AGENTS_ROOT="${GOAL_AGENTS_ROOT:-/app}"
REPO_ROOT="${GOAL_REPO_ROOT:-/workspace/repo}"
BRANCH="${GOAL_START_REF:-main}"
REPO_URL="${GOAL_REPO_URL:?GOAL_REPO_URL required}"
SLEEP_SEC="${GOAL_LOOP_SLEEP_SEC:-120}"
EXIT_ON_COMPLETE="${GOAL_EXIT_ON_COMPLETE:-1}"
GOAL_SPRINT_MD="${GOAL_SPRINT_MD:-}"
GOALS_YAML="${GOALS_YAML:-goals.yaml}"
GOAL_PLAN="${GOAL_PLAN:-}"

git_sync() {
  if [[ -d "${REPO_ROOT}/.git" ]]; then
    git -C "$REPO_ROOT" fetch origin
    git -C "$REPO_ROOT" checkout "$BRANCH" 2>/dev/null || git -C "$REPO_ROOT" checkout -B "$BRANCH" "origin/${BRANCH}"
    git -C "$REPO_ROOT" pull --rebase origin "$BRANCH" || true
  else
    mkdir -p "$(dirname "$REPO_ROOT")"
    local token="${GH_TOKEN:-}"
    local url="$REPO_URL"
    if [[ -n "$token" && "$url" == https://* ]]; then
      url="https://x-access-token:${token}@${url#https://}"
    fi
    git clone --branch "$BRANCH" --depth 1 "$url" "$REPO_ROOT" || git clone "$url" "$REPO_ROOT"
    git -C "$REPO_ROOT" checkout "$BRANCH" 2>/dev/null || true
  fi
  echo "local-goal-loop: synced ${REPO_ROOT} @ $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
}

run_yaml_goal_iteration() {
  local next
  next="$("${AGENTS_ROOT}/scripts/advance-goal.sh" "$REPO_ROOT" 2>/dev/null || true)"
  if [[ "$next" == "ALL_DONE" ]]; then
    echo "GOAL_COMPLETE"
    return 0
  fi
  if [[ -z "$next" || "$next" == "NONE" ]]; then
    echo "GOAL_INCOMPLETE: no pending goals"
    return 1
  fi
  echo "local-goal-loop: running goal ${next}"
  GOAL_ID="$next" REPO_ROOT="$REPO_ROOT" "${AGENTS_ROOT}/scripts/ollama-run-goal.sh" || return 1
  return 1
}

run_markdown_sprint_iteration() {
  local sprint_file="${REPO_ROOT}/${GOAL_SPRINT_MD}"
  if [[ ! -f "$sprint_file" ]]; then
    echo "local-goal-loop: missing sprint file ${sprint_file}" >&2
    return 1
  fi
  GOAL_ID="sprint" GOAL_SPRINT_MD="$GOAL_SPRINT_MD" REPO_ROOT="$REPO_ROOT" \
    "${AGENTS_ROOT}/scripts/ollama-run-goal.sh" || return 1
  if "${AGENTS_ROOT}/scripts/goal-completion-gate.sh" "$sprint_file" "$REPO_ROOT"; then
    echo "GOAL_COMPLETE"
    return 0
  fi
  echo "GOAL_INCOMPLETE"
  return 1
}

check_all_yaml_done() {
  local status
  status="$("${AGENTS_ROOT}/scripts/advance-goal.sh" "$REPO_ROOT" --status 2>/dev/null || echo pending)"
  if [[ "$status" == "ALL_DONE" ]]; then
    echo "GOAL_COMPLETE"
    return 0
  fi
  return 1
}

echo "local-goal-loop: started repo=${REPO_URL} branch=${BRANCH} ollama=${OLLAMA_URL:-http://127.0.0.1:11434}"

while true; do
  git_sync
  result="GOAL_INCOMPLETE"
  if [[ -n "$GOAL_SPRINT_MD" ]]; then
    if run_markdown_sprint_iteration; then result="GOAL_COMPLETE"; fi
  else
    if run_yaml_goal_iteration; then
      result="GOAL_COMPLETE"
    elif check_all_yaml_done; then
      result="GOAL_COMPLETE"
    fi
  fi

  if [[ "$result" == "GOAL_COMPLETE" ]]; then
    echo "local-goal-loop: program complete — all gates passed"
    if [[ "$EXIT_ON_COMPLETE" == "1" ]]; then
      exit 0
    fi
  fi

  echo "local-goal-loop: sleeping ${SLEEP_SEC}s"
  sleep "$SLEEP_SEC"
done
