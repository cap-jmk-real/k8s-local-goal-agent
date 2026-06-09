#!/usr/bin/env bash
# Resolve next incomplete goal from goals.yaml (minimal parser, no node deps).
set -euo pipefail

REPO_ROOT="${1:-.}"
STATUS_ONLY=false
if [[ "${2:-}" == "--status" ]]; then STATUS_ONLY=true; fi

GOALS_YAML="${GOALS_YAML:-goals.yaml}"
PROGRESS_JSON="${PROGRESS_JSON:-.goal-progress.json}"
GOAL_FILE="${REPO_ROOT}/${GOALS_YAML}"
PROGRESS_FILE="${REPO_ROOT}/${PROGRESS_JSON}"

if [[ ! -f "$GOAL_FILE" ]]; then
  echo "NONE"
  exit 0
fi

last_done=""
if [[ -f "$PROGRESS_FILE" ]]; then
  last_done="$(grep -o '"last_completed_goal"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROGRESS_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
  if [[ "$last_done" == "null" ]]; then last_done=""; fi
fi

mapfile -t ids < <(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*' "$GOAL_FILE" | sed -E 's/^[[:space:]]*-[[:space:]]*id:[[:space:]]*//; s/[[:space:]]*$//')

if [[ ${#ids[@]} -eq 0 ]]; then
  echo "NONE"
  exit 0
fi

found_last=false
for id in "${ids[@]}"; do
  if [[ -z "$last_done" ]]; then
    if $STATUS_ONLY; then echo "pending"; else echo "$id"; fi
    exit 0
  fi
  if $found_last; then
    if $STATUS_ONLY; then echo "pending"; else echo "$id"; fi
    exit 0
  fi
  if [[ "$id" == "$last_done" ]]; then
    found_last=true
  fi
done

if $found_last; then
  echo "ALL_DONE"
else
  if $STATUS_ONLY; then echo "pending"; else echo "${ids[0]}"; fi
fi
