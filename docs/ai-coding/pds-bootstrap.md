# PDS / PDS-Lab Initialization

This document defines the reproducible fresh-machine baseline for the AI-Coding
platform. PDS and PDS-Lab use the same account, filesystem layout, tools, Agent
surfaces, and project paths. The only machine-level difference is `node_role`.

## Canonical identity and workspace

| Item | PDS | PDS-Lab |
|---|---|---|
| Node role | `pds` | `pds-lab` |
| Development user | `gany` | `gany` |
| Development home | `/home/gany` | `/home/gany` |
| Git workspace | `/project` | `/project` |
| LoopX platform checkout | `/project/loopx` | `/project/loopx` |
| Scratch workspace | `/project/.scratch` | `/project/.scratch` |
| User commands | `/home/gany/.local/bin` | `/home/gany/.local/bin` |
| LoopX Dashboard | `127.0.0.1:8767` | `127.0.0.1:8767` |
| Coding Dashboard | `127.0.0.1:8768` | `127.0.0.1:8768` |

All Git repositories used for development should be cloned under
`/project/<repository-name>`. This makes SSH, Codex GUI, Kiro GUI, CLI agents,
and ordinary shell work observe the same source tree.

`gany` is a real Unix development account and is added to the `sudo` group. Sudo
remains password-protected; the initializer does not grant `NOPASSWD: ALL`.

The default web bind is loopback-only. Dashboards can later be exposed through
the private network or a controlled reverse proxy.

## Installed machine baseline

The canonical initializer installs:

- Ubuntu build/runtime tools, Git, Git LFS, SSH client, tmux, jq, rsync, and
  GitHub CLI (`gh`);
- Node.js 22 when the machine does not already have a sufficiently recent Node;
- the `gany` development account and `/project` workspace;
- the `zkzchb/loopx` `platform` branch at `/project/loopx`;
- Codex CLI as the primary interaction/planning/review lane;
- Kiro CLI as the secondary planning/execution lane;
- Qwen Code as the worker lane;
- LoopX from the platform checkout;
- upstream LoopX Codex and Kiro host surfaces;
- downstream Qwen Skill + MCP integration using LoopX `generic_cli` semantics;
- dependencies for both Dashboard applications;
- the canonical node environment and Agent inventory;
- `ai-coding-doctor` for read-only validation.

Claude Code remains a backup lane rather than a default dependency of the base
server image. LoopX upstream support for it is retained.

## One-command fresh-machine initialization

Run the initializer from a root shell on a freshly reset Ubuntu 24.04 server.
It creates `gany` and prompts on the controlling terminal for the Unix password.
The password is handled by the operating-system `passwd` command and is never
stored in the repository or generated configuration.

PDS-Lab should be initialized first:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-init.sh \
  | bash -s -- --role pds-lab
```

After PDS-Lab passes the clean-machine validation, initialize PDS with the same
script and only change the role:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-init.sh \
  | bash -s -- --role pds
```

If `gany` already exists, the initializer preserves its password by default. To
intentionally reset the password:

```bash
curl -fsSL https://raw.githubusercontent.com/zkzchb/loopx/platform/scripts/ai-coding-init.sh \
  | bash -s -- --role pds-lab --reset-password
```

## Authentication boundary

Machine initialization and external account authentication are deliberately
separate. The script never asks for or stores GitHub, OpenAI, Qwen, or Kiro
credentials.

After initialization:

```bash
su - gany
```

Authenticate GitHub first so private repositories under `/project` can be cloned
and managed with the GitHub CLI:

```bash
gh auth login
```

Then authenticate each coding tool interactively:

```bash
codex login
# verify with: codex login status

qwen
# complete the provider/auth flow when needed

kiro-cli
# complete the Kiro sign-in flow
```

Finally:

```bash
ai-coding-doctor
```

## Canonical node configuration

The initializer writes:

```text
/home/gany/.config/ai-coding/env.sh
/home/gany/.config/ai-coding/agents.json
```

`env.sh` standardizes the development PATH, node role, `/project`, LoopX
platform path, Dashboard ports, and host homes.

`agents.json` is the machine inventory consumed by the downstream Extension,
Dashboard, telemetry, and future dispatch logic. Consumers should read this
inventory instead of rediscovering binaries independently.

## Machine setup vs project setup

Fresh-machine initialization does **not** create project Goal/Todo/claim/lease
state. It also does not automatically clone product repositories other than the
platform repository itself.

For a product repository, clone it as `gany` under `/project`:

```bash
cd /project
gh repo clone OWNER/REPO
```

Then run the separate LoopX project-onboarding workflow. This boundary means a
PDS/PDS-Lab rebuild can safely recreate the development environment without
silently taking over durable project task state.

## Local desktop pairing

The server image has no GUI requirement. The operator workstation may use Codex
GUI or ChatGPT desktop as the primary visible interaction surface and Kiro GUI
as the secondary visual surface. Both should connect to the `gany` account and
the same `/project/<repo>` source tree over the chosen remote/SSH mechanism.
