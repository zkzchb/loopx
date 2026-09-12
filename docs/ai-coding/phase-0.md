# Phase 0 — Platform Bootstrap

## Goal

Prove that the downstream platform can preserve LoopX as the control plane while presenting a unified coding workflow across Codex, Kiro CLI, Qwen Code, and Claude Code.

## Exit criteria

Phase 0 is complete when:

- `main` remains usable as the upstream-sync branch;
- downstream work is isolated on `platform` and additive paths;
- Codex can complete a bounded task under LoopX control and emit normalized run/evidence data;
- Kiro CLI can do the same through its upstream integration;
- Claude Code can do the same through its upstream integration;
- Qwen Code has a downstream adapter and can complete the same class of smoke task;
- all four lanes can be represented through one Agent Run/read-model contract;
- a Coding Projection can expose project/task/run/evidence/telemetry facts without frontend dependence on private LoopX storage;
- upstream Dashboard can run independently on default port `8767`;
- downstream Coding Dashboard skeleton can run independently on default port `8768`;
- compatibility smoke tests exist for an upstream-sync cycle.

## Work packages

### P0-01 Upstream/fork discipline

Freeze branch roles, sync workflow, and conflict policy.

### P0-02 Downstream extension skeleton

Reserve `loopx/extensions/ai_coding/`, dashboard, docs, and test boundaries without changing kernel semantics.

### P0-03 Codex lane smoke

Validate the upstream Codex CLI/App path on the target Linux/PDS workflow and define the projection mapping.

### P0-04 Kiro lane smoke

Validate upstream Kiro CLI goal-mode behavior and projection mapping.

### P0-05 Claude Code lane smoke

Validate upstream Claude Code goal-mode/MCP behavior as the backup lane.

### P0-06 Qwen Code adapter

Research Qwen Code's current CLI/session/skill/MCP surfaces, implement the minimal downstream adapter, and make it satisfy the common Agent Run contract.

### P0-07 Agent Run + evidence model

Implement normalized run lifecycle and evidence references as a downstream projection over LoopX/host facts.

### P0-08 Telemetry foundation

Capture token usage, cached input/cache hit, runtime, retries, and cost when available. Unknown values remain unknown.

### P0-09 Coding Projection

Expose a stable read model for project/task/run/evidence/telemetry/evaluation consumers.

### P0-10 Dual dashboard runtime

Keep the upstream Dashboard untouched and add an independently runnable Coding Dashboard skeleton with configurable ports.

## Phase 0 implementation order

```text
P0-01 / P0-02
      |
      +--> P0-03 Codex
      +--> P0-04 Kiro
      +--> P0-05 Claude
      +--> P0-06 Qwen Code
                |
                v
          P0-07 Agent Run
                |
          P0-08 Telemetry
                |
          P0-09 Projection
                |
          P0-10 Dashboards
```

UI polish and advanced agent scoring are intentionally deferred until the execution/projection contracts are stable.