from __future__ import annotations

from dataclasses import dataclass
import os
import shutil
from typing import Literal

QWEN_CODE_AGENT_TYPE = "qwen-code"
QWEN_CODE_BIN_ENV = "AI_CODING_QWEN_BIN"

OutputFormat = Literal["text", "json", "stream-json"]
ApprovalMode = Literal["plan", "default", "auto-edit", "auto", "yolo"]


@dataclass(frozen=True)
class QwenRunRequest:
    """Normalized inputs needed to build one bounded Qwen Code invocation."""

    prompt: str
    session_id: str | None = None
    continue_latest: bool = False
    output_format: OutputFormat = "stream-json"
    approval_mode: ApprovalMode = "auto-edit"
    model: str | None = None
    max_session_turns: int | None = None
    max_wall_time: str | None = None
    max_tool_calls: int | None = None


def qwen_binary(explicit: str | None = None) -> str:
    """Return the configured Qwen Code executable name/path."""

    return explicit or os.environ.get(QWEN_CODE_BIN_ENV) or "qwen"


def qwen_available(explicit: str | None = None) -> bool:
    """Return True when the configured Qwen Code executable is discoverable."""

    return shutil.which(qwen_binary(explicit)) is not None


def build_qwen_command(
    request: QwenRunRequest,
    *,
    executable: str | None = None,
) -> list[str]:
    """Build a non-shell Qwen Code command for one bounded run.

    The adapter deliberately returns argv rather than a shell string so callers
    can execute without shell interpolation. Execution/runtime integration is a
    later layer; this function only normalizes the public CLI contract.
    """

    prompt = request.prompt.strip()
    if not prompt:
        raise ValueError("Qwen Code prompt must not be empty")
    if request.session_id and request.continue_latest:
        raise ValueError("session_id and continue_latest are mutually exclusive")
    if request.max_session_turns is not None and request.max_session_turns <= 0:
        raise ValueError("max_session_turns must be greater than zero")
    if request.max_tool_calls is not None and request.max_tool_calls <= 0:
        raise ValueError("max_tool_calls must be greater than zero")
    if request.max_wall_time is not None and not request.max_wall_time.strip():
        raise ValueError("max_wall_time must not be blank")

    argv = [qwen_binary(executable)]

    if request.session_id:
        argv.extend(["--resume", request.session_id])
    elif request.continue_latest:
        argv.append("--continue")

    argv.extend(
        [
            "--prompt",
            prompt,
            "--output-format",
            request.output_format,
            "--approval-mode",
            request.approval_mode,
        ]
    )

    if request.model:
        argv.extend(["--model", request.model])
    if request.max_session_turns is not None:
        argv.extend(["--max-session-turns", str(request.max_session_turns)])
    if request.max_wall_time is not None:
        argv.extend(["--max-wall-time", request.max_wall_time])
    if request.max_tool_calls is not None:
        argv.extend(["--max-tool-calls", str(request.max_tool_calls)])

    return argv
