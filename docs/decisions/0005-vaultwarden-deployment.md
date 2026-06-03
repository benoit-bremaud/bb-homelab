# ADR 0005 — Vaultwarden as the self-hosted password vault

- **Status**: Accepted
- **Date**: 2026-06-03

## Context

The homelab and its consuming projects need a private, self-hosted
password vault — a place to keep human-facing credentials (logins,
recovery codes, secure notes) reachable from browsers and phones,
without depending on a third-party cloud. Issue #25 tracked this as a
"nice-to-have"; the prerequisites it was waiting on are now in place:
Caddy reverse proxy with the internal CA (ADR 0002), the `/mnt/appdata`
HDD (storage `LAYOUT.md`), Tailscale-only access (decision #28), and
Uptime Kuma monitoring (ADR 0004).

Two products carry the word "vault" and must not be confused:

- **Vaultwarden** — a lightweight Rust server implementing the Bitwarden
  API. Static secrets (passwords, notes, attachments) for human users,
  consumed via the Bitwarden extensions/apps. SQLite, a few tens of MB
  of RAM.
- **HashiCorp Vault** — an enterprise secrets-management engine for
  infrastructure/apps (dynamic secrets, leasing, policies, audit
  devices). Heavy to operate, aimed at machine consumers.

A real constraint shapes the rollout: the homelab has **no unified,
off-site, restore-tested backup yet** (`/mnt/backup` is not mounted —
issue #19; only n8n has SD-card backups). A password vault that every
project depends on is the worst possible thing to make a single point of
failure with no proven recovery.

## Decision

Deploy **Vaultwarden** under `services/vaultwarden/`, following the
established service pattern (n8n / caddy / kuma), with these
sub-decisions:

1. **Vaultwarden over HashiCorp Vault.** The need is human end-user
   password management, not dynamic infra secrets. Vaultwarden matches
   the need at a fraction of the operational cost and runs comfortably
   on the Pi 5. It is also consistent with the separate `bb-vault`
   conventions toolkit, which standardises on the Bitwarden `bw` CLI.

2. **Tailnet-only, no public ingress.** Reached only via Caddy on the
   Tailscale network (`vaultwarden.bb-homelab.local`, internal CA, no
   host port published). The password vault is the last service that
   should ever face the public internet; this aligns with decision #28
   (no domain owned) and reuses ADR 0002 unchanged.

3. **Admin panel behind an Argon2 hash.** `ADMIN_TOKEN` is stored as an
   Argon2 PHC hash in `.env`, never as plaintext, so the file at rest
   holds no usable credential. The plaintext lives only in a password
   manager (break-glass).

4. **Closed instance.** `SIGNUPS_ALLOWED=false` and
   `INVITATIONS_ALLOWED=false` after a one-shot bootstrap window creates
   the single account. Mobile push is off by default (it would route
   device tokens through Bitwarden's third-party relay).

5. **Install now, but NOT Tier-0 until backup + monitoring are proven
   (the gating decision).** The service is installed and usable
   immediately, but is explicitly *not* treated as a Tier-0 dependency
   until four criteria are green: (1) unified off-site `restic` backup
   with Disk C mounted (#19/#47), (2) a documented end-to-end restore
   drill, (3) the Uptime Kuma `/alive` probe green on the fault-only
   channel, (4) the Healthchecks.io dead-man's-switch green. Until then,
   a break-glass copy (encrypted vault export + admin-token plaintext +
   `rsa_key`/`config.json`) is kept off-Pi, and the existing password
   manager remains the source of truth for the most critical secrets.
   Rationale: making Vaultwarden Tier-0 today would create a single
   point of failure with no proven recovery.

## Consequences

**Positive:**

- A private, self-hosted vault reachable from browsers and phones, with
  nothing in a third-party cloud.
- Reuses the existing proxy/CA/storage/monitoring layers — adding the
  service is a folder + one Caddyfile route.
- The "install now, gate Tier-0" stance captures the value immediately
  while refusing the single-point-of-failure risk until recovery is
  proven.
- Forward-compatible with `bb-vault`: that toolkit can later point
  `bw config server` at this instance with no change here.

**Negative:**

- A new stateful, security-sensitive service to operate, back up, and
  keep patched (image pinned; bump deliberately).
- The break-glass discipline (keep an encrypted export + admin plaintext
  off-Pi) is a manual habit until the Tier-0 gate closes.
- **No SMTP yet**: no email-based 2FA / hints, and invited users must be
  confirmed manually from `/admin`. Acceptable for a single-user (later
  small-family) instance; revisit when a mail relay exists.
- Crown-jewels data (`db.sqlite3` + `rsa_key`) lives on a single HDD
  with only SD-card backups until #19 lands — the precise gap the Tier-0
  gate exists to close.

## Alternatives considered

- **HashiCorp Vault.** Rejected: wrong tool for human password
  management — dynamic-secret engine aimed at infra/app consumers, heavy
  to run on a Pi, and it would throw away the Bitwarden-aligned `bw`
  workflow used across projects.
- **Bitwarden cloud only (no self-hosting).** Viable and zero-ops, but
  the explicit goal is to self-host the vault in the homelab. Kept as
  the break-glass fallback during the Tier-0 gate.
- **Make Vaultwarden Tier-0 immediately.** Rejected: with no unified,
  off-site, restore-tested backup, a disk failure would mean permanent
  loss of every stored secret. The gate defers that status until
  recovery is proven.
- **Expose it publicly via a named cloudflared tunnel.** Rejected:
  conflicts with decision #28 and puts the most sensitive service on the
  public internet.

## Refs

- Issue #25 — deploy Vaultwarden.
- Issue #19 — off-site backups (restic) of `BACKUP_DIR`; Disk C.
- ADR 0001 — DIP layering (this fits layers 4-6: service packaging).
- ADR 0002 — Caddy internal reverse proxy (tailnet routing + internal CA).
- ADR 0004 — monitoring (Uptime Kuma probe, Healthchecks.io switch).
- `services/vaultwarden/` — implementation (compose, README, BACKUP,
  backup script).
- Decision #28 — domain purchase (deferred); keeps access tailnet-only.
- The separate `bb-vault` repo — secret-management conventions on the
  `bw` CLI; will later point `bw config server` at this instance.
