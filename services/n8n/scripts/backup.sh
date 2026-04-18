#!/usr/bin/env bash
#
# n8n backup — atomic snapshot of the n8n Docker volume.
#
# Produces a timestamped tar.gz in /var/backups/n8n/ containing the full
# /home/node/.n8n directory (SQLite DB, workflows, encrypted credentials,
# config).
#
# SQLite strategy (two paths):
#   - If sqlite3 is present in the container: uses the SQLite Online Backup
#     API (.backup command) — produces a clean single-file snapshot with
#     WAL merged in. Sidecar files (.wal, .shm) are dropped from the archive.
#   - If sqlite3 is absent (e.g. Docker Hardened Images): keeps the verbatim
#     copy including .wal and .shm files. This is a valid SQLite backup —
#     any SQLite client will merge the WAL automatically on first open.
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

# Validate KEEP early so an invalid env var fails with a clear message
# instead of a confusing arithmetic error from $((KEEP + 1)) below.
if ! [[ "${KEEP}" =~ ^[0-9]+$ ]]; then
  die "KEEP must be a non-negative integer (got: '${KEEP}')"
fi

command -v docker >/dev/null || die "docker not found in PATH"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  die "container '${CONTAINER}' is not running"
fi

# Preflight the tools we rely on inside the container so a missing
# binary surfaces with a clear message instead of an opaque "not found"
# from `docker exec` mid-snapshot. sqlite3 is optional: hardened images
# (e.g. Docker Hardened Images) ship without it — the script falls back
# to a WAL-inclusive copy which is equally valid for restore purposes.
for tool in tar cp sh; do
  if ! docker exec "${CONTAINER}" sh -c "command -v ${tool} >/dev/null"; then
    die "container '${CONTAINER}' is missing required tool: ${tool}"
  fi
done

HAS_SQLITE3=false
if docker exec "${CONTAINER}" sh -c "command -v sqlite3 >/dev/null" 2>/dev/null; then
  HAS_SQLITE3=true
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

log "staging snapshot inside container (sqlite3: ${HAS_SQLITE3})"
docker exec "${CONTAINER}" sh -c "
  set -e
  rm -rf '${TMP_IN_CONTAINER}'
  mkdir -p '${TMP_IN_CONTAINER}'
  # Copy the whole n8n data dir verbatim (workflows, nodes, config,
  # encrypted credentials, and a copy of the live .sqlite + WAL).
  cp -a /home/node/.n8n/. '${TMP_IN_CONTAINER}/'
"

if [ "${HAS_SQLITE3}" = "true" ]; then
  # Overwrite the verbatim .sqlite copy with an atomic Online Backup API
  # snapshot — consistent even under concurrent writes, WAL fully merged.
  # Drop the WAL sidecar files: they are redundant after .backup merges them.
  docker exec "${CONTAINER}" sh -c "
    set -e
    sqlite3 /home/node/.n8n/database.sqlite \".backup '${TMP_IN_CONTAINER}/database.sqlite'\"
    rm -f \\
      '${TMP_IN_CONTAINER}/database.sqlite-wal' \\
      '${TMP_IN_CONTAINER}/database.sqlite-shm' \\
      '${TMP_IN_CONTAINER}/database.sqlite-journal'
  "
  log "SQLite: atomic .backup completed (WAL merged, sidecar files removed)"
else
  # No sqlite3 in the container — WAL and SHM files are kept as-is.
  # This is a valid backup: SQLite will merge the WAL on first open after restore.
  log "SQLite: sqlite3 absent — WAL-inclusive copy (valid for restore)"
fi

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
