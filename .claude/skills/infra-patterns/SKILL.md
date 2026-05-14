---
name: infra-patterns
description: Infrastructure patterns for bb-homelab. Defines shell script standards (`set -euo pipefail`, idempotent, lock-out-proof), Docker compose patterns (pinned images, shared external network `bb-homelab-proxy`, hardened images), fstab convention (UUID + nofail, `/mnt/<role>/<service>/` layout), systemd defaults, and SSH-to-Pi conventions. Apply when authoring or reviewing shell scripts, `docker-compose.yml`, fstab edits, or anything that interacts with the Pi infrastructure.
---

# Infrastructure patterns — bb-homelab

Project-specific patterns for shell scripts, Docker compose, fstab,
systemd, and SSH interactions in this repo. This skill extends the
agent-agnostic brief in [AGENTS.md](../../../AGENTS.md) and the global
rules in `~/.claude/CLAUDE.md`.

## Shell scripts

Location: `bootstrap/*.sh`, `services/*/scripts/*.sh`.

Mandatory pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `-e` exit on error
- `-u` error on unset variable
- `-o pipefail` propagate errors through pipes

Other rules:

- **Idempotent by design** — every script must be re-runnable without
  side effects (no double-installs, no double-mounts, no double-line
  appended to config files).
- **Lock-out-proof for hardening scripts** — `harden-ssh.sh` refuses
  to run if `~/.ssh/authorized_keys` is empty (would lock you out).
- Validate with `sshd -t` (or equivalent) before reloading services
  that hold your only remote access.
- Always use `sudo` explicitly; never assume root.
- Linted by `shellcheck` (CI-enforced via `.github/workflows/shellcheck.yml`).

Validate locally before commit:

```bash
shellcheck bootstrap/*.sh services/**/scripts/*.sh
```

## Docker compose patterns

Per-service `docker-compose.yml` files in `services/<name>/`.

- **Pin all images explicitly** — `image: name:X.Y.Z`, never `:latest`.
- **Override via env var**: `image: name:${SERVICE_IMAGE_TAG:-X.Y.Z}`
  so a bump is a deliberate `.env` change, never a silent `:latest` pull.
- **Named volumes for persistence**: `volumes: { name: bb-homelab-<service>-data }`.
- **External shared network for inter-service routing**:
  `bb-homelab-proxy` (cf. [ADR 0002](../../../docs/decisions/0002-caddy-reverse-proxy.md)).
  - Created once on host: `docker network create bb-homelab-proxy`.
  - Backend services join via `external: true` in their compose.
  - Caddy reaches them by service name as hostname (e.g. `n8n:5678`).
- **Hardened images preferred** when available (e.g. Alpine 3.22+ for
  n8n). Be aware that hardened images often lack `sqlite3`, `wget`,
  etc. — scripts that depend on these tools must detect and fall back
  (see `services/n8n/scripts/backup.sh` for the pattern).

## fstab convention (storage layer)

Reference: [`storage/INVENTORY.md`](../../../storage/INVENTORY.md).

- **Mount via UUID**, never `/dev/sdX` (which changes across reboots).
- **Always use `nofail`** option — boot continues even if disk
  disconnected.
- **Layout**: `/mnt/{appdata,archive,media,backup}/<service>/`.
- **Register the disk in INVENTORY.md before** any user data lands on
  it: identity + SMART baseline + integration procedure documented.
- Validate fstab additions with `sudo mount -a` (no reboot) before
  trusting them across a reboot.

Example fstab line:

```text
UUID=aed8879a-543a-4d43-90b1-0fb05aa371ea  /mnt/appdata  ext4  defaults,nofail  0  2
```

## systemd

- Prefer `Restart=on-failure` over `Restart=always` (avoid restart
  loops on misconfiguration).
- Set `TimeoutStopSec=30` to avoid the 90-second default hang on
  shutdown.
- Log to journal by default; `StandardOutput=append:/var/log/...` only
  when needed for service-specific log rotation.

## SSH to Pi

- Host alias: `bb-homelab` (resolves via Tailscale MagicDNS).
- Fallback IP: `100.121.134.61` (Tailscale).
- Convention: `ssh benoit@bb-homelab`.
- The sudo password lives in the user's password manager. Never echo
  it, never paste it in chat, never write it to a screenshot.
- For long pipelines, prefer a heredoc over chained `&&` which hides
  failure points:

  ```bash
  ssh benoit@bb-homelab '
    set -e
    cmd1
    cmd2
  '
  ```
