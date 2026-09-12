# PDS / PDS-Lab Bootstrap

This document defines the reproducible machine baseline for the AI-Coding platform.
The same software stack is installed on PDS and PDS-Lab; only the node role and
workspace root differ.

## Standard topology

| Item | PDS | PDS-Lab |
|---|---|---|
| Node role | `pds` | `pds-lab` |
| Platform checkout | `/opt/ai-coding/loopx` | `/opt/ai-coding/loopx` |
| Project root | `/srv/ai-coding/projects` | `/srv/ai-coding/lab-projects` |
| Scratch root | `/srv/ai-coding/scratch` | `/srv/ai-coding/scratch` |
| User commands | `~/.local/bin` | `~/.local/bin` |
| LoopX Dashboard | `127.0.0.1:8767` | `127.0.0.1:8767` |
| Coding Dashboard | `127.0.0.1:8768` | `127.0.0.1:8768` |

The default web bind is loopback-only. Expose dashboards later through the
private network/reverse proxy instead of making a fresh server public during
bootstrap.

## Installed agent stack

- LoopX: installed from the downstream `platform` checkout, while preserving the
  upstream architecture and release installer.
- Codex CLI: primary interaction, planning, coding, and final-review lane.
- Kiro CLI: secondary planning/execution lane through upstream LoopX Kiro support.
- Qwen Code CLI: worker lane through the downstream AI-Coding Skill + MCP bridge
  using LoopX's `generic_cli` runtime profile.
- Claude Code is intentionally not part of the default machine image. LoopX's
  upstream Claude adapter remains available as a backup lane and can be added
  after the base stack is validated.

## One-command bootstrap

Run as the normal Ubuntu runtime user with sudo access:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-bootstrap.sh \
  | bash -s -- --role pds
```

For PDS-Lab:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-bootstrap.sh \
  | bash -s -- --role pds-lab
```

If you are intentionally running the bootstrap from a root shell, pass the
runtime account explicitly:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-bootstrap.sh \
  | bash -s -- --role pds --user ubuntu
```

The installer is designed to be rerunnable. It refuses to update a dirty
`/opt/ai-coding/loopx` checkout instead of discarding local changes.

## What the bootstrap configures

1. Ubuntu build/runtime prerequisites and Node.js 22.
2. Standard `/opt` and `/srv` directory layout.
3. `zkzchb/loopx` `platform` checkout.
4. Official Codex CLI, Qwen Code CLI, and Kiro CLI installers.
5. LoopX using its own `scripts/install-local.sh` release installation path.
6. LoopX Codex and Kiro host surfaces using upstream installers.
7. Qwen personal Skill at `~/.qwen/skills/loopx/SKILL.md`.
8. An isolated Python environment for Qwen's LoopX MCP bridge at
   `~/.local/share/ai-coding/qwen-mcp/`.
9. Qwen user-scope MCP server named `loopx-ai-coding`.
10. `~/.config/ai-coding/env.sh`, `node.env`, and `agents.json` so the platform
    has one canonical host inventory.
11. npm dependencies for both Dashboard applications.
12. `ai-coding-doctor` for repeatable read-only verification.

## Authentication boundary

Credentials are never embedded in the repository or bootstrap script. After
installation, authenticate each CLI interactively as the runtime user:

```bash
codex
# choose Sign in with ChatGPT; verify later with:
codex login status

qwen
# run /auth when prompted/needed

kiro-cli
# complete the Kiro sign-in flow
```

Then reload the environment and verify:

```bash
source ~/.config/ai-coding/env.sh
ai-coding-doctor
```

## Machine setup vs project setup

The bootstrap deliberately does **not** create LoopX Goals, Todos, claims, or
leases in business repositories. Machine setup is rerunnable infrastructure;
project onboarding is durable task state and must remain explicit.

For a new project, the next platform step is a separate project-onboarding
workflow that will:

- inspect Git and existing LoopX state;
- connect/reuse an exact project Goal;
- register peer identities for the selected lanes;
- use upstream `codex-cli` and `kiro-cli` host types;
- register `qwen-code` as the downstream worker identity backed by the Qwen MCP
  bridge;
- preserve `.loopx/`, `.codex/goals/`, and `.local/` as local state.

## Local desktop pairing

The server image has no GUI requirement. The operator workstation can use:

- Codex GUI or ChatGPT desktop as the primary visible interaction surface; and
- Kiro GUI as the secondary visual development surface.

The server remains the execution/control environment. GUI applications should
connect to the same Git/SSH/project reality rather than create independent task
state.
