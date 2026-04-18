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
#     WAL merged in. SQLite sidecar files such as `database.sqlite-wal`,
#     `database.sqlite-shm` (and, if present, `database.sqlite-journal`)
#     are dropped from the archive.
#   - If sqlite3 is absent (e.g. Docker Hardened Images): the container is
#     paused via the cgroup freezer (docker pause) for the duration of the
#     file copy, then immediately resumed (docker unpause). The freeze halts
#     all writes atomically so the copied `database.sqlite` + SQLite sidecar
#     files such as `database.sqlite-wal` and `database.sqlite-shm` form a
#     consistent set. Any SQLite client will merge the WAL automatically on
#     first open.
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
# Path B (sqlite3 absent) builds the archive on the host, so host tar is
# required too. Check it upfront — otherwise the script would pause the
# container, copy, then fail late at tar, leaving a partial archive.
command -v tar >/dev/null    || die "tar not found in PATH (needed on host for sqlite3-absent fallback)"

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

# Cleanup on exit: unpause container if it was left paused by an error,
# remove the in-container staging dir, the host temp dir, and any partial archive.
TMP_ON_HOST=""
CONTAINER_PAUSED=false
cleanup() {
  # If the container is (or may still be) paused, skip in-container cleanup:
  # `docker exec` against a paused container hangs forever, and trap handlers
  # must not block. We try unpause once and verify — only then run docker exec.
  can_exec_in_container=true
  if [ "${CONTAINER_PAUSED}" = "true" ]; then
    if ! docker unpause "${CONTAINER}" >/dev/null 2>&1; then
      log "warning: failed to unpause '${CONTAINER}' in cleanup — skipping in-container rm (manual cleanup may be needed: ${TMP_IN_CONTAINER})"
      can_exec_in_container=false
    elif [ "$(docker inspect -f '{{.State.Paused}}' "${CONTAINER}" 2>/dev/null || printf 'true')" = "true" ]; then
      log "warning: '${CONTAINER}' still paused after unpause — skipping in-container rm"
      can_exec_in_container=false
    fi
  fi
  if [ "${can_exec_in_container}" = "true" ]; then
    docker exec "${CONTAINER}" rm -rf "${TMP_IN_CONTAINER}" 2>/dev/null || true
  fi
  if [ -n "${TMP_ON_HOST}" ]; then rm -rf "${TMP_ON_HOST}" 2>/dev/null || true; fi
  rm -f "${ARCHIVE}.part" 2>/dev/null || true
}
trap cleanup EXIT

if [ "${HAS_SQLITE3}" = "true" ]; then
  # Path A — sqlite3 present: stage inside container, overwrite .sqlite with an
  # atomic Online Backup API snapshot (WAL-safe, consistent under concurrent writes),
  # drop the now-redundant WAL sidecar files, stream archive via docker exec tar.
  log "staging snapshot inside container (sqlite3: true)"
  docker exec "${CONTAINER}" sh -c "
    set -e
    rm -rf '${TMP_IN_CONTAINER}'
    mkdir -p '${TMP_IN_CONTAINER}'
    cp -a /home/node/.n8n/. '${TMP_IN_CONTAINER}/'
    sqlite3 /home/node/.n8n/database.sqlite \".backup '${TMP_IN_CONTAINER}/database.sqlite'\"
    rm -f \\
      '${TMP_IN_CONTAINER}/database.sqlite-wal' \\
      '${TMP_IN_CONTAINER}/database.sqlite-shm' \\
      '${TMP_IN_CONTAINER}/database.sqlite-journal'
  "
  log "SQLite: atomic .backup completed (WAL merged, sidecar files removed)"
  log "streaming archive to ${ARCHIVE}"
  docker exec "${CONTAINER}" tar -czf - -C "${TMP_IN_CONTAINER}" . > "${ARCHIVE}.part"
else
  # Path B — sqlite3 absent: pause the container (cgroup freezer via docker
  # pause) so no write can occur, copy files to a host temp dir via docker
  # cp -a (which works on a paused container, bypassing exec), then resume
  # immediately. docker exec is NOT used while the container is paused — it
  # would hang.
  # -a is critical: preserves UID/GID from the container so that on restore,
  # ownership of /home/node/.n8n matches n8n's runtime UID. Without it, files
  # get chowned to whoever runs backup.sh (e.g. root via cron) and n8n fails
  # to write to its data dir after restore.
  TMP_ON_HOST="$(mktemp -d)"
  log "staging snapshot via docker cp (sqlite3: false) — pausing container"
  CONTAINER_PAUSED=true
  docker pause "${CONTAINER}"
  docker cp -a "${CONTAINER}:/home/node/.n8n/." "${TMP_ON_HOST}/"
  docker unpause "${CONTAINER}"
  CONTAINER_PAUSED=false
  log "SQLite: container resumed — WAL-inclusive copy completed"
  log "streaming archive to ${ARCHIVE}"
  tar -czf "${ARCHIVE}.part" -C "${TMP_ON_HOST}" .
  rm -rf "${TMP_ON_HOST}"
  TMP_ON_HOST=""
fi

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
