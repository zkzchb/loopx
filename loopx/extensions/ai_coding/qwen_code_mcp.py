from __future__ import annotations

"""Qwen Code MCP bridge for the downstream AI-Coding platform.

This module intentionally lives in the downstream extension instead of adding a
new host type to LoopX core. Qwen Code is represented as a registered peer
identity (default: ``qwen-code``) and uses LoopX's generic CLI runtime profile.
"""

import os
from pathlib import Path
from typing import Any

from loopx.control_plane.scheduler.execution_context import SchedulerRuntimeProfile
from loopx.goal_mode_context import resolve_goal_context
from loopx.goal_mode_mcp import GoalModeMCPConfig, create_fastmcp_server

QWEN_AGENT_ID_ENV = "AI_CODING_QWEN_AGENT_ID"
DEFAULT_QWEN_AGENT_ID = "qwen-code"


def qwen_agent_id() -> str:
    value = os.environ.get(QWEN_AGENT_ID_ENV, DEFAULT_QWEN_AGENT_ID).strip()
    return value or DEFAULT_QWEN_AGENT_ID


def qwen_goal_context(cwd: str | Path | None = None) -> dict[str, Any] | None:
    """Resolve only a goal that explicitly registers the Qwen peer identity.

    Requiring the preferred binding prevents a Qwen session from silently
    taking over another agent's identity when a repository has multiple lanes.
    """

    return resolve_goal_context(
        cwd or Path.cwd(),
        preferred_agent_id=qwen_agent_id(),
        require_preferred_binding=True,
    )


def build_server():
    config = GoalModeMCPConfig(
        server_name="loopx-ai-coding-qwen",
        runtime_profile=SchedulerRuntimeProfile.GENERIC_CLI_AGENT_LOOP.value,
        legacy_host_surface="qwen-code",
        scheduler_owner="agent_cli_loop",
        execution_mode="interactive",
        setup_hint=(
            "connect the project to LoopX and register the qwen-code peer before "
            "starting this Qwen Code lane"
        ),
    )
    return create_fastmcp_server(config, lambda: qwen_goal_context(Path.cwd()))


def main() -> None:
    mcp, _control = build_server()
    mcp.run()


if __name__ == "__main__":
    main()
