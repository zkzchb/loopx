# Host matrix

| Host | Platform role | LoopX integration | Machine bootstrap |
|---|---|---|---|
| Codex CLI | primary interaction / planning / coding / final review | upstream `codex-cli` | default |
| Kiro CLI | secondary planning / execution | upstream `kiro-cli` | default |
| Qwen Code | worker | downstream Skill + MCP on `generic_cli` | default |
| Claude Code | backup high-capability lane | upstream `claude-code` | optional, not in base image |

## Rules

- Primary/secondary/worker are platform policy, not LoopX kernel semantics.
- Codex and Kiro stay on upstream adapters so upstream upgrades remain cheap.
- Qwen Code is isolated in `loopx/extensions/ai_coding/`; do not add a Qwen host
  type to upstream-owned catalogs unless the upstream project itself adopts it.
- Claude Code remains compatible through the upstream adapter but is deliberately
  excluded from the initial PDS/PDS-Lab base image until the three-host stack is
  stable.
