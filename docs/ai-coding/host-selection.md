# PDS-Lab host qualification

PDS-Lab is a replaceable execution role. It may run on BCE, NERD, local Ubuntu, or a low-cost VPS as long as the host passes the same clean-machine initializer and smoke tests.

Host selection should prioritize developer-network reliability over raw compute. A suitable PDS-Lab must be able to reach GitHub, npm/NodeSource, PyPI, Codex/OpenAI, Qwen Code, and Kiro reliably enough for repeated rebuild, upstream sync, package installation, authentication, and disposable-project testing.

Domestic mirrors being fast is not sufficient if GitHub transport is repeatedly unstable. Conversely, a small VPS with modest CPU/RAM may be a better PDS-Lab when its external network is more predictable.

Recommended qualification order:

1. Ubuntu 24.04 clean install.
2. Run `ai-coding-init.sh --role pds-lab`.
3. Confirm the partial LoopX clone and explicit `main`/`platform` fetch complete without exhausting retries.
4. Authenticate `gh`, Codex, Qwen, and Kiro as `gany`.
5. Run `ai-coding-doctor`.
6. Run the disposable-project smoke under `/project/.scratch`.
7. Run the stable-runtime canary/validate/promote/rollback smoke.

A provider that cannot pass this sequence should be treated as an unsuitable current PDS-Lab host, not as a reason to weaken the platform's GitHub-centric source-of-truth model.
