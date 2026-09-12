# AI-Coding Platform

This directory defines the downstream AI-Coding platform built on LoopX.

## Start here

1. [`architecture.md`](architecture.md) — product/control-plane boundaries and agent roles.
2. [`upstream-policy.md`](upstream-policy.md) — how this fork stays upgradeable from LoopX upstream.
3. [`agent-contract.md`](agent-contract.md) — normalized Agent Run lifecycle, evidence, and usage facts.
4. [`dashboard.md`](dashboard.md) — dual-dashboard boundary and the three-tab product information architecture.
5. [`qwen-code-adapter.md`](qwen-code-adapter.md) — downstream Qwen Code integration strategy.
6. [`phase-0.md`](phase-0.md) — bootstrap work packages and acceptance criteria.

## Working rule

LoopX is the control plane. Codex is the primary human interaction/planning surface. Kiro CLI, Qwen Code, and Claude Code participate through host-specific integrations while the downstream coding layer normalizes runs, evidence, telemetry, and evaluation.

The custom AI-Coding Dashboard is an independent projection client and is not a replacement for the upstream LoopX Dashboard.
