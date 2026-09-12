# Bootstrap validation checklist

Use this checklist after a fresh PDS or PDS-Lab reset before onboarding any real project.

## Machine baseline

```bash
source ~/.config/ai-coding/env.sh
ai-coding-doctor
```

Expected minimum:

- Python 3.11+;
- Node.js 22+;
- `loopx`, `codex`, `qwen`, `kiro-cli` on PATH;
- LoopX platform checkout on branch `platform`;
- Codex/Kiro LoopX skills installed;
- Qwen LoopX skill and `loopx-ai-coding` user MCP configured;
- Qwen isolated MCP Python can import both `loopx` and `mcp`.

## Interactive authentication

Verify as the runtime user, not root:

```bash
codex login status
qwen
kiro-cli
```

Do not save tokens/API keys in the repository or `agents.json`.

## Host-only smoke

Before a business repository is connected, verify that each executable starts and
that LoopX's machine health is clean. Do not create project Goal/Todo state as
part of this check.

## First disposable project smoke

Create a disposable Git repository under the node's scratch root and use
`ai-coding-project-init.sh` in preview mode first. Only after the preview is
understood should `--execute` be used.

The disposable smoke is complete when:

1. LoopX creates/reuses local project state safely;
2. Codex can see the upstream LoopX surface;
3. Kiro can see the upstream LoopX surface;
4. Qwen can see the `loopx` Skill and `loopx-ai-coding` MCP server;
5. the `qwen-code` peer is only bound after explicit registration;
6. no private LoopX state is tracked by Git.

Real product repositories should not be used until this disposable smoke passes
on both PDS and PDS-Lab.
