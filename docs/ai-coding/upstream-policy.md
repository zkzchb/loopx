# Upstream Compatibility Policy

## Objective

Keep the downstream AI-Coding platform continuously upgradeable from `huangruiteng/loopx` with minimal conflict.

## Branch roles

- `main`: mirror/sync branch for upstream LoopX. No downstream feature development.
- `platform`: integration branch for the downstream AI-Coding platform.
- `feature/*`: short-lived branches based on `platform`.

Recommended sync flow:

```text
huangruiteng/loopx:main
        |
        v
zkzchb/loopx:main
        |
        v
merge/rebase into platform
        |
        v
compatibility + smoke tests
```

## Change classification

### A. Preferred: additive

Examples:

- new files under `loopx/extensions/ai_coding/`;
- new presentation app under `apps/presentation/coding-dashboard/`;
- new docs under `docs/ai-coding/`;
- new smoke tests/examples;
- new adapters using existing extension/public interfaces.

### B. Allowed with justification: narrow integration patch

A small change to upstream-owned code is allowed only when an extension point is missing and the patch is needed to register or expose a downstream capability. Such changes must be isolated, documented, and covered by a compatibility test.

### C. Avoid

- rewriting LoopX control-plane semantics;
- renaming upstream public concepts;
- moving upstream files for downstream aesthetics;
- making the custom dashboard depend directly on private storage layout;
- embedding downstream policy into kernel state transitions when it can live in projection/policy code.

## Upstream sync rule

Every upstream update should be evaluated in this order:

1. sync `main` from upstream;
2. compare upstream changes touching extension/public interfaces we consume;
3. integrate into `platform`;
4. run host compatibility smoke tests for Codex, Kiro CLI, Qwen Code, and Claude Code;
5. run projection/dashboard contract tests;
6. only then continue feature work.

## Conflict budget

A healthy downstream release should normally have conflicts concentrated in registration/packaging boundaries, not in LoopX kernel code. If recurring conflicts appear in control-plane files, treat that as an architecture smell and move the customization outward.