---
name: restore-test-n8n
description: Full restore test of an n8n backup archive on the Pi. Spins up an isolated n8n container (port 5679, separate volume, prod encryption key sourced from prod .env), verifies the workflow auto-activates as proof that credentials decrypt correctly, then tears down cleanly. Invoke with /restore-test-n8n before any risky operation (n8n volume migration, Pi OS upgrade, n8n version bump). Zero risk to production n8n.
disable-model-invocation: true
---

# /restore-test-n8n — validate n8n backup is restorable

Run this skill **before** any risky operation on n8n to confirm the
most recent backup archive can actually be restored with workflows
and credentials intact.

## When to invoke

- Before migrating n8n volume from SD card to HDD (`/mnt/appdata/n8n`)
- Before upgrading n8n image to a newer version
- Before a Pi OS / Docker upgrade that might affect n8n
- Periodically (every ~2 months) as a regression check

## Prerequisites

- SSH access to Pi as `benoit`
- Prod n8n is running (we test alongside, no impact)
- Prod `~/bb-homelab/services/n8n/.env` contains `N8N_ENCRYPTION_KEY`
- Disk space for ~5 MB of test data in `~/n8n-restoretest/`

## Canonical reference

The full procedure lives in
[`services/n8n/BACKUP.md`](../../../services/n8n/BACKUP.md) §"Full
restore test — isolated n8n instance".

This skill is the executable summary; refer to BACKUP.md for full
context (rationale, troubleshooting, History table convention).

## Procedure (commands to run on the Pi via SSH)

### 1. Pick the most recent archive

```bash
# The deployed cron on this Pi writes to ~/backups/n8n/ (user-owned).
# The script default in services/n8n/scripts/backup.sh is
# /var/backups/n8n/ but the running cron overrides it via the
# BACKUP_DIR env var — check `crontab -l` if unsure of the actual
# location on a given Pi.
BACKUP_DIR_DEPLOYED="${BACKUP_DIR:-$HOME/backups/n8n}"
# Fallback to /var/backups/n8n if the home-dir path is empty
if [ -z "$(ls -1 "${BACKUP_DIR_DEPLOYED}"/*.tar.gz 2>/dev/null)" ] \
   && [ -d /var/backups/n8n ]; then
  BACKUP_DIR_DEPLOYED=/var/backups/n8n
fi
ARCHIVE="$(ls -1t "${BACKUP_DIR_DEPLOYED}"/*.tar.gz | head -n1)"
echo "Will test: ${ARCHIVE}"
```

### 2. Light check — archive readable

```bash
tar -tzf "${ARCHIVE}" >/dev/null && echo "✓ archive readable"
tar -tzf "${ARCHIVE}" | grep -qE '^./database\.sqlite$' \
  && echo "✓ database.sqlite present"
```

If either fails: archive is corrupt — keep the previous archive and
raise an incident. Do NOT proceed to full test.

### 3. Extract into isolated test directory

```bash
mkdir -p ~/n8n-restoretest/data
sudo tar -xzpf "${ARCHIVE}" -C ~/n8n-restoretest/data/
```

`sudo` + `-p` flags preserve UID 1000 from the archive (the `node`
user inside the n8n container).

### 4. Write throwaway docker-compose.yml

```bash
cat > ~/n8n-restoretest/docker-compose.yml << 'EOF'
services:
  n8n-restoretest:
    image: docker.n8n.io/n8nio/n8n:2.16.0
    container_name: bb-homelab-n8n-restoretest
    restart: "no"
    ports:
      - "127.0.0.1:5679:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - GENERIC_TIMEZONE=Europe/Paris
      - TZ=Europe/Paris
      - "N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:?required for restore test}"
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
    volumes:
      - ./data:/home/node/.n8n
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:5678/healthz || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
EOF
```

Distinct from prod: different container name, port 5679 (not 5678),
separate volume bind mount. Zero collision risk.

### 5. Start the test container

```bash
cd ~/n8n-restoretest
docker compose --env-file ~/bb-homelab/services/n8n/.env up -d
```

`--env-file` reuses prod's `.env` so the **same**
`N8N_ENCRYPTION_KEY` is used — required for credential decryption.

### 6. Wait + verify

```bash
sleep 30
docker logs bb-homelab-n8n-restoretest --tail 40
docker inspect --format='{{.State.Health.Status}}' bb-homelab-n8n-restoretest
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:5679/healthz
```

## Success signals

| Signal | What it proves |
|---|---|
| `Building workflow dependency index... Processed N draft workflows` | DB readable, workflows enumerated |
| `Activated workflow "..."` for each currently-active workflow | **Decryption proof** — credentials inside the workflow decrypted cleanly. This is the strongest single signal. |
| Healthcheck = `healthy` | n8n fully bootstrapped |
| `curl /healthz` returns `HTTP 200` | Connectivity confirmed |

If any of those fail, the backup is **not safely restorable** — do
NOT proceed with any operation that would require restoring from it.

## Optional visual validation

From the user's laptop (NOT from the Pi), open SSH tunnel:

```bash
ssh -L 5679:localhost:5679 benoit@bb-homelab
```

Keep the session open. Open `http://localhost:5679` in the browser
to confirm visually that:

- Login screen accepts the prod owner account
- Workflow list shows the expected workflows
- Credentials list opens without "Decryption failed" errors

## Teardown — ALWAYS

```bash
cd ~/n8n-restoretest
docker compose --env-file ~/bb-homelab/services/n8n/.env down
sudo rm -rf ~/n8n-restoretest
docker ps --filter "name=bb-homelab-n8n-restoretest"  # must be empty
docker ps --filter "name=bb-homelab-n8n$" --format "{{.Names}} | {{.Status}}"
# Expected: bb-homelab-n8n | Up X weeks (healthy)
```

Verify prod n8n is unchanged before declaring success.

## After successful run — update BACKUP.md

Add a row to the "History of validated restores" table in
[`services/n8n/BACKUP.md`](../../../services/n8n/BACKUP.md):

```markdown
| 2026-MM-DD | `n8n-YYYY-MM-DD_HHMMSS.tar.gz` | ✅ N workflows restored and auto-activated, healthcheck healthy, HTTP 200. |
```

## Related

- [`services/n8n/BACKUP.md`](../../../services/n8n/BACKUP.md) — full
  canonical procedure with troubleshooting
- [`services/n8n/scripts/backup.sh`](../../../services/n8n/scripts/backup.sh)
  — the script that produces the archives this skill validates
- `infra-patterns` skill — Docker compose conventions used in the
  test compose
