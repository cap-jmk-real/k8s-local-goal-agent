#!/usr/bin/env bash
# Run bash completion gate extracted from markdown sprint (## Completion gate section).
set -euo pipefail

GOAL_FILE="${1:?goal file required}"
GATE_CWD="${2:-.}"

if [[ ! -f "$GOAL_FILE" ]]; then
  echo "goal-completion-gate: missing ${GOAL_FILE}" >&2
  exit 1
fi

gate_script="$(mktemp)"
trap 'rm -f "$gate_script"' EXIT

awk '/^## Completion gate/{found=1; next} found && /^```bash/{inblock=1; next} inblock && /^```/{exit} inblock{print}' "$GOAL_FILE" > "$gate_script"

if [[ ! -s "$gate_script" ]]; then
  echo "goal-completion-gate: no bash gate in ${GOAL_FILE}" >&2
  exit 1
fi

chmod +x "$gate_script"
echo "goal-completion-gate: running gate in ${GATE_CWD}"
(cd "$GATE_CWD" && bash "$gate_script")
