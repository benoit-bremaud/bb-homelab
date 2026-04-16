#!/usr/bin/env bash
#
# n8n backup — atomic snapshot of the n8n Docker volume.
#
# Produces a timestamped tar.gz in /var/backups/n8n/ containing the full
# /home/node/.n8n directory (SQLite DB, workflows, encrypted credentials,
# config). The SQLite DB is dumped via `.backup` first so the snapshot
# is consistent even if n8n is writing.
#
# IMPORTANT — the N8N_ENCRYPTION_KEY is NOT included in this archive.
# Without that key the encrypted credentials in the SQLite DB cannot be
# decrypted. Store the key in a password manager; losing it = losing
# every credential n8n holds. See services/n8n/BACKUP.md.
#
# Usage:
#   ./backup.sh                   # default: /var/backups/n8n, keep 7
#   BACKUP_DIR=/mnt/backup/n8n \
#   KEEP=14 ./backup.sh           # override destination + retention

set -euo pipefail

CONTAINER="${N8N_CONTAINER:-bb-homelab-n8n}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/n8n}"
KEEP="${KEEP:-7}"
TS="$(date +%Y-%m-%d_%H%M%S)"
ARCHIVE="${BACKUP_DIR}/n8n-${TS}.tar.gz"
TMP_IN_CONTAINER="/tmp/n8n-backup-${TS}"

log()  { printf '[backup] %s\n' "$*"; }
die()  { printf '[backup] ERROR: %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || die "docker not found in PATH"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  die "container '${CONTAINER}' is not running"
fi

mkdir -p "${BACKUP_DIR}"

# Ensure the in-container staging dir and the partial archive are
# cleaned up no matter how we exit (success, error, or interrupt).
# Without this, a failure during tar/mv leaves a full copy of .n8n
# inside /tmp of the container, eating disk and compounding failures.
cleanup() {
  docker exec "${CONTAINER}" rm -rf "${TMP_IN_CONTAINER}" 2>/dev/null || true
  rm -f "${ARCHIVE}.part" 2>/dev/null || true
}
trap cleanup EXIT

log "staging snapshot inside container"
docker exec "${CONTAINER}" sh -c "
  set -e
  rm -rf '${TMP_IN_CONTAINER}'
  mkdir -p '${TMP_IN_CONTAINER}'
  # First: copy the whole n8n data dir verbatim (workflows, nodes,
  # config, encrypted credentials, and a copy of the live .sqlite).
  cp -a /home/node/.n8n/. '${TMP_IN_CONTAINER}/'
  # Then: overwrite the copied .sqlite with an atomic SQLite .backup,
  # which is consistent even under concurrent writes (WAL-safe).
  sqlite3 /home/node/.n8n/database.sqlite \".backup '${TMP_IN_CONTAINER}/database.sqlite'\"
"

log "streaming archive to ${ARCHIVE}"
docker exec "${CONTAINER}" tar -czf - -C "${TMP_IN_CONTAINER}" . > "${ARCHIVE}.part"
mv "${ARCHIVE}.part" "${ARCHIVE}"
chmod 600 "${ARCHIVE}"

log "rotation: keep last ${KEEP} archives"
# shellcheck disable=SC2012  # ls is fine here; filenames are controlled.
ls -1t "${BACKUP_DIR}"/n8n-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
  log "removing ${old}"
  rm -f -- "${old}"
done

SIZE="$(du -h "${ARCHIVE}" | cut -f1)"
log "done: ${ARCHIVE} (${SIZE})"
