# Standard node layout

PDS and PDS-Lab use the same filesystem layout. The machines differ only by
`AI_CODING_NODE_ROLE`; they do not use different source-code roots.

```text
/project/                            canonical Git workspace owned by gany
/project/loopx/                      mutable downstream LoopX development checkout
/project/<repository-name>/          product and tool repositories
/project/.scratch/                   disposable smoke/test workspaces

/home/gany/.local/bin/               loopx/codex/qwen/kiro-cli + helpers
/home/gany/.config/ai-coding/env.sh  machine environment and canonical paths
/home/gany/.config/ai-coding/runtime.env
                                     currently bound stable LoopX release
/home/gany/.config/ai-coding/agents.json
                                     machine Agent inventory

/home/gany/.local/share/loopx/releases/
                                     immutable promoted LoopX releases
/home/gany/.local/share/ai-coding/loopx-runtime/
                                     promotion receipts/history/previous release
/home/gany/.local/share/ai-coding/qwen-mcp/releases/<release-id>/
                                     release-specific Qwen MCP Python runtime

/home/gany/.codex/                   Codex host state/skills
/home/gany/.kiro/                    Kiro host state/skills
/home/gany/.qwen/                    Qwen state, skills, user MCP settings
```

`gany` is the shared software-development identity on both servers and belongs
to the `sudo` group. Sudo remains password-protected.

The critical boundary is that `/project/loopx` is **not** the runtime used to
govern normal work. It is a mutable development checkout. The ordinary `loopx`
command, Codex/Kiro LoopX surfaces, Qwen Skill/MCP bridge, and AI-Coding helper
commands are bound to an immutable promoted release under
`~/.local/share/loopx/releases/`.

`loopx-canary` is the only expected surface that may point directly at the
mutable checkout during development and validation.

The layout is intentionally simple. Stable paths are more valuable than clever
autodiscovery on disposable/rebuilt servers. Platform code should read
`~/.config/ai-coding/agents.json`, `env.sh`, and `runtime.env` before falling
back to PATH probing for diagnostics.

All Git repositories used for development belong under `/project`; do not spread
working checkouts across `/opt`, `/srv`, `/root`, or temporary home directories.
Deployment/runtime paths for finished products remain separate from these source
workspace paths.
