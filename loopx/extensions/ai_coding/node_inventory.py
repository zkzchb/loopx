from __future__ import annotations

"""Canonical machine inventory for the downstream AI-Coding platform.

This is a read-only projection over bootstrap-owned configuration. It does not
register LoopX agents, create Goals, or become a scheduler. Consumers use it to
resolve the installed host binaries and the intended LoopX routing contract in a
stable way instead of independently guessing from PATH.
"""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import shutil
from typing import Any

SCHEMA_VERSION = "ai_coding_node_agents_v0"
INVENTORY_ENV = "AI_CODING_AGENT_INVENTORY"
DEFAULT_INVENTORY = Path("~/.config/ai-coding/agents.json")


class NodeInventoryError(ValueError):
    pass


@dataclass(frozen=True)
class AgentInstallation:
    name: str
    binary: str
    loopx_integration: str
    role: str
    loopx_agent_type: str | None = None
    loopx_runtime_profile: str | None = None
    registered_agent_id: str | None = None
    mcp_server: str | None = None

    def resolved_binary(self) -> str | None:
        """Resolve the configured executable without mutating configuration."""

        configured = os.path.expanduser(self.binary.strip())
        if not configured:
            return None
        if os.path.sep in configured:
            path = Path(configured)
            return str(path.resolve()) if path.is_file() and os.access(path, os.X_OK) else None
        return shutil.which(configured)

    @property
    def available(self) -> bool:
        return self.resolved_binary() is not None

    def scheduler_route(self) -> dict[str, str]:
        """Return the LoopX-facing route declared by the platform manifest.

        The route is descriptive only. LoopX remains authoritative for Goal,
        Todo, Gate, lease, quota, and scheduling state.
        """

        route: dict[str, str] = {"integration": self.loopx_integration}
        if self.loopx_agent_type:
            route["agent_type"] = self.loopx_agent_type
        if self.loopx_runtime_profile:
            route["runtime_profile"] = self.loopx_runtime_profile
        if self.registered_agent_id:
            route["registered_agent_id"] = self.registered_agent_id
        if self.mcp_server:
            route["mcp_server"] = self.mcp_server
        return route


@dataclass(frozen=True)
class NodeInventory:
    node_role: str
    agents: dict[str, AgentInstallation]
    source: Path

    def agent(self, name: str) -> AgentInstallation:
        try:
            return self.agents[name]
        except KeyError as exc:
            raise NodeInventoryError(f"agent is not declared in node inventory: {name}") from exc

    def availability(self) -> dict[str, bool]:
        return {name: agent.available for name, agent in self.agents.items()}

    def public_projection(self) -> dict[str, Any]:
        """Return non-secret facts suitable for diagnostics/dashboard use."""

        return {
            "schema_version": SCHEMA_VERSION,
            "node_role": self.node_role,
            "agents": {
                name: {
                    "binary": agent.binary,
                    "resolved_binary": agent.resolved_binary(),
                    "available": agent.available,
                    "role": agent.role,
                    "route": agent.scheduler_route(),
                }
                for name, agent in self.agents.items()
            },
        }


def inventory_path(explicit: str | Path | None = None) -> Path:
    candidate = explicit or os.environ.get(INVENTORY_ENV) or DEFAULT_INVENTORY
    return Path(candidate).expanduser().resolve()


def _optional_string(raw: dict[str, Any], key: str) -> str | None:
    value = raw.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise NodeInventoryError(f"{key} must be a non-empty string when present")
    return value.strip()


def _required_string(raw: dict[str, Any], key: str) -> str:
    value = _optional_string(raw, key)
    if value is None:
        raise NodeInventoryError(f"missing required field: {key}")
    return value


def load_node_inventory(explicit: str | Path | None = None) -> NodeInventory:
    path = inventory_path(explicit)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise NodeInventoryError(f"node inventory does not exist: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise NodeInventoryError(f"cannot read node inventory: {path}: {exc}") from exc

    if not isinstance(payload, dict):
        raise NodeInventoryError("node inventory root must be an object")
    if payload.get("schema_version") != SCHEMA_VERSION:
        raise NodeInventoryError(
            f"unsupported node inventory schema: {payload.get('schema_version')!r}"
        )

    node_role = _required_string(payload, "node_role")
    raw_agents = payload.get("agents")
    if not isinstance(raw_agents, dict) or not raw_agents:
        raise NodeInventoryError("agents must be a non-empty object")

    agents: dict[str, AgentInstallation] = {}
    for name, raw in raw_agents.items():
        if not isinstance(name, str) or not name.strip() or not isinstance(raw, dict):
            raise NodeInventoryError("agent entries must use non-empty string names and object values")
        canonical = name.strip()
        agents[canonical] = AgentInstallation(
            name=canonical,
            binary=_required_string(raw, "binary"),
            loopx_integration=_required_string(raw, "loopx_integration"),
            role=_required_string(raw, "role"),
            loopx_agent_type=_optional_string(raw, "loopx_agent_type"),
            loopx_runtime_profile=_optional_string(raw, "loopx_runtime_profile"),
            registered_agent_id=_optional_string(raw, "registered_agent_id"),
            mcp_server=_optional_string(raw, "mcp_server"),
        )

    return NodeInventory(node_role=node_role, agents=agents, source=path)
