# Standard node layout

PDS and PDS-Lab use the same filesystem layout. The machines differ only by
`AI_CODING_NODE_ROLE`; they do not use different source-code roots.

```text
/project/                            canonical Git workspace owned by gany
/project/loopx/                      downstream LoopX platform checkout
/project/<repository-name>/          product and tool repositories
/project/.scratch/                   disposable smoke/test workspaces

/home/gany/.local/bin/               loopx/codex/qwen/kiro-cli + helpers
/home/gany/.config/ai-coding/env.sh  shell environment and canonical paths
/home/gany/.config/ai-coding/agents.json
                                     machine Agent inventory
/home/gany/.local/share/ai-coding/qwen-mcp/
                                     isolated Qwen MCP Python runtime

/home/gany/.codex/                   Codex host state/skills
/home/gany/.kiro/                    Kiro host state/skills
/home/gany/.qwen/                    Qwen state, skills, user MCP settings
```

`gany` is the shared software-development identity on both servers and belongs
to the `sudo` group. Sudo remains password-protected.

The layout is intentionally simple. Stable paths are more valuable than clever
autodiscovery on disposable/rebuilt servers. Platform code should read
`~/.config/ai-coding/agents.json` and the exported environment first, and only
fall back to PATH probing for diagnostics.

All Git repositories used for development belong under `/project`; do not spread
working checkouts across `/opt`, `/srv`, `/root`, or individual temporary home
directories. System services may still use standard system paths when a project
is later deployed, but deployment/runtime paths are separate from source-code
workspace paths.
