---
workflow_repo: my-repo
branch: cursor/my-sprint
plan: docs/plans/my-plan.md
---

# My sprint — goal-directed worker

**Branch:** `cursor/my-sprint`  
**Agent:** local Ollama (`qwen3.5:9b`)

## Mission

Implement the plan in `docs/plans/my-plan.md` until the completion gate passes.

## Phase checklist

| Phase | Deliverable | Status | Gate |
|-------|-------------|--------|------|
| P1 | Module extraction | pending | `check-phase1-gate.sh` |
| P2 | Tests green | pending | `check-phase2-gate.sh` |

## Completion gate

```bash
bash scripts/check-my-sprint-gate.sh
```
