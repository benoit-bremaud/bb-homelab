#!/usr/bin/env bash
# Off-site copy of the local Vaultwarden archives (bb-vault#19).
#
# Pushes BACKUP_DIR to an encrypted restic repository on Cloudflare R2,
# keeps 30 daily + 12 monthly snapshots, checks a sample of the data, then
# sends a success-only heartbeat to an Uptime Kuma Push monitor. Restic
# encrypts client-side: R2 only ever stores ciphertext.
#
# Run from cron after scripts/backup.sh, e.g.:
#   20 3 * * * KUMA_PUSH_URL="$(cat ~/.config/bb-homelab/kuma-push-vaultwarden-offsite)" \
#     /bin/bash ~/bb-homelab/services/vaultwarden/scripts/offsite.sh
#
# Environment:
#   RESTIC_ENV_FILE  env file with AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
#                    RESTIC_REPOSITORY (bucket root) and RESTIC_PASSWORD_FILE
#                    (default ~/.config/bb-homelab/restic-r2.env, chmod 600,
#                    out of git). The restic password must also live in the
#                    owner's password manager: without it nothing restores.
#   BACKUP_DIR       local archives to copy (default ~/vaultwarden-backups)
#   KUMA_PUSH_URL    Push URL (optional, kept out of git)

set -euo pipefail

RESTIC_ENV_FILE="${RESTIC_ENV_FILE:-${HOME}/.config/bb-homelab/restic-r2.env}"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/vaultwarden-backups}"

log() { printf '[offsite] %s %s\n' "$(date -Is)" "$*"; }
die() { printf '[offsite] ERROR: %s\n' "$*" >&2; exit 1; }

[ -r "${RESTIC_ENV_FILE}" ] || die "cannot read ${RESTIC_ENV_FILE}"
[ -d "${BACKUP_DIR}" ] || die "BACKUP_DIR ${BACKUP_DIR} does not exist"
command -v restic >/dev/null || die "restic is not installed"

set -a
# shellcheck source=/dev/null
. "${RESTIC_ENV_FILE}"
set +a
# One sub-path per service inside the shared bucket.
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY}/vaultwarden"

log "backup ${BACKUP_DIR}"
restic backup --quiet --tag vaultwarden --host bb-homelab --exclude '*.log' "${BACKUP_DIR}"

log "retention: 30 daily, 12 monthly"
restic forget --quiet --tag vaultwarden --keep-daily 30 --keep-monthly 12 --prune

log "check 5% of the data"
restic check --quiet --read-data-subset=5%

log "done"
if [ -n "${KUMA_PUSH_URL:-}" ]; then
  printf 'url = "%s"\n' "${KUMA_PUSH_URL}" | curl -fsS -m 10 --retry 2 -o /dev/null -K - \
    || log "warning: heartbeat to Uptime Kuma failed (backup itself is fine)"
fi
