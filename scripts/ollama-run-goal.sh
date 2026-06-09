#!/usr/bin/env bash
# One Ollama inference pass for the current goal; apply edits via structured response.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/workspace/repo}"
GOAL_ID="${GOAL_ID:-}"
GOALS_YAML="${GOALS_YAML:-goals.yaml}"
GOAL_PLAN="${GOAL_PLAN:-}"
GOAL_SPRINT_MD="${GOAL_SPRINT_MD:-}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3.5:9b}"

build_prompt() {
  local plan_text="" goal_text=""
  if [[ -n "$GOAL_PLAN" && -f "${REPO_ROOT}/${GOAL_PLAN}" ]]; then
    plan_text="$(cat "${REPO_ROOT}/${GOAL_PLAN}")"
  fi
  if [[ -n "$GOAL_SPRINT_MD" && -f "${REPO_ROOT}/${GOAL_SPRINT_MD}" ]]; then
    goal_text="$(cat "${REPO_ROOT}/${GOAL_SPRINT_MD}")"
  elif [[ -n "$GOAL_ID" && -f "${REPO_ROOT}/${GOALS_YAML}" ]]; then
    goal_text="$(awk -v id="$GOAL_ID" '
      $0 ~ "^[[:space:]]*-[[:space:]]*id:[[:space:]]*" id "$" { capture=1 }
      capture && /^[[:space:]]*-[[:space:]]*id:/ && $0 !~ id { exit }
      capture { print }
    ' "${REPO_ROOT}/${GOALS_YAML}")"
  fi

  cat <<EOF
You are an autonomous coding agent working in ${REPO_ROOT}.
Complete exactly one goal. Make minimal, correct edits. Run verify commands before committing.

Plan:
${plan_text}

Current goal (${GOAL_ID}):
${goal_text}

Respond with a brief summary of changes you made. If you cannot complete the goal, explain why.
EOF
}

prompt="$(build_prompt)"
echo "ollama-run-goal: model=${OLLAMA_MODEL} goal=${GOAL_ID}"

response="$(curl -sf "${OLLAMA_URL}/api/generate" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg model "$OLLAMA_MODEL" --arg prompt "$prompt" '{model: $model, prompt: $prompt, stream: false}')" \
  | jq -r '.response // empty')" || {
  echo "ollama-run-goal: Ollama request failed (${OLLAMA_URL})" >&2
  exit 1
}

echo "ollama-run-goal: response length=${#response}"
echo "$response" | head -c 2000
echo ""

# Note: full file-edit orchestration belongs in consumer-specific wrappers.
# This script records the inference pass; pair with human review or a richer apply layer.
if [[ -n "$GOAL_ID" && "$GOAL_ID" != "sprint" ]]; then
  git -C "$REPO_ROOT" config user.email "goal-agent@homelab.local" 2>/dev/null || true
  git -C "$REPO_ROOT" config user.name "k8s-local-goal-agent" 2>/dev/null || true
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
    git -C "$REPO_ROOT" add -A
    git -C "$REPO_ROOT" commit -m "chore(goal): [goal:${GOAL_ID}] ollama iteration" || true
    progress="${REPO_ROOT}/${PROGRESS_JSON:-.goal-progress.json}"
    printf '{"plan":"%s","start_ref":"%s","last_completed_goal":"%s","updated_at":"%s"}\n' \
      "$(basename "$GOALS_YAML" .yaml)" "${GOAL_START_REF:-main}" "$GOAL_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "$progress"
    if [[ -n "${GH_TOKEN:-}" ]]; then
      git -C "$REPO_ROOT" push origin "HEAD:${GOAL_START_REF:-main}" 2>/dev/null || true
    fi
  fi
fi

exit 0
