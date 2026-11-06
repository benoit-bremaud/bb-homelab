# Vaultwarden — Backup & Restore

Procedure for backing up the Vaultwarden data directory (SQLite DB, JWT
signing keys, attachments, sends, admin config) and restoring it on the
same or a different host. Also defines the **break-glass** copy and the
gate to promote this service to **Tier-0**.

## What is backed up

The archive contains a full snapshot of `/data` inside the running
container:

- `db.sqlite3` — accounts, **encrypted** vault items, org/collection
  keys, settings.
- `rsa_key.pem` / `rsa_key.der` — JWT signing keys (sessions, push,
  invite tokens).
- `attachments/` — encrypted file attachments.
- `sends/` — Bitwarden Send blobs.
- `config.json` — settings written via the `/admin` panel.

The SQLite file is dumped via `sqlite3 ".backup"` so the copy is
consistent even if Vaultwarden is writing at the moment of the snapshot.
The DB snapshot is taken **before** the attachment/send blobs are copied,
so every blob the snapshot references is captured (no DB-vs-blob race). If
`sqlite3` is absent from the image, the script falls back to briefly
pausing the container (`docker pause`) for a WAL-inclusive consistent copy
instead.

## What is NOT backed up

- **Your master password.** Vault items stay encrypted with it; the
  archive alone cannot decrypt them. This is good — the backup is not a
  plaintext vault — but it means a restore is only useful to someone who
  still knows the master password. Keep it in a second password manager.
- **`VW_ADMIN_TOKEN`.** It lives in `services/vaultwarden/.env` (not under
  `/data`), so it is not in the archive. Keep its **plaintext** in your
  password manager.

If you lose the master password, the encrypted items are unrecoverable.
No backup can fix that.

## Break-glass copy — keep these off-Pi

While Vaultwarden is **not yet Tier-0** (see gate below), do not trust it
as the sole holder of any critical secret. Keep an emergency copy of
three things, off the Pi, never in plaintext:

1. **An encrypted Vault export** — in the Web Vault: *Tools → Export
   Vault → password-protected (encrypted) format*. This is the
   user-recoverable copy that does **not** depend on the server, the
   `rsa_key`, or the Pi being alive — import it into any Bitwarden /
   Vaultwarden.
2. **The `VW_ADMIN_TOKEN` plaintext** — in your existing password
   manager, so `/admin` is recoverable even if `.env` is lost.
3. **A copy of `rsa_key.pem` + `config.json`** (from a backup archive) —
   lets you restore the exact server identity, not just the data.

Store (1) and (3) in an encrypted location (your password manager's
secure-file store, or an `age`/`restic`-encrypted blob on the laptop) —
never plaintext, never only on the Pi's SD card.

## Graduation to Tier-0 (all four green)

Promote Vaultwarden to a Tier-0 dependency only when:

1. **Off-site backup** — done for Vaultwarden (2026-11-02):
   `scripts/offsite.sh` pushes `BACKUP_DIR` to an encrypted `restic`
   repository on Cloudflare R2 every night (see "Off-site copy" below).
   Other services join the same bucket under #19. Disk C (`/mnt/backup`,
   #47) still pending; 3-2-1, local kept alongside remote.
2. **Restore drill passed** — partly done 2026-11-02 from R2: restore →
   `PRAGMA integrity_check` ok → throwaway instance `/alive` 200. Still
   missing: the owner logs in to the restored instance.
3. **Uptime Kuma probe green** — HTTP probe on `/alive`, wired to the
   fault-only Telegram channel (ADR 0004).
4. **Dead-man's-switch green** — Healthchecks.io covers the Pi (ADR
   0004).

Until then, your existing password manager stays the source of truth for
the most critical secrets.

## Backup — manual run

```bash
cd services/vaultwarden
./scripts/backup.sh
```

Default behaviour:

- Writes to `/var/backups/vaultwarden/vaultwarden-YYYY-MM-DD_HHMMSS.tar.gz` (script default;
  the Pi cron below sets `BACKUP_DIR=/home/benoit/vaultwarden-backups`, which the rest of
  this document uses)
- Keeps the last 7 archives, deletes older ones.
- Archive is `chmod 600` (readable only by the user who ran the script).

Overrides:

```bash
BACKUP_DIR=/mnt/backup/vaultwarden \
KEEP=14 \
./scripts/backup.sh
```

Use the `BACKUP_DIR` override once dedicated backup storage (HDD C, see
issues #19 / #47) is in place — switch cleanly from the temporary SD
location to the HDD without editing the script.

First run needs a writable `/var/backups/vaultwarden`. If running as a
non-root user, create it once:

```bash
sudo install -d -o "$USER" -g "$USER" -m 700 /var/backups/vaultwarden
```

## Backup — scheduled via cron

Edit the crontab of the user that owns Docker (likely `benoit`):

```bash
crontab -e
```

Add a nightly run at 03:05 local time — staggered five minutes after the
n8n job (03:00) to avoid HDD contention. The log goes next to the
archives, in a directory the user already owns:

```cron
5 3 * * *  KUMA_PUSH_URL="$(cat /home/benoit/.config/bb-homelab/kuma-push-vaultwarden)" BACKUP_DIR=/home/benoit/vaultwarden-backups /home/benoit/bb-homelab/services/vaultwarden/scripts/backup.sh >> /home/benoit/vaultwarden-backups/backup.log 2>&1
```

`BACKUP_DIR` must exist before the first run (the `>>` redirect fails
otherwise). It is also the folder `storage/scripts/pull-backups.sh` reads:
changing it here means updating `SOURCES` there too. `KUMA_PUSH_URL` is the
failure alert described below.

Verify with:

```bash
crontab -l | grep backup.sh
# Wait one night, then:
ls -lt /home/benoit/vaultwarden-backups/
tail -n 20 /home/benoit/vaultwarden-backups/backup.log
```

## Failure alert — Uptime Kuma Push monitor

A failed run sends nothing; a good run pings a Push monitor, which turns
DOWN and alerts on Telegram after 26 h of silence (issue #133, diagrams in
[docs/architecture/diagrams/backup/](../../docs/architecture/diagrams/backup/01-sequence.md)).

1. In Uptime Kuma: **Add New Monitor → Push**, name `backup-vaultwarden`,
   heartbeat interval `93600` s (26 h: one night, plus 1 h for the
   autumn DST change and 1 h of margin), retries `0`, notification
   `BB Infra Alerts`.
2. Store the push URL outside git, readable by `benoit` only:

   ```bash
   install -d -m 700 ~/.config/bb-homelab
   (umask 077; printf '%s' '<push URL>' > ~/.config/bb-homelab/kuma-push-vaultwarden)
   ```

3. Pass it from the crontab line shown in the cron section above.

The archives are then pulled off the Pi every night, see
[storage/OFFPI-COPY.md](../../storage/OFFPI-COPY.md).

## Restore — same host

Restore to the same Pi, same Vaultwarden version.

> **Precondition**: the HDD must be mounted at `/mnt/appdata`
> (`mountpoint -q /mnt/appdata`). The compose uses
> `create_host_path: false`, so Vaultwarden refuses to start if the
> bind-mount source is missing — restore into the mounted disk.

```bash
# 1. Stop the stack (do NOT delete the data directory yet).
cd services/vaultwarden
docker compose down

# 2. Pick the archive to restore.
ARCHIVE=/home/benoit/vaultwarden-backups/vaultwarden-2026-06-03_030500.tar.gz

# 3. The data lives at a fixed host bind-mount path.
VOL_PATH=/mnt/appdata/vaultwarden
echo "${VOL_PATH}"

# 4. Wipe + extract in place (sudo: the dir is owned by the container's
#    root). The find form deletes dotfiles too.
sudo find "${VOL_PATH:?}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
sudo tar -xzf "${ARCHIVE}" -C "${VOL_PATH}"

# 5. Bring the stack back up.
docker compose up -d

# 6. Confirm: open https://vaultwarden.bb-homelab.local and log in. If the
#    Web Vault loads but sessions are invalid, the rsa_key in the archive
#    differs from the running one — re-log all devices.
```

## Restore — different host (or fresh Pi)

Same flow as above, plus two prerequisites before step 1:

1. `services/vaultwarden/.env` must exist with the **same**
   `VW_ADMIN_TOKEN` you want for `/admin` (pull the plaintext from your
   password manager and re-hash, or reuse the stored hash). The vault
   items themselves are decrypted client-side with the master password,
   independent of `.env`.

2. The bind-mount target directory must exist before the restore:

   ```bash
   sudo mkdir -p /mnt/appdata/vaultwarden
   sudo chmod 700 /mnt/appdata/vaultwarden
   ```

   Then proceed with steps 2-5 above (no need to start the stack first —
   the bind-mount path is created by hand).

## Verifying an archive is restorable

Periodically (before a Pi OS upgrade, a volume migration to HDD, etc.)
verify a restore end-to-end on a throwaway location:

```bash
mkdir -p /tmp/vw-restore-test
tar -xzf "$(ls -1t /home/benoit/vaultwarden-backups/*.tar.gz | head -n1)" \
  -C /tmp/vw-restore-test
sqlite3 /tmp/vw-restore-test/db.sqlite3 'PRAGMA integrity_check;'
# Expected: "ok"
ls /tmp/vw-restore-test/rsa_key.pem && echo "rsa_key present"
rm -rf /tmp/vw-restore-test
```

A failed `integrity_check` means the archive is corrupt — raise an
incident and keep the previous archive as the working copy.

## Rotation & storage

- Current: 7 daily snapshots on SD (`/home/benoit/vaultwarden-backups/`). A small
  single-user vault compresses to a few MB; 7 × a few MB on SD is
  negligible.
- Target (once HDD C is in): move `BACKUP_DIR` to
  `/mnt/backup/vaultwarden/`, extend `KEEP` to 14 or 30.
- Off-site: see "Off-site copy" below. Do not replace local backups with
  remote — keep both (3-2-1).

## Off-site copy (restic → Cloudflare R2)

- **What**: `scripts/offsite.sh`, cron `20 3 * * *` (after the 03:05 local
  backup). Pushes `BACKUP_DIR` to `s3:…r2.cloudflarestorage.com/bb-homelab-backups/vaultwarden`,
  keeps 30 daily + 12 monthly snapshots, checks 5% of the data, then
  pings the Uptime Kuma Push monitor "Vaultwarden off-site backup".
- **Encryption**: restic encrypts client-side; R2 only stores ciphertext.
- **Secrets** (on the Pi, `chmod 600`, out of git):
  `~/.config/bb-homelab/restic-r2.env` (R2 key pair, repository) and
  `~/.config/bb-homelab/restic-password`. The R2 token
  `r2-bb-homelab-restic-backup-2026` is scoped to the bucket, read/write
  objects, expires after 1 year — rotate before expiry.
- **Known risk**: the R2 token can delete objects, so a compromised Pi
  can erase the off-site history (`forget --prune` or S3 DELETE). Accepted
  for now; the fix (delete-less token + R2 bucket lock, retention run from
  a trusted machine) is tracked in a follow-up issue.
- **Kuma monitor**: Push type, interval 25 h (above the 24 h cron period).
- **Break-glass**: the restic password and the R2 key pair must also be
  in the owner's password manager. Without the restic password nothing
  restores.

### Restore from R2 (any machine with restic)

```bash
export AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=…
export RESTIC_REPOSITORY=s3:https://<account-id>.r2.cloudflarestorage.com/bb-homelab-backups/vaultwarden
export RESTIC_PASSWORD_FILE=/path/to/restic-password  # or let restic prompt
restic snapshots
restic restore latest --target /tmp/vw-restore
# then extract the newest vaultwarden-*.tar.gz into the data dir and
# follow "Restore" above.
```

## Refs

- Issue #25 — Vaultwarden deployment.
- Issue #19 — off-site backups (restic); Vaultwarden part done (bb-vault#19).
- ADR [0004](../../docs/decisions/0004-monitoring-architecture.md) —
  monitoring (Uptime Kuma probe, Healthchecks.io dead-man's-switch).
- ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md) —
  Vaultwarden deployment + backup-before-Tier-0 gating.
