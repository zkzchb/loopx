# Standard node layout

The AI-Coding platform uses the same filesystem layout on PDS and PDS-Lab.
Only the node role and default project root differ.

```text
/opt/ai-coding/loopx/                 downstream LoopX platform checkout
/srv/ai-coding/projects/              PDS formal project workspace
/srv/ai-coding/lab-projects/          PDS-Lab experimental project workspace
/srv/ai-coding/scratch/               disposable smoke/tests

~/.local/bin/                         loopx/codex/qwen/kiro-cli + helpers
~/.config/ai-coding/env.sh            shell environment
~/.config/ai-coding/node.env          machine role/path facts
~/.config/ai-coding/agents.json       agent inventory for platform consumers
~/.local/share/ai-coding/qwen-mcp/    isolated Qwen MCP Python runtime

~/.codex/                             Codex host state/skills
~/.kiro/                              Kiro host state/skills
~/.qwen/                              Qwen state, skills, user MCP settings
```

The layout is intentionally boring: stable paths are more valuable than clever
autodiscovery on disposable/rebuilt servers. Platform code should prefer the
canonical inventory files and environment variables, then fall back to PATH
probing for diagnostics.
