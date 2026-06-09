#!/usr/bin/env bash
# Create/update goal-agent-secrets from GH_TOKEN env.
set -euo pipefail

require_gh_token() {
  if [[ -z "${GH_TOKEN:-}" ]]; then
    echo "ERROR: GH_TOKEN is required for private repo clone/push." >&2
    return 1
  fi
}

apply_goal_secrets() {
  local ns="${1:-goal-workers}"
  kubectl -n "$ns" create secret generic goal-agent-secrets \
    --from-literal=GH_TOKEN="${GH_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "Applied secret goal-agent-secrets in ${ns}"
}
