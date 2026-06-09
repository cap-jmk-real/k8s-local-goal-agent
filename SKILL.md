---
name: k8s-local-goal-agent
description: >-
  Deploy always-on goal-directed agents on homelab Kubernetes using Ollama/Qwen
  (not Cursor cloud SDK). YAML backlog or markdown sprint + completion gate.
  Use for majico refactors, li-style sprints on blackpearl/engine, or cost-sensitive
  local agent loops until verify gates pass.
---

# K8s local goal agent

Run goal sprints on **your** Kubernetes cluster with **Ollama/Qwen** until completion gates pass.

## When to use

- Homelab/blackpearl staging sprints without Cursor API cost
- Majico refactor backlogs (`goals.yaml` + plan markdown)
- Li-style markdown sprints with `## Completion gate` bash blocks
- Overnight always-on Deployment on engine/blackpearl

Do **not** use when you need Cursor cloud agent quality — use [cursor-goal-loop](https://github.com/cap-jmk-real/cursor-goal-loop) instead.

## Prerequisites

1. **kubeconfig:** homelab (`~/.kube/config-homelab`) or blackpearl k3s (`~/.kube/config`)
2. **Ollama** in-cluster or reachable (`OLLAMA_URL`)
3. **GH_TOKEN** for private repo clone/push
4. **Goal file** on branch: `goals.yaml` or `data/goal-directed-sprints/<sprint>.md`
5. **One PVC per concurrent sprint** (never share workspace PVCs)

## Deploy

```bash
git clone https://github.com/cap-jmk-real/k8s-local-goal-agent.git
cd k8s-local-goal-agent

export KUBECONFIG=~/.kube/config
export GH_TOKEN=...
export GOAL_REPO_URL=https://github.com/you/repo.git
export GOAL_START_REF=feature/my-sprint
export GOAL_PLAN=docs/plans/my-plan.md
export GOALS_YAML=goals.yaml
export K8S_NAMESPACE=majico-staging
export GOAL_WORKER_NAME=my-sprint-goal

bash scripts/setup-homelab-goal-worker.sh
```

## Verify

```bash
kubectl -n $K8S_NAMESPACE logs -f deploy/$GOAL_WORKER_NAME
kubectl -n $K8S_NAMESPACE exec deploy/$GOAL_WORKER_NAME -- test -f /workspace/repo/$GOALS_YAML
```

Healthy loop: git sync → `advance-goal` → Ollama run → verify → commit → sleep.

`GOAL_INCOMPLETE` between iterations is **expected** until gates pass.

On `GOAL_COMPLETE`, pod exits (when `GOAL_EXIT_ON_COMPLETE=1`). Scale to 0:

```bash
kubectl -n $K8S_NAMESPACE scale deploy/$GOAL_WORKER_NAME --replicas=0
```

## Consumer repos

| Repo | Example config |
|------|----------------|
| majico.xyz | `examples/majico-refactor/consumer.yaml` |
| lic sprints | Set `GOAL_SPRINT_MD=data/goal-directed-sprints/<sprint>.md` |

## Related

- Cloud agents: [cursor-goal-loop](https://github.com/cap-jmk-real/cursor-goal-loop)
- Li homelab workers: `homelab-goal-directed-k8s-worker` skill in li-cursor-agents
- Majico staging: `deploy/staging/docs/blackpearl-k8s-lis.md`
