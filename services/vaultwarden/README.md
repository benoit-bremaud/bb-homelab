# services/vaultwarden — password manager (Bitwarden-compatible)

Vaultwarden is a lightweight, self-hosted server that speaks the Bitwarden
API. It gives the homelab a private password vault reachable from the
Bitwarden browser extensions and mobile apps, without sending anything to
a third-party cloud.

Reached **on the tailnet only** (no public ingress, decision #28), behind
Caddy with the internal CA (ADR 0002).

> **Status — scaffold; NOT a Tier-0 dependency (issue #25).** These files
> scaffold the service; the live deploy on the Pi (see Bootstrap) is the
> operator's next step. Once deployed it is usable, but the homelab has no
> unified, off-site, restore-tested backup yet (`/mnt/backup` not mounted —
> issue #19).
> Until the four graduation criteria in [BACKUP.md](BACKUP.md) are green,
> keep your existing password manager as the source of truth for your
> most critical secrets, and rely on the break-glass copy described
> there. See ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md).

## Stack

- Image: `vaultwarden/server:1.36.0` (pinned — bump deliberately via
  `.env`). Multi-arch manifest: arm64 is pulled automatically on the Pi 5.
- **No host port published**: Caddy reaches it as `vaultwarden:80` over
  the shared `bb-homelab-proxy` network. Smallest attack surface for the
  box that stores every password.
- Persistent data: bind-mount `/mnt/appdata/vaultwarden` (HDD, Pattern Y,
  role `appdata`) → `/data` in the container. Holds the entire vault
  state (`db.sqlite3`, `rsa_key.*`, `attachments/`, `sends/`,
  `config.json`). **Precondition**: the HDD must be mounted at
  `/mnt/appdata` before `docker compose up`. The compose declares
  `create_host_path: false`, so if the disk is not mounted Vaultwarden
  fails to start (loud) rather than starting silently on an empty DB.
- Network: `bb-homelab-proxy` (shared with Caddy) + `default`.
- Internal URL: `https://vaultwarden.bb-homelab.local` (via Caddy).

See [BACKUP.md](BACKUP.md) for the backup & restore procedure and the
break-glass / Tier-0 graduation gate.

## Bootstrap

Pre-requisites: Docker + Compose v2 (`bootstrap/bootstrap.sh`), the HDD
mounted at `/mnt/appdata`, the shared proxy network present, and the Caddy
internal CA installed on your client (see
[services/caddy/README.md](../caddy/README.md)).

On the Pi (`ssh benoit@bb-homelab`):

```bash
cd services/vaultwarden

# 1. Pre-flight: HDD mounted + proxy network present.
mountpoint -q /mnt/appdata || { echo "ABORT: /mnt/appdata not mounted"; exit 1; }
docker network inspect bb-homelab-proxy >/dev/null 2>&1 \
  || docker network create bb-homelab-proxy

# 2. Create the bind-mount target on the HDD (crown-jewels dir).
#    Vaultwarden runs as root inside the stock image, so no chown is
#    needed (unlike n8n's uid 1000). Lock the dir down:
sudo mkdir -p /mnt/appdata/vaultwarden
sudo chmod 700 /mnt/appdata/vaultwarden

# 3. Generate the Argon2 PHC admin-token hash (asks for the password
#    twice). SAVE the PLAINTEXT password to your password manager NOW —
#    it is the break-glass key to /admin and lives nowhere else.
docker run --rm -it vaultwarden/server:1.36.0 /vaultwarden hash

# 4. Create .env and paste the hash into VW_ADMIN_TOKEN WRAPPED IN SINGLE
#    QUOTES, keeping single '$'. Single-quoted .env values are literal, so
#    Compose does not interpolate the '$...' segments. Do NOT double the
#    '$' (that is the rule for inline compose.yml values, not for .env).
cp .env.example .env
${EDITOR:-nano} .env
chmod 600 .env

# 5. Bring the stack up and watch it become healthy.
docker compose up -d
docker compose ps
docker compose logs -f vaultwarden   # wait for "Rocket has launched"; Ctrl-C
```

The Caddy route (`vaultwarden.bb-homelab.local`) ships in
`services/caddy/Caddyfile` with this service. Apply it without restarting
Caddy:

```bash
docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
```

On each **client** (one-time, if not already done for other services),
route the hostname to the Pi's Tailscale IP (see
`services/caddy/README.md` for the CA):

```text
100.121.134.61  vaultwarden.bb-homelab.local
```

### Create the single account (signup dance)

Registration is closed by default. Open a one-shot window, create your
account, then slam the door:

```bash
# a. Open signups briefly, re-apply env (no data loss). Set
#    VW_SIGNUPS_ALLOWED=true in .env, then:
docker compose up -d
#    Keep VW_SIGNUPS_DOMAINS_WHITELIST EMPTY: a non-empty whitelist lets
#    those domains register even when SIGNUPS_ALLOWED=false (it overrides
#    it), leaving the door open after step c.

# b. Register your single account in the browser at
#    https://vaultwarden.bb-homelab.local
#    (strong master password → your password manager).

# c. Close signups again: set VW_SIGNUPS_ALLOWED=false in .env (and ensure
#    VW_SIGNUPS_DOMAINS_WHITELIST is empty), then:
docker compose up -d
#    Verify the register page no longer offers account creation.

# d. Confirm the admin panel works with the PLAINTEXT password at
#    https://vaultwarden.bb-homelab.local/admin
#    (if it rejects it, the hash is probably not wrapped in single quotes
#    in .env).
```

Finally, register an Uptime Kuma probe against `http://vaultwarden:80/alive`
(an HTTP "status / keyword" monitor expecting a 200 — **not** a "JSON
query" monitor: `/alive` returns a bare quoted timestamp string, not a
JSON object), and run the first backup (see [BACKUP.md](BACKUP.md)).

## Environment variables

| Variable | Role |
|---|---|
| `VW_ADMIN_TOKEN` | **Argon2 PHC hash** of the `/admin` password (never plaintext). Fail-fast if empty. Wrap the hash in single quotes in `.env` (single `$`). Plaintext lives only in your password manager. |
| `VW_IMAGE_TAG` | Image tag override (default `1.36.0`). Bump deliberately, test first. |
| `VW_DOMAIN` | Public origin (default `https://vaultwarden.bb-homelab.local`). Must match the Caddy hostname or WebAuthn/2FA and links break. |
| `VW_SIGNUPS_ALLOWED` | Open registration (default `false`). `true` only for the one-shot account bootstrap. |
| `VW_SIGNUPS_DOMAINS_WHITELIST` | Restrict self-registration to these email domains during the bootstrap window. |
| `VW_PUSH_ENABLED` | Mobile push via Bitwarden's relay (default `false`). Enabling routes device tokens through a third party. |
| `VW_PUSH_INSTALLATION_ID` / `_KEY` | Push credentials from <https://bitwarden.com/host> (only if push enabled). |
| `TZ` | Timezone (default `Europe/Paris`). Standard container/libc variable, not a Vaultwarden setting. |
| `VW_LOG_LEVEL` | Log verbosity (default `warn`; values: `trace`/`debug`/`info`/`warn`/`error`/`off`). |

All sensitive values live in `.env` (gitignored). Never commit `.env`.

## Security notes

- **Tailnet-only.** No host port; reachable only via Caddy on the
  Tailscale network. The password vault is the last service that should
  ever face the public internet.
- **Closed instance.** `SIGNUPS_ALLOWED=false` and
  `INVITATIONS_ALLOWED=false` after bootstrap — no self-registration, no
  invite surface.
- **Admin token at rest is a hash.** The `.env` holds the Argon2 PHC
  hash, not a usable credential; the plaintext lives only in your
  password manager.
- **No SMTP (known limitation).** No mail server in the homelab yet, so
  there is no email-based 2FA / hint flow and any invited user must be
  confirmed manually from `/admin`. Acceptable for a single-user (later
  small-family) instance.
- **Push is off by default** to avoid routing device push tokens through
  Bitwarden's third-party relay.

## Refs

- Issue #25 — deploy Vaultwarden.
- ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md) —
  deployment decision (Vaultwarden over HashiCorp Vault, tailnet-only,
  internal CA, backup-before-Tier-0 gating).
- [BACKUP.md](BACKUP.md) — backup, restore, break-glass, graduation gate.
- Issue #19 — off-site backups (restic) of `BACKUP_DIR`.
- The separate `bb-vault` repo standardises secret-management conventions
  on the `bw` CLI and will later point `bw config server` at this
  instance — tracked there, not here.
