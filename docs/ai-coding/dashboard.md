# AI-Coding Dashboard Boundary

## Two independent web apps

The platform intentionally keeps two dashboards:

1. LoopX upstream Dashboard — preserved for control-plane/operator visibility.
2. AI-Coding Dashboard — downstream product view for coding projects and agent performance.

Default development/runtime ports:

```text
LoopX Dashboard      8767
AI-Coding Dashboard  8768
```

Both must support configuration through environment variables and/or CLI flags.

## Product dashboard tabs

The custom Dashboard keeps the three-tab information architecture defined for the AI-Coding workflow.

### 1. Current Task

Primary purpose: answer what agents are doing now and whether intervention is needed.

Show task titles rather than opaque IDs. Agent identity appears compactly next to the title. Status uses strong visual hierarchy:

- completed: vivid success state;
- running: active/high-attention state;
- planned/not started: low-saturation state;
- blocked/failed: explicit warning state.

Hover/focus may reveal the longer explanation while the board keeps titles concise.

Current Task should surface execution quality indicators relevant to intervention, including validation state, retry count, token usage, cache behavior, and abnormal context consumption.

### 2. Task Detail

Primary purpose: explain one task end-to-end.

Expected information includes task purpose, dependencies, executor, attempts, Agent Run history, evidence, validation, handoff, token/cache/cost data, interventions, and evaluation.

### 3. Overall Tasks

Primary purpose: expose the complete project decomposition and progress model.

The task graph can evolve, but it should remain detailed enough that a human can understand the actual planned work. Chinese explanatory titles/descriptions should accompany internal task identifiers.

## Projection boundary

The custom Dashboard must not read LoopX private storage schemas directly.

```text
LoopX control state + Agent Run facts + telemetry
                    |
                    v
        Coding Projection / Read Model
                    |
                    v
            Dashboard API
                    |
                    v
       AI-Coding Dashboard :8768
```

The projection is an anti-corruption layer. Upstream LoopX schema changes should normally require changes only in the projection adapter, not in the frontend.

## Evaluation presentation

Facts and scores remain visually distinct.

Facts may include:

- task state;
- tests passed/failed;
- evidence count;
- token use;
- cache hit ratio;
- retries;
- duration;
- human interventions.

Derived evaluation may include:

- Quality;
- Efficiency;
- Independence;
- Context Efficiency;
- Reliability;
- Overall Score.

The scoring formula is versioned separately so historical facts remain stable when evaluation policy changes.