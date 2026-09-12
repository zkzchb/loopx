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
- source repositories are not spread under `/root`, `/opt`, or `/srv`;
- when bootstrap inherited an administrator SSH key, `gany` can use the same
  public-key access without enabling password SSH.

Then switch to the development identity:

```bash
su - gany
```

## Stable-runtime baseline

```bash
source ~/.config/ai-coding/env.sh
ai-coding-loopx status
ai-coding-doctor
```

Expected minimum:

- Python 3.11+ and Node.js 22+;
- `git`, `gh`, `loopx`, `codex`, `qwen`, `kiro-cli`, and `ai-coding-loopx` available;
- `AI_CODING_PROJECT_ROOT=/project`;
- LoopX development checkout `/project/loopx` on branch `platform`;
- `~/.local/bin/loopx` resolves under `~/.local/share/loopx/releases/`, not
  under `/project/loopx`;
- `runtime.env` names the same stable release as the `loopx` symlink;
- `ai-coding-doctor`, `ai-coding-loopx`, and `ai-coding-project-init` resolve to
  scripts inside that stable release;
- Codex/Kiro LoopX surfaces are generated from the stable release;
- Qwen LoopX Skill and `loopx-ai-coding` MCP are configured;
- the Qwen MCP Python environment is release-specific and its `.source-release`
  marker matches the active stable release;
- the Qwen MCP runtime imports `loopx` and `mcp` without reading editable code
  from `/project/loopx`;
- both Dashboard dependency trees are present for validation/development.

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

## Self-host isolation smoke

Before connecting a real product repository, prove that editing the development
checkout cannot silently mutate the stable control plane:

```bash
readlink -f ~/.local/bin/loopx
readlink -f ~/.local/bin/ai-coding-doctor
ai-coding-loopx status
```

The resolved paths must remain inside the active stable release. `loopx-canary`
is the only expected executable that may point at `/project/loopx`.

Run the candidate path once:

```bash
cd /project/loopx
ai-coding-loopx canary
```

Then confirm the ordinary `loopx` path is unchanged.

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

## Promotion/rollback smoke before real use

On PDS-Lab only, make a harmless downstream-only test commit or use the intended
next candidate and verify the lifecycle:

```bash
ai-coding-loopx validate
ai-coding-loopx promote --label test
ai-coding-loopx status
ai-coding-loopx rollback
ai-coding-loopx status
```

Do not perform a promotion while an Agent run is actively writing LoopX control
state. Promotion is a task/run boundary operation, not a live-process hot swap.

Real product repositories should not be used until the disposable-project and
promotion/rollback smokes pass on PDS-Lab. PDS can then be initialized from the
same baseline without repeating experimental promotion tests unless desired.
