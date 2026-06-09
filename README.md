# k8s-local-goal-agent

**Homelab goal-directed agent loop** — offload autonomous implementation to your Kubernetes cluster using **local Ollama/Qwen**, not the Cursor cloud SDK.

Generalized from the [li-langverse homelab pattern](https://gitlab.lilangverse.xyz/li-langverse/li-cursor-agents) (`homelab-goal-directed-k8s-worker` skill) and [majico](https://github.com/cap-jmk-launchpad/majico.xyz) goal YAML backlogs.

## vs [cursor-goal-loop](https://github.com/cap-jmk-real/cursor-goal-loop)

| | **k8s-local-goal-agent** (this repo) | **cursor-goal-loop** |
|---|---|---|
| **Runtime** | Ollama/Qwen on your cluster | `@cursor/sdk` → Cursor cloud |
| **Cost** | Homelab GPU/CPU only | Cursor API usage |
| **K8s role** | Worker runs inference + git loop | Job only clones repo + calls cloud API |
| **Network** | In-cluster; no egress to Cursor | Needs egress + `CURSOR_API_KEY` |
| **Goal format** | YAML backlog **or** markdown sprint + bash gate | YAML backlog |
| **Best for** | Staging/homelab sprints, cost-sensitive eval | High-quality cloud agents, CI CronJobs |

Use **cursor-goal-loop** when you want Cursor cloud agents. Use **k8s-local-goal-agent** when you want agents on blackpearl/engine with Ollama.

## Quick start

```bash
git clone https://github.com/cap-jmk-real/k8s-local-goal-agent.git
cd k8s-local-goal-agent
```

### 1. Author goals in your target repo

Copy `templates/goals.example.yaml` → `goals.yaml` (or `templates/goal-sprint.example.md` for li-style markdown gates).

### 2. Configure consumer

Copy `examples/majico-refactor/consumer.yaml` and edit repo URL, branch, plan path.

### 3. Deploy on homelab (blackpearl / engine)

```bash
export KUBECONFIG=~/.kube/config   # blackpearl k3s or engine homelab
export GH_TOKEN=...                  # clone private repos
export OLLAMA_URL=http://ollama.majico-staging.svc.cluster.local:11434
export GOAL_REPO_URL=https://github.com/cap-jmk-launchpad/majico.xyz.git
export GOAL_START_REF=cursor/refactor-canvas-worker
export GOAL_PLAN=docs/internal/plans/refactor-canvas-worker-1000lc.md
export GOALS_YAML=scripts/agents/goals/refactor-canvas-worker-1000lc.yaml
export K8S_NAMESPACE=majico-staging
export GOAL_WORKER_NAME=majico-refactor-goal

bash scripts/setup-homelab-goal-worker.sh
```

### 4. Watch until done

```bash
kubectl -n majico-staging logs -f deploy/majico-refactor-goal
kubectl -n majico-staging scale deploy/majico-refactor-goal --replicas=0  # after GOAL_COMPLETE
```

## Blackpearl deploy (majico staging)

On `blackpearl` (`192.168.10.41`) after k3s is up ([majico runbook](https://github.com/cap-jmk-launchpad/majico.xyz/blob/main/deploy/staging/docs/blackpearl-k8s-lis.md)):

```bash
cd ~/staging/k8s-local-goal-agent
export GH_TOKEN="$(grep GH_TOKEN ~/staging/secrets/.env.staging | cut -d= -f2-)"
export OLLAMA_URL=http://ollama.majico-staging.svc.cluster.local:11434
export GOAL_REPO_URL=https://github.com/cap-jmk-launchpad/majico.xyz.git
export GOAL_START_REF=main
export GOAL_PLAN=docs/plans/canvas-human-touch.md
export GOALS_YAML=scripts/agents/goals/canvas-human-touch.yaml
export K8S_NAMESPACE=majico-staging
export GOAL_WORKER_NAME=majico-canvas-goal

bash scripts/setup-homelab-goal-worker.sh
```

Prerequisites: Ollama deployed in `majico-staging` (`k8s/ollama.deployment.yaml` or majico staging overlay).

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GOAL_REPO_URL` | — | Target git repo (required) |
| `GOAL_START_REF` | `main` | Branch to sync |
| `GOAL_PLAN` | — | Markdown plan path in repo |
| `GOALS_YAML` | `goals.yaml` | YAML backlog path in repo |
| `GOAL_SPRINT_MD` | — | Alternative: markdown sprint with `## Completion gate` |
| `PROGRESS_JSON` | `.goal-progress.json` | Resume state path in repo |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Ollama HTTP base |
| `OLLAMA_MODEL` | `qwen3.5:9b` | Model tag |
| `GOAL_LOOP_SLEEP_SEC` | `120` | Pause between iterations |
| `GOAL_EXIT_ON_COMPLETE` | `1` | Exit pod when all goals pass |
| `GOAL_WORKER_NAME` | `local-goal-agent` | Deployment name |
| `K8S_NAMESPACE` | `goal-workers` | K8s namespace |
| `GH_TOKEN` | — | Git clone/push (private repos) |

## Repo layout

```
├── README.md
├── SKILL.md
├── scripts/
│   ├── setup-homelab-goal-worker.sh   # apply namespace, PVC, secrets, deployment
│   ├── apply-goal-secrets.sh
│   ├── local-goal-loop.sh            # always-on loop (git sync → ollama → verify → commit)
│   ├── goal-completion-gate.sh       # run bash gate from markdown sprint
│   ├── advance-goal.sh               # resolve next YAML goal
│   ├── ollama-run-goal.sh            # one Ollama inference for current goal
│   └── loop-goals.sh                 # local test without k8s
├── templates/
│   ├── goals.example.yaml
│   ├── goal-sprint.example.md
│   ├── progress.example.json
│   └── consumer.example.yaml
├── k8s/
│   ├── namespace.yaml
│   ├── pvc-workspace.yaml
│   ├── configmap.template.yaml
│   ├── deployment.template.yaml
│   ├── job.template.yaml
│   ├── ollama.deployment.yaml
│   └── secret.example.yaml
└── examples/majico-refactor/
    ├── consumer.yaml
    └── goals.yaml
```

## Goal formats

### YAML backlog (cursor-goal-loop compatible)

See `templates/goals.example.yaml`. Worker advances goals in order, runs `verify_commands`, commits with `[goal:<id>]`.

### Markdown sprint (li-langverse compatible)

See `templates/goal-sprint.example.md`. Worker loops until the bash block under `## Completion gate` exits 0.

## Anti-patterns

- **Sharing one PVC across concurrent workers** — branch checkout races
- **Using this package with `CURSOR_API_KEY`** — that is cursor-goal-loop's job
- **Applying cloud-sdk K8s jobs alongside** — suspend `infra/k8s/jobs/goal-directed-agent.job.yaml` in consumer repos

## License

MIT
