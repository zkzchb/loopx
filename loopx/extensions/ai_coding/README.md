# AI-Coding Extension

Downstream-only extension layer for the AI-Coding platform.

Planned submodules:

```text
adapters/      host-specific execution adapters
runs/          normalized Agent Run model and lifecycle projection
telemetry/     token/cache/cost/runtime facts
evaluation/    derived agent/task scoring
projection/    stable read model for the custom dashboard
```

## Boundary rules

- Do not become a second control plane.
- Do not duplicate LoopX Goal/Todo/Gate/Evidence semantics.
- Prefer translation/projection over mutation of upstream state models.
- Preserve raw host-specific facts when normalization would lose information.
- Keep downstream scoring outside the authoritative task state.
- Any required upstream-owned code change must be documented in `docs/ai-coding/upstream-policy.md`.

## Initial host matrix

- Codex: upstream integration + downstream projection/telemetry.
- Kiro CLI: upstream integration + downstream projection/telemetry.
- Claude Code: upstream integration + downstream projection/telemetry.
- Qwen Code: downstream adapter; reference implementation for the common Agent Run contract.
