# Network resilience for replaceable hosts

PDS-Lab is a role, not a specific provider. A replacement host is acceptable only when it can reliably reach the public development services required by the AI-Coding platform, especially GitHub, npm/NodeSource, PyPI, Codex/OpenAI, Qwen Code, and Kiro.

The machine initializer therefore treats GitHub transport as part of the host portability contract instead of assuming a perfect network.

## LoopX checkout policy

The canonical `/project/loopx` development checkout uses a Git partial clone:

```text
--filter=blob:none
--no-tags
--branch platform
```

This keeps full commit/tree history for `main`/`platform` compatibility checks while deferring file blobs until Git actually needs them. It is intentionally not a shallow clone because `ai-coding-loopx validate` needs a usable merge base between `origin/main` and the downstream `platform` branch.

After clone, the initializer explicitly fetches both remote refs:

```text
origin/main
origin/platform
```

The downstream promotion gate therefore retains the same additive-only comparison semantics as a normal full clone.

## Retry behavior

Initial clone and the explicit `main`/`platform` fetch are retried up to four times with bounded exponential backoff. A failed initial clone is removed before retry so a half-written checkout is never mistaken for a valid platform workspace.

Retry delays are currently 3, 6, and 12 seconds before the final attempt. The retry policy is intended for transient packet loss, route instability, or short GitHub transport interruptions; it is not a substitute for a host with persistently poor external connectivity.

## Host selection implication

A host that repeatedly cannot complete the partial clone/fetch should fail PDS-Lab qualification even if domestic package mirrors are fast. The platform is GitHub-centric and later operation requires frequent fetch/pull, issue/PR work, package installation, agent authentication, and upstream synchronization.

BCE, NERD, local Ubuntu, or a low-cost VPS may all assume the `pds-lab` role. The provider name is irrelevant; the required capability is stable access to the external development toolchain plus the standard Ubuntu 24.04 / `gany` / `/project` baseline.

## Failure boundary

The initializer does not switch to unofficial repository mirrors or silently rewrite GitHub remotes. If all retry attempts fail, initialization stops with the development checkout incomplete. This keeps GitHub as the repository source of truth and makes network suitability visible during clean-host acceptance rather than hiding it behind a provider-specific workaround.
