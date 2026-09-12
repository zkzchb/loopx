from __future__ import annotations

import json
from pathlib import Path

import pytest

from loopx.extensions.ai_coding.node_inventory import (
    NodeInventoryError,
    load_node_inventory,
)


def write_inventory(path: Path, *, schema: str = "ai_coding_node_agents_v0") -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": schema,
                "node_role": "pds-lab",
                "agents": {
                    "codex": {
                        "binary": "/bin/sh",
                        "loopx_integration": "upstream",
                        "loopx_agent_type": "codex-cli",
                        "role": "primary_interaction_planning_review",
                    },
                    "qwen-code": {
                        "binary": "/bin/sh",
                        "loopx_integration": "ai_coding_extension",
                        "loopx_runtime_profile": "generic_cli",
                        "registered_agent_id": "qwen-code",
                        "mcp_server": "loopx-ai-coding",
                        "role": "worker",
                    },
                },
            }
        ),
        encoding="utf-8",
    )


def test_inventory_loads_and_exposes_routes(tmp_path: Path) -> None:
    inventory_path = tmp_path / "agents.json"
    write_inventory(inventory_path)

    inventory = load_node_inventory(inventory_path)

    assert inventory.node_role == "pds-lab"
    assert inventory.agent("codex").scheduler_route() == {
        "integration": "upstream",
        "agent_type": "codex-cli",
    }
    assert inventory.agent("qwen-code").scheduler_route() == {
        "integration": "ai_coding_extension",
        "runtime_profile": "generic_cli",
        "registered_agent_id": "qwen-code",
        "mcp_server": "loopx-ai-coding",
    }
    assert inventory.availability() == {"codex": True, "qwen-code": True}


def test_inventory_rejects_unknown_schema(tmp_path: Path) -> None:
    inventory_path = tmp_path / "agents.json"
    write_inventory(inventory_path, schema="future")

    with pytest.raises(NodeInventoryError, match="unsupported node inventory schema"):
        load_node_inventory(inventory_path)


def test_inventory_rejects_missing_file(tmp_path: Path) -> None:
    with pytest.raises(NodeInventoryError, match="does not exist"):
        load_node_inventory(tmp_path / "missing.json")
