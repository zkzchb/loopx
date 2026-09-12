# Host portability

The AI-Coding platform treats compute hosts as replaceable execution nodes, not as the durable identity of the system.

## Stable role vs replaceable machine

- **PDS** is the long-lived primary development node. The current expectation is that the physical/cloud host may remain stable for years, but the platform must still be rebuildable from the same initializer.
- **PDS-Lab** is an intentionally replaceable experimental role. The role may be hosted on BCE, NERD, a local Ubuntu workstation, another VPS, or any later Ubuntu machine that satisfies the baseline.

A machine becomes PDS or PDS-Lab by initialization and configuration, not by hostname, cloud vendor, IP address, disk identity, or provider-specific metadata.

## Portability contract

Any supported host must be able to assume a node role by starting from a clean Ubuntu 24.04 environment and running the canonical initializer with only the role changed:

```bash
# primary node
scripts/ai-coding-init.sh --role pds

# replaceable laboratory node
scripts/ai-coding-init.sh --role pds-lab
```

Both roles use the same development identity and path contract:

```text
gany
/project
/project/loopx
/project/<repository-name>
/home/gany/.config/ai-coding
```

No platform code should depend on:

- a particular VPS/cloud vendor;
- public IP or ZeroTier address literals;
- hostnames such as `pds`, `nerd`, or provider-assigned names;
- provider-specific home directories;
- a fixed CPU architecture beyond explicitly supported tool requirements;
- project checkouts outside `/project`;
- credentials or login state committed to Git.

## Durable vs disposable state

Host replacement is safe only when durable state is separated from machine-local state.

**Durable/project truth** belongs in systems that survive node replacement, primarily GitHub repositories, Issues/PRs, committed platform configuration, and other explicitly backed-up project assets.

**Machine-local state** includes tool login sessions, caches, package installations, temporary LoopX runtime files, CLI session data, Dashboard build artifacts, and `/project/.scratch`. These may be recreated or intentionally discarded when a node is rebuilt.

LoopX project/runtime state that is required for continuation must never be assumed to survive a disposable PDS-Lab replacement unless it has an explicit persistence/transfer path. The platform should prefer reconstruction from Git/project truth or an intentional state handoff over copying an entire machine image.

## Replacement workflow

Replacing PDS-Lab should normally be:

1. provision any suitable Ubuntu 24.04 host;
2. run `ai-coding-init.sh --role pds-lab`;
3. log in as `gany` and authenticate `gh`, Codex, Qwen Code, and Kiro;
4. run `ai-coding-doctor`;
5. clone only the repositories needed for the experiment into `/project`;
6. perform the disposable smoke before assigning real work;
7. retire the previous laboratory node without changing platform architecture.

The same recovery procedure also applies to PDS if it ever has to be rebuilt; PDS is operationally stable, not architecturally irreplaceable.

## Design consequence

Dashboard, dispatch, telemetry, Agent adapters, and project workflows should reason about **node roles and capabilities**, not machine identities. A future scheduler should be able to answer “which healthy node can execute this task?” without caring whether the PDS-Lab role currently runs on BCE, NERD, local Ubuntu, or another VPS.
