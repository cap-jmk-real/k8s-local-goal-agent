#!/usr/bin/env bash
# Deploy always-on local goal worker (Ollama) on homelab k8s.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S="$ROOT/k8s"

: "${K8S_NAMESPACE:=goal-workers}"
: "${GOAL_WORKER_NAME:=local-goal-agent}"
: "${GOAL_REPO_URL:?GOAL_REPO_URL is required}"
: "${GOAL_START_REF:=main}"
: "${GOAL_PLAN:=}"
: "${GOALS_YAML:=goals.yaml}"
: "${GOAL_SPRINT_MD:=}"
: "${PROGRESS_JSON:=.goal-progress.json}"
: "${OLLAMA_URL:=http://ollama.majico-staging.svc.cluster.local:11434}"
: "${OLLAMA_MODEL:=qwen3.5:9b}"
: "${GOAL_LOOP_SLEEP_SEC:=120}"
: "${GOAL_EXIT_ON_COMPLETE:=1}"
: "${GOAL_MAX_PER_ITERATION:=1}"
: "${PVC_SIZE:=10Gi}"

if ! kubectl config current-context &>/dev/null; then
  echo "ERROR: kubectl has no current-context. Set KUBECONFIG." >&2
  exit 1
fi

# shellcheck source=apply-goal-secrets.sh
source "$ROOT/scripts/apply-goal-secrets.sh"
require_gh_token || exit 1

substitute() {
  sed \
    -e "s|__NAMESPACE__|${K8S_NAMESPACE}|g" \
    -e "s|__WORKER_NAME__|${GOAL_WORKER_NAME}|g" \
    -e "s|__PVC_NAME__|${GOAL_WORKER_NAME}-workspace|g" \
    -e "s|__PVC_SIZE__|${PVC_SIZE}|g" \
    -e "s|__REPO_URL__|${GOAL_REPO_URL}|g" \
    -e "s|__START_REF__|${GOAL_START_REF}|g" \
    -e "s|__GOAL_PLAN__|${GOAL_PLAN}|g" \
    -e "s|__GOALS_YAML__|${GOALS_YAML}|g" \
    -e "s|__GOAL_SPRINT_MD__|${GOAL_SPRINT_MD}|g" \
    -e "s|__PROGRESS_JSON__|${PROGRESS_JSON}|g" \
    -e "s|__OLLAMA_URL__|${OLLAMA_URL}|g" \
    -e "s|__OLLAMA_MODEL__|${OLLAMA_MODEL}|g" \
    -e "s|__LOOP_SLEEP_SEC__|${GOAL_LOOP_SLEEP_SEC}|g" \
    -e "s|__EXIT_ON_COMPLETE__|${GOAL_EXIT_ON_COMPLETE}|g" \
    -e "s|__MAX_PER_ITERATION__|${GOAL_MAX_PER_ITERATION}|g"
}

echo "==> context: $(kubectl config current-context)"
echo "==> namespace: ${K8S_NAMESPACE} worker: ${GOAL_WORKER_NAME}"

kubectl apply -f "$K8S/namespace.yaml" 2>/dev/null || kubectl create namespace "$K8S_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

substitute < "$K8S/pvc-workspace.yaml" | kubectl apply -f -
substitute < "$K8S/configmap.template.yaml" | kubectl apply -f -
kubectl -n "$K8S_NAMESPACE" create configmap "${GOAL_WORKER_NAME}-scripts" \
  --from-file="$ROOT/scripts/local-goal-loop.sh" \
  --from-file="$ROOT/scripts/advance-goal.sh" \
  --from-file="$ROOT/scripts/goal-completion-gate.sh" \
  --from-file="$ROOT/scripts/ollama-run-goal.sh" \
  --dry-run=client -o yaml | kubectl apply -f -
apply_goal_secrets "$K8S_NAMESPACE"
substitute < "$K8S/deployment.template.yaml" | kubectl apply -f -

kubectl -n "$K8S_NAMESPACE" rollout status "deploy/${GOAL_WORKER_NAME}" --timeout=180s || true
echo "Done. Worker runs until goal completion gate passes."
echo "Watch: kubectl -n ${K8S_NAMESPACE} logs -f deploy/${GOAL_WORKER_NAME}"
