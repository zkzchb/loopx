# Qwen Code Adapter Strategy

## Why a downstream adapter

LoopX upstream currently has first-class paths for Codex, Kiro CLI, and Claude Code, while Qwen Code is not yet exposed as an equivalent LoopX host surface. The downstream platform therefore adds Qwen Code without changing LoopX control-plane semantics.

## Host capabilities used

The adapter is designed around Qwen Code's public CLI surfaces:

- `qwen -p/--prompt` for bounded headless execution;
- `--output-format json|stream-json` for machine-readable output;
- `--continue` and `--resume <sessionId>` for project-scoped continuation;
- `qwen sessions list --json` for session discovery;
- explicit run budgets such as `--max-session-turns`, `--max-wall-time`, and `--max-tool-calls`;
- MCP for LoopX tools/control-plane access;
- command/HTTP lifecycle hooks for observation and telemetry.

## Integration pattern

```text
LoopX control plane
      |
      +--> LoopX MCP surface -------------------+
      |                                        |
      v                                        v
AI-Coding Qwen adapter ---> qwen headless/interactive session
      ^                                        |
      |                                        |
      +--------- hooks / stream-json -----------+
```

The adapter should not patch Qwen Code or replace its provider/authentication configuration.

## Phase 0 execution strategy

For automated worker tasks, prefer headless execution with `stream-json` so the platform can observe events while the task is running. Session continuation should use an explicit session ID when known; `--continue` is acceptable only when the project has a single unambiguous active lane.

Default safety policy for initial testing:

- do not force `--yolo`;
- prefer `--approval-mode auto-edit` only inside an already isolated task workspace/worktree;
- use explicit wall-time/tool-call/turn budgets;
- preserve raw stream events for diagnostics;
- expose only normalized facts to the Coding Projection.

## Hooks

Hooks are suitable for telemetry and policy observation, especially:

- SessionStart / SessionEnd;
- PreToolUse / PostToolUse / PostToolUseFailure;
- Stop / StopFailure;
- TodoCreated / TodoCompleted;
- PermissionRequest;
- PreCompact / PostCompact.

Hooks should not become a second source of task truth. LoopX remains authoritative for control state.

## MCP

The preferred control integration is project-scoped MCP configuration pointing Qwen Code at the LoopX MCP surface. Adapter installation must be opt-in and should avoid mutating unrelated global Qwen configuration.

## Phase 0 acceptance

A Qwen Code run passes the initial adapter smoke test when it can:

1. receive one bounded LoopX-governed coding task;
2. execute in an isolated workspace;
3. expose a stable session ID;
4. produce machine-readable run output;
5. collect completion evidence/tests;
6. record bounded runtime/attempt facts;
7. hand control back to LoopX without independently deciding global Goal completion.
