# Stable Runtime Lifecycle

The AI-Coding platform deliberately separates the LoopX development checkout from the LoopX runtime that governs active work.

## Core rule

`/project/loopx` is source code. It is allowed to change while 1.N+1 is being developed.

`~/.local/share/loopx/releases/<release-id>/` is an immutable promoted runtime. `~/.local/bin/loopx` points only at one of these promoted releases.

Codex/Kiro host surfaces, the Qwen LoopX Skill, the Qwen MCP Python environment, `ai-coding-doctor`, `ai-coding-loopx`, and project-init helpers are rebound to the selected stable release. They must not import or execute the mutable `/project/loopx` checkout during normal governed work.

## Bootstrap baseline

A fresh machine installs the current `platform` commit as a stable release named like:

```text
ai-coding-1.0-<source-sha>
```

The source checkout remains at `/project/loopx`, but editing it does not change the stable control plane.

## Development cycle

```text
stable 1.0
   |
   | governs Codex/Kiro/Qwen
   v
/project/loopx   <- develop 1.1 here
   |
   v
ai-coding-loopx canary
   |
   v
ai-coding-loopx validate
   |
   v
ai-coding-loopx promote --label 1.1
   |
   v
stable 1.1
```

`loopx-canary` may point directly at the development checkout because it is explicitly a candidate surface. The ordinary `loopx` command must remain bound to the promoted release until promotion succeeds.

## Validation and compatibility gate

The baseline promotion manager currently supports automatic promotion only while the downstream remains additive-only relative to `origin/main`.

Validation requires:

- a clean development checkout;
- no modified/deleted upstream-owned files relative to `origin/main`;
- canary deep installation doctor success;
- downstream shell syntax and Python compile checks;
- focused AI-Coding extension tests;
- Coding Dashboard build success.

A successful validation writes a promotion receipt tied to both the exact source commit and the exact currently active stable release. A later source edit or runtime switch invalidates that receipt.

If the downstream later needs to modify upstream-owned state/control-plane code, automatic additive promotion must stop. At that point a dedicated state/schema migration and backward-compatibility plan is required before the lifecycle manager is relaxed.

## Promotion

```bash
cd /project/loopx
ai-coding-loopx canary
ai-coding-loopx validate
ai-coding-loopx promote --label 1.1
```

Promotion delegates release materialization and candidate validation to LoopX's upstream `scripts/install-local.sh`, which creates a self-contained release and atomically changes the default `loopx` executable. The AI-Coding binder then rebinds Codex/Kiro/Qwen/helper surfaces to that release.

If post-promotion host-surface binding fails, the lifecycle manager immediately restores the previous stable executable and attempts to rebind its surfaces.

## Rollback

The previous stable release is retained locally. Roll back with:

```bash
ai-coding-loopx rollback
```

Or choose an explicit retained release:

```bash
ai-coding-loopx releases
ai-coding-loopx rollback ai-coding-1.0-<sha>
```

Rollback switches the LoopX executable and also restores the matching Codex/Kiro surfaces, Qwen Skill, release-specific Qwen MCP environment, and AI-Coding helper commands.

## Qwen MCP isolation

Every stable LoopX release gets an isolated Qwen MCP environment:

```text
~/.local/share/ai-coding/qwen-mcp/releases/<release-id>/
```

The package is installed from the immutable release, not with `pip install -e /project/loopx`. This prevents development edits from changing a running Qwen worker bridge.

## Upgrade semantics

The intended upgrade boundary is a task/run boundary, not a live-process hot swap. Finish or pause active work, validate the candidate, promote, then resume using the new runtime.

Machine initialization and software upgrades are different lifecycles:

```text
new host      -> ai-coding-init.sh
new LoopX     -> canary -> validate -> promote
bad release   -> rollback
```

Replacing PDS-Lab or rebuilding a host therefore does not require reconstructing historical development state by hand; the machine is recreated from the initializer, repositories are cloned under `/project`, and stable software is promoted through the same lifecycle.
