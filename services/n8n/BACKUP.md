# n8n — Backup & Restore

Procedure for backing up the n8n Docker volume (SQLite DB, workflows,
encrypted credentials, config) and restoring it on the same or a
different host.

## What is backed up

The archive contains a full snapshot of `/home/node/.n8n` inside the
running container:

- `database.sqlite` — workflows, execution history, **encrypted**
  credentials, settings.
- `workflows/`, `nodes/`, `binaryData/` — on-disk artefacts.
- `config`, `n8nEventLog.log`, `*.json` — runtime state.

The SQLite file is dumped via `sqlite3 ".backup"` so the copy is
consistent even if n8n is writing at the moment of the snapshot.

## What is NOT backed up

**`N8N_ENCRYPTION_KEY`** is intentionally excluded. Without that key,
the encrypted credentials inside `database.sqlite` cannot be
decrypted, so a restored DB without the matching key is effectively
useless for any workflow that uses credentials.

The key lives in two places and only those:

1. `services/n8n/.env` on the Pi (loaded by docker compose at runtime).
2. **Your password manager** — the canonical source of truth.

If you lose both, you lose every credential n8n stores. No recovery.

## Backup — manual run

```bash
cd services/n8n
./scripts/backup.sh
```

Default behaviour:

- Writes to `/var/backups/n8n/n8n-YYYY-MM-DD_HHMMSS.tar.gz`
- Keeps the last 7 archives, deletes older ones.
- Archive is `chmod 600` (readable only by the user who ran the script).

Overrides:

```bash
BACKUP_DIR=/mnt/backup/n8n \
KEEP=14 \
./scripts/backup.sh
```

Use the `BACKUP_DIR` override once dedicated backup storage (HDD C,
see issues #7 / #47 / #49) is in place — switch cleanly from the
temporary SD location to the HDD without editing the script.

First run needs a writable `/var/backups/n8n`. If running as a
non-root user, create it once:

```bash
sudo install -d -o "$USER" -g "$USER" -m 700 /var/backups/n8n
```

## Backup — scheduled via cron

Edit the crontab of the user that owns Docker (likely `benoit`):

```bash
crontab -e
```

Add a nightly run at 03:00 local time. The log goes next to the
archives (`/var/backups/n8n/backup.log`) so it lives in a directory
that the user already owns — no extra setup, no `/var/log` permission
issue, and the log rotates with the backups when you change
`BACKUP_DIR` later:

```cron
0 3 * * *  /home/benoit/bb-homelab/services/n8n/scripts/backup.sh >> /var/backups/n8n/backup.log 2>&1
```

Verify with:

```bash
crontab -l | grep backup.sh
# Wait one night, then:
ls -lt /var/backups/n8n/
tail -n 20 /var/backups/n8n/backup.log
```

If you prefer to keep logs under `/var/log/`, pre-create the file
once with the right ownership before adding the cron line, otherwise
the shell redirection fails before `backup.sh` runs and the cron job
silently produces nothing:

```bash
sudo install -o "$USER" -g "$USER" -m 644 /dev/null /var/log/n8n-backup.log
```

## Restore — same host

Restore to the same Pi, same n8n version, same `N8N_ENCRYPTION_KEY`.

```bash
# 1. Stop the stack (do NOT delete the volume).
cd services/n8n
docker compose down

# 2. Pick the archive you want to restore.
ARCHIVE=/var/backups/n8n/n8n-2026-04-15_030000.tar.gz

# 3. Find the host path of the volume.
VOL_PATH=$(docker volume inspect bb-homelab-n8n-data --format '{{ .Mountpoint }}')
echo "${VOL_PATH}"

# 4. Wipe + extract in place (requires sudo because the volume is
#    owned by the container's uid). The find form deletes dotfiles
#    too — n8n's volume contains hidden state (e.g. .cache, .npmrc)
#    that a plain `rm -rf .../*` would silently leave behind.
sudo find "${VOL_PATH:?}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
sudo tar -xzf "${ARCHIVE}" -C "${VOL_PATH}"

# 5. Bring the stack back up.
docker compose up -d

# 6. Confirm: list workflows in the UI, try an execution that uses
#    credentials. If the UI opens but credentials are empty/broken,
#    the N8N_ENCRYPTION_KEY in .env does not match the one used when
#    the archive was produced. Fix the key first.
```

## Restore — different host (or fresh Pi)

Same flow as above, plus two prerequisites before step 1:

1. `services/n8n/.env` must exist with the **same** `N8N_ENCRYPTION_KEY`
   value that was active when the archive was produced. Pull it from
   your password manager. An empty or wrong key means every encrypted
   credential in the archive is unusable.

2. `docker compose up -d` must be run **at least once** with the
   correct `.env` before the restore so the named volume
   (`bb-homelab-n8n-data`) exists. You can then immediately
   `docker compose down` and proceed with steps 2-5.

## Verifying an archive is restorable

Periodically (before a Pi OS upgrade, a volume migration to HDD, etc.)
verify a restore end-to-end on a throwaway location:

```bash
mkdir -p /tmp/n8n-restore-test
tar -xzf /var/backups/n8n/$(ls -1t /var/backups/n8n/ | head -n1) \
  -C /tmp/n8n-restore-test
sqlite3 /tmp/n8n-restore-test/database.sqlite 'PRAGMA integrity_check;'
# Expected: "ok"
rm -rf /tmp/n8n-restore-test
```

A failed `integrity_check` means the archive is corrupt — raise an
incident and keep the previous archive as the working copy.

## Rotation & storage

- Current: 7 daily snapshots on SD (`/var/backups/n8n/`). Size per
  snapshot ≈ size of `/home/node/.n8n/` compressed, typically 5-50 MB
  for a small homelab. 7 × 50 MB = 350 MB max on SD — fine.
- Target (once HDD C is in): move `BACKUP_DIR` to `/mnt/backup/n8n/`,
  extend `KEEP` to 14 or 30.
- Target (once off-site is in, issue #19): add a second job that
  `restic` the local `BACKUP_DIR` to Backblaze B2 / Hetzner Storage
  Box. Do not replace local backups with remote — keep both (3-2-1).

## Related

- Issue #8 — this procedure.
- Issue #7 — migrate live n8n volume from SD to HDD A. Uses the same
  archive format to ship the data across.
- Issue #19 — off-site backups (restic) of `BACKUP_DIR`.
