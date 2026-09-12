# Initialization validation checklist

Use this checklist after a fresh PDS or PDS-Lab reset before onboarding any real
product repository.

## Identity and workspace baseline

Verify from the initial root session:

```bash
id gany
getent group sudo | grep -w gany
stat -c '%U:%G %n' /project /project/loopx
```

Expected:

- `gany` exists with home `/home/gany` and shell `/bin/bash`;
- `gany` belongs to `sudo`;
- `/project` and `/project/loopx` are owned by `gany`;
- sudo still requires the `gany` Unix password;
- source repositories are not spread under `/root`, `/opt`, or `/srv`.

Then switch to the development identity:

```bash
su - gany
```

## Machine baseline

```bash
source ~/.config/ai-coding/env.sh
ai-coding-doctor
```

Expected minimum:

- Python 3.11+;
- Node.js 22+;
- `git`, `gh`, `loopx`, `codex`, `qwen`, and `kiro-cli` available;
- `AI_CODING_PROJECT_ROOT=/project`;
- LoopX platform checkout `/project/loopx` on branch `platform`;
- Codex/Kiro LoopX skills installed;
- Qwen LoopX skill and `loopx-ai-coding` user MCP configured;
- Qwen isolated MCP Python can import both `loopx` and `mcp`;
- both Dashboard dependency trees are present.

## Interactive authentication

Authenticate as `gany`, never as root:

```bash
gh auth login
codex login
codex login status
qwen
kiro-cli
```

Do not save tokens/API keys in the repository or `agents.json`. Confirm `gh auth
status` before cloning private repositories.

## Host-only smoke

Before a business repository is connected, verify that each executable starts
and LoopX machine health is clean. Do not create project Goal/Todo state as part
of this check.

## First disposable project smoke

Create the disposable repository under `/project/.scratch` and run the separate
project initializer in preview mode first. Only after reviewing the preview
should `--execute` be used.

The disposable smoke is complete when:

1. LoopX creates/reuses local project state safely;
2. Codex can see the upstream LoopX surface;
3. Kiro can see the upstream LoopX surface;
4. Qwen can see the `loopx` Skill and `loopx-ai-coding` MCP server;
5. the `qwen-code` peer is only bound after explicit registration;
6. no private LoopX state is tracked by Git;
7. normal Git/GitHub operations are performed as `gany` inside `/project`.

Real product repositories should not be used until this disposable smoke passes
on PDS-Lab, followed by the same initialization on PDS.
