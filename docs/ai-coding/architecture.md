# AI-Coding Platform Architecture

## 1. Positioning

This repository is a downstream platform built on top of LoopX. LoopX remains the durable control plane; the downstream platform adds a coding-domain layer, agent interoperability, telemetry, evaluation, and a dedicated operator dashboard.

The primary human interaction surface is Codex. The platform does not introduce a competing chat UI as the main workflow.

## 2. Architectural rule

**Add first; modify upstream only when there is no stable extension point.**

The downstream platform should prefer:

1. existing LoopX extensions and public control-plane interfaces;
2. new additive modules under `loopx/extensions/ai_coding/`;
3. projection/read-model APIs for the custom dashboard;
4. host-specific adapters that translate a common Agent Run contract;
5. isolated presentation code under `apps/presentation/coding-dashboard/`.

Direct edits to LoopX kernel/control-plane code require an explicit compatibility justification.

## 3. Layer model

```text
Human
  |
  +-- Codex CLI / Codex App  <-- primary interaction / planning / intervention
  |
  v
LoopX control plane
  |-- goal / todo / gate / claim / lease
  |-- evidence / quota / recovery / scheduling
  |-- durable state / sessions / coordination
  |
  +-- AI-Coding extension
      |-- agent adapters
      |-- Agent Run model
      |-- telemetry
      |-- evaluation
      |-- coding projection / read model
      |-- dashboard API
  |
  +--------------------+-------------------+------------------+
  |                    |                   |                  |
Codex                Kiro CLI           Qwen Code        Claude Code
primary              supported          worker           backup
  |                    |                   |                  |
  +--------------------+-------------------+------------------+
                           |
                        PDS / PDS-Lab
                           |
                         GitHub
```

## 4. Agent roles

Agent roles are platform policy, not kernel semantics.

Initial policy:

- Codex: primary human interaction, primary planning, primary coding agent, final review.
- Kiro CLI: structured planning/specification and secondary coding agent.
- Qwen Code: high-frequency worker; primary target for cost/quality telemetry and evaluation.
- Claude Code: backup high-capability coding agent and optional cross-review agent.

The role assignment must remain replaceable without changing LoopX task semantics.

## 5. Truth boundaries

- LoopX is the source of truth for control state.
- GitHub is the source of truth for repository history, issues, pull requests, and merged code.
- Agent hosts are execution surfaces, not authoritative state stores.
- Telemetry records execution facts.
- Evaluation derives scores from facts and must not overwrite task facts.
- Dashboards are projections, not authoritative state stores.

## 6. Compatibility target

The first supported host matrix is:

| Host | Target | Strategy |
| --- | --- | --- |
| Codex | first-class | inherit upstream integration; downstream additions only |
| Kiro CLI | first-class | inherit upstream integration; downstream additions only |
| Qwen Code | first-class worker | add downstream adapter using common Agent Run contract |
| Claude Code | first-class backup | inherit upstream integration; downstream additions only |

OpenCode, OMP, agy and additional workers may be added later through the same contract.

## 7. Dashboard model

Two dashboards coexist intentionally:

- LoopX upstream Dashboard: preserved as-is, default port `8767`.
- AI-Coding Dashboard: downstream operator view, default port `8768`.

Both ports must be configurable. The AI-Coding Dashboard reads a stable coding projection/read model instead of LoopX internal storage structures directly.

## 8. Non-goals for Phase 0

Phase 0 does not attempt to redesign LoopX orchestration, replace the upstream Dashboard, create a new chat system, or optimize UI polish. The goal is compatibility, durable state, unified execution facts, and a stable projection boundary.