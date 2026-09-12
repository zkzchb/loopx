# AI-Coding Dashboard

Downstream presentation app for the AI-Coding platform.

This app is intentionally separate from `apps/presentation/dashboard/`, which remains the LoopX upstream Dashboard.

## Runtime

Default port: `8768`.

The port must remain configurable. The upstream LoopX Dashboard keeps its own default `8767`, allowing both applications to run simultaneously.

## Information architecture

The product UI uses three primary tabs:

1. Current Task
2. Task Detail
3. Overall Tasks

Detailed behavior is defined in `docs/ai-coding/dashboard.md`.

## Data boundary

This frontend must consume a stable Coding Projection / Dashboard API. It must not bind directly to LoopX private storage files or internal database layout.

No production UI implementation is required in Phase 0; this directory initially reserves the independent presentation boundary.