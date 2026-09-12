# Agent Run Contract

## Purpose

The platform needs a stable contract that lets different coding agents participate in the same LoopX-controlled workflow without leaking host-specific session semantics into the control plane or dashboard.

## Contract principles

1. LoopX owns control state.
2. The adapter owns host-specific invocation and session handling.
3. The Agent Run record describes execution facts, not model opinions.
4. Evidence is explicit and independently inspectable when possible.
5. Telemetry is optional at source but normalized when available.

## Required lifecycle

Every first-class adapter should expose equivalent behavior for:

- `prepare`: verify host availability, workspace, permissions, and task inputs.
- `start`: begin a new bounded run.
- `resume`: continue an existing resumable run when supported.
- `status`: report normalized execution state.
- `interrupt`: request a safe stop without corrupting shared state.
- `collect_evidence`: gather commits, diffs, tests, logs, artifacts, or other completion evidence.
- `collect_usage`: gather token/cache/cost/runtime facts when the host exposes them.
- `finish`: close the run and return a normalized outcome/handoff.

These names describe platform semantics and do not require every host to implement identical CLI commands.

## Normalized Agent Run

Initial logical fields:

```text
run_id
project_id
goal_id
task_id
agent_id
agent_type
role
host
session_id
status
started_at
finished_at
attempt
workspace
branch
input_context_ref
output_summary
evidence_refs
validation_refs
usage
interventions
handoff
failure
```

## Normalized state

Minimum states:

```text
planned
preparing
running
waiting
blocked
interrupted
validating
completed
failed
cancelled
```

Host-native states should be mapped into these states for the coding projection while preserving raw host details separately.

## Evidence

Useful evidence includes:

- commit SHA;
- pull request;
- changed-file list or diff reference;
- test/lint/typecheck result;
- build/deploy result;
- generated artifact;
- explicit reviewer acceptance;
- agent handoff packet.

A task being marked `completed` and a task being `accepted` are distinct concepts. Acceptance may require validation or review.

## Usage facts

When exposed by a host/provider, normalize:

```text
input_tokens
output_tokens
cached_input_tokens
cache_hit_ratio
estimated_cost
wall_time
active_time
retries
context_rebuilds
```

Missing data must remain unknown rather than being estimated silently.

## Evaluation separation

Evaluation is downstream of Agent Run facts. Initial evaluation dimensions may include:

- Quality
- Efficiency
- Independence
- Context Efficiency
- Reliability

Scores are derived views and may be recalculated without mutating historical run facts.

## Initial adapter strategy

- Codex: reuse upstream LoopX integration and project additional run/telemetry facts around it.
- Kiro CLI: reuse upstream `kiro_cli_goal_mode` and project additional run/telemetry facts around it.
- Claude Code: reuse upstream `claude_goal_mode` and MCP path; treat it as a backup host initially.
- Qwen Code: implement the first downstream-native adapter against this contract.

The Qwen Code adapter is therefore the reference implementation for proving that the contract is not coupled to an upstream-native host.