# AI-Coding Platform

This directory defines the downstream AI-Coding platform built on LoopX.

## Start here

1. [`architecture.md`](architecture.md) — product/control-plane boundaries and agent roles.
2. [`upstream-policy.md`](upstream-policy.md) — how this fork stays upgradeable from LoopX upstream.
3. [`pds-bootstrap.md`](pds-bootstrap.md) — one-click PDS/PDS-Lab machine baseline.
4. [`node-layout.md`](node-layout.md) — canonical filesystem and configuration locations.
5. [`host-matrix.md`](host-matrix.md) — Codex/Kiro/Qwen/Claude integration boundaries.
6. [`bootstrap-validation.md`](bootstrap-validation.md) — clean-node and disposable-project validation checklist.
7. [`agent-run-contract.md`](agent-run-contract.md) — normalized Agent Run lifecycle, evidence, and usage facts.
8. [`dashboard.md`](dashboard.md) — dual-dashboard boundary and the three-tab product information architecture.
9. [`qwen-code-adapter.md`](qwen-code-adapter.md) — downstream Qwen Code integration strategy.
10. [`phase-0.md`](phase-0.md) — Phase 0 work packages and acceptance criteria.

## Working rule

LoopX is the control plane. Codex is the primary human interaction/planning surface. Kiro CLI and Qwen Code are installed in the default server stack; Claude Code remains an upstream-compatible backup lane. Host-specific details stay in adapters and node inventory, while the downstream coding layer normalizes runs, evidence, telemetry, and evaluation.

Machine bootstrap and project onboarding are deliberately separate. Rebuilding PDS/PDS-Lab may recreate tools and host surfaces, but must not silently create, replace, or take over project Goal/Todo/Agent state.

The custom AI-Coding Dashboard is an independent projection client and is not a replacement for the upstream LoopX Dashboard.