from __future__ import annotations

import pytest

from loopx.extensions.ai_coding.qwen_code_adapter import (
    QwenRunRequest,
    build_qwen_command,
)


def test_builds_bounded_headless_command() -> None:
    command = build_qwen_command(
        QwenRunRequest(
            prompt="Fix the failing unit test",
            output_format="stream-json",
            approval_mode="auto-edit",
            model="example-model",
            max_session_turns=20,
            max_wall_time="10m",
            max_tool_calls=50,
        ),
        executable="qwen-custom",
    )

    assert command == [
        "qwen-custom",
        "--prompt",
        "Fix the failing unit test",
        "--output-format",
        "stream-json",
        "--approval-mode",
        "auto-edit",
        "--model",
        "example-model",
        "--max-session-turns",
        "20",
        "--max-wall-time",
        "10m",
        "--max-tool-calls",
        "50",
    ]


def test_resume_uses_explicit_session_id() -> None:
    command = build_qwen_command(
        QwenRunRequest(prompt="Continue", session_id="session-123"),
    )

    assert command[:3] == ["qwen", "--resume", "session-123"]


def test_continue_latest_is_supported() -> None:
    command = build_qwen_command(
        QwenRunRequest(prompt="Continue", continue_latest=True),
    )

    assert command[:2] == ["qwen", "--continue"]


def test_resume_and_continue_are_mutually_exclusive() -> None:
    with pytest.raises(ValueError, match="mutually exclusive"):
        build_qwen_command(
            QwenRunRequest(
                prompt="Continue",
                session_id="session-123",
                continue_latest=True,
            )
        )


def test_empty_prompt_is_rejected() -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        build_qwen_command(QwenRunRequest(prompt="   "))


def test_non_positive_budgets_are_rejected() -> None:
    with pytest.raises(ValueError, match="max_session_turns"):
        build_qwen_command(QwenRunRequest(prompt="x", max_session_turns=0))
    with pytest.raises(ValueError, match="max_tool_calls"):
        build_qwen_command(QwenRunRequest(prompt="x", max_tool_calls=0))
