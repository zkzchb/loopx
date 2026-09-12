# AI-Coding Platform

This directory defines the downstream AI-Coding platform built on LoopX.

## Start here

1. [`architecture.md`](architecture.md) — product/control-plane boundaries and agent roles.
2. [`upstream-policy.md`](upstream-policy.md) — how this fork stays upgradeable from LoopX upstream.
3. [`pds-bootstrap.md`](pds-bootstrap.md) — one-click PDS/PDS-Lab machine baseline.
4. [`node-layout.md`](node-layout.md) — canonical filesystem and configuration locations.
5. [`host-portability.md`](host-portability.md) — replaceable-host contract for PDS/PDS-Lab roles.
6. [`runtime-lifecycle.md`](runtime-lifecycle.md) — stable runtime, canary, promotion and rollback lifecycle.
7. [`host-matrix.md`](host-matrix.md) — Codex/Kiro/Qwen/Claude integration boundaries.
8. [`bootstrap-validation.md`](bootstrap-validation.md) — clean-node and disposable-project validation checklist.
9. [`agent-contract.md`](agent-contract.md) — normalized Agent Run lifecycle, evidence, and usage facts.
10. [`dashboard.md`](dashboard.md) — dual-dashboard boundary and the three-tab product information architecture.
11. [`qwen-code-adapter.md`](qwen-code-adapter.md) — downstream Qwen Code integration strategy.
12. [`phase-0.md`](phase-0.md) — Phase 0 work packages and acceptance criteria.

## Working rule

LoopX is the control plane. Codex is the primary human interaction/planning surface. Kiro CLI and Qwen Code are installed in the default server stack; Claude Code remains an upstream-compatible backup lane. Host-specific details stay in adapters and node inventory, while the downstream coding layer normalizes runs, evidence, telemetry, and evaluation.

Machine bootstrap, stable runtime management, source development, and project onboarding are deliberately separate lifecycles. Rebuilding PDS/PDS-Lab may recreate tools and host surfaces, but must not silently create, replace, or take over project Goal/Todo/Agent state. Editing `/project/loopx` must not change the active stable control plane until an explicit validation and promotion succeeds.

PDS is operationally long-lived but still rebuildable. PDS-Lab is explicitly disposable: BCE, NERD, local Ubuntu, or a later VPS may assume the same role as long as the canonical initializer, `gany` identity, `/project` layout, and capability checks pass.

The custom AI-Coding Dashboard is an independent projection client and is not a replacement for the upstream LoopX Dashboard.
