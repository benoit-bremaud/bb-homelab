#!/usr/bin/env bash
#
# Vaultwarden backup — consistent snapshot of the Vaultwarden data dir.
#
# Produces a timestamped tar.gz in /var/backups/vaultwarden/ containing the
# full /data directory inside the running container:
#   db.sqlite3        — accounts + *encrypted* vault items, org/collection keys
#   rsa_key.pem/.der  — JWT signing keys (sessions, push, invites)
#   attachments/      — encrypted file attachments
#   sends/            — Bitwarden Send blobs
#   config.json       — settings written via the /admin panel
#
# SQLite strategy (two paths):
#   - If sqlite3 is present in the container: uses the SQLite Online Backup
#     API (.backup command) — a clean single-file snapshot with the WAL
#     merged in. The redundant sidecars (db.sqlite3-wal, db.sqlite3-shm,
#     db.sqlite3-journal) are dropped from the archive.
#   - If sqlite3 is absent: the container is paused via the cgroup freezer
#     (docker pause) for the duration of the file copy, then resumed
#     (docker unpause). The freeze halts all writes atomically so the copied
#     db.sqlite3 + sidecars form a consistent set; any SQLite client merges
#     the WAL on first open.
#
# IMPORTANT — what is NOT in this archive:
#   - The user's MASTER PASSWORD. Vault items stay encrypted with it; the
#     archive alone cannot decrypt them. Good (the backup is not a plaintext
#     vault) — but it means a restore is only useful to someone who still
#     knows the master password.
#   - The ADMIN_TOKEN. It lives in services/vaultwarden/.env (not under
#     /data), so it is not captured here. Keep its plaintext in your
#     password manager (break-glass). See services/vaultwarden/BACKUP.md.
#
# CROWN JEWELS — this archive contains rsa_key.pem and the encrypted DB.
# chmod 600 is applied; once moved off-Pi, encrypt it (restic / age) before
# it leaves the box.
#
# Usage:
#   ./backup.sh                   # default: /var/backups/vaultwarden, keep 7
#   BACKUP_DIR=/mnt/backup/vaultwarden \
#   KEEP=14 ./backup.sh           # override destination + retention
#                                 # (use once HDD C lands — issue #19)

set -euo pipefail

CONTAINER="${VW_CONTAINER:-bb-homelab-vaultwarden}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/vaultwarden}"
KEEP="${KEEP:-7}"
DATA_DIR="/data"
DB="db.sqlite3"
TS="$(date +%Y-%m-%d_%H%M%S)"
ARCHIVE="${BACKUP_DIR}/vaultwarden-${TS}.tar.gz"
TMP_IN_CONTAINER="/tmp/vw-backup-${TS}"

log()  { printf '[backup] %s\n' "$*"; }
die()  { printf '[backup] ERROR: %s\n' "$*" >&2; exit 1; }

# Validate KEEP early so an invalid env var fails with a clear message
# instead of a confusing arithmetic error from $((KEEP + 1)) below.
if ! [[ "${KEEP}" =~ ^[0-9]+$ ]]; then
  die "KEEP must be a non-negative integer (got: '${KEEP}')"
fi

command -v docker >/dev/null || die "docker not found in PATH"
# The sqlite3-absent fallback builds the archive on the host, so host tar is
# required too. Check it upfront — otherwise the script would pause the
# container, copy, then fail late at tar, leaving a partial archive.
command -v tar >/dev/null    || die "tar not found in PATH (needed on host for sqlite3-absent fallback)"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  die "container '${CONTAINER}' is not running"
fi

# Preflight the tools we rely on inside the container so a missing binary
# surfaces with a clear message instead of an opaque "not found" from
# `docker exec` mid-snapshot. sqlite3 is optional: the script falls back to
# a WAL-inclusive paused copy which is equally valid for restore purposes.
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
# remove the in-container staging dir, the host temp dir, and any partial
# archive.
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
  # Path A — sqlite3 present, no pause needed. Order is deliberate and
  # matters for referential integrity:
  #   1) snapshot the DB FIRST via the Online Backup API (WAL-safe,
  #      consistent under concurrent writes) — the OLDEST artefact;
  #   2) copy the rest of /data (attachments/, sends/, keys, config) AFTER,
  #      excluding the live DB + sidecars (the step-1 snapshot is the one
  #      that ships).
  # Copying blobs first and snapshotting the DB last would race: a blob
  # created in between would be referenced by the newer DB yet absent from
  # the archive, making that item unrestorable. DB-first guarantees every
  # blob the snapshot references is captured by the copy that follows.
  log "staging snapshot inside container (sqlite3: true)"
  docker exec "${CONTAINER}" sh -c "
    set -e
    rm -rf '${TMP_IN_CONTAINER}'
    mkdir -p '${TMP_IN_CONTAINER}'
    sqlite3 ${DATA_DIR}/${DB} \".backup '${TMP_IN_CONTAINER}/${DB}'\"
    cd ${DATA_DIR}
    find . -mindepth 1 -maxdepth 1 \\
      ! -name '${DB}' ! -name '${DB}-wal' ! -name '${DB}-shm' ! -name '${DB}-journal' \\
      -exec cp -a {} '${TMP_IN_CONTAINER}/' ';'
  "
  log "SQLite: DB snapshot taken before blob copy (WAL merged, no blob race)"
  log "streaming archive to ${ARCHIVE}"
  docker exec "${CONTAINER}" tar -czf - -C "${TMP_IN_CONTAINER}" . > "${ARCHIVE}.part"
else
  # Path B — sqlite3 absent: pause the container (cgroup freezer via docker
  # pause) so no write can occur, copy files to a host temp dir via docker
  # cp -a (which works on a paused container, bypassing exec), then resume.
  # docker exec is NOT used while paused — it would hang.
  # -a preserves UID/GID from the container so ownership of /data on restore
  # matches Vaultwarden's runtime user (root in the stock image).
  TMP_ON_HOST="$(mktemp -d)"
  log "staging snapshot via docker cp (sqlite3: false) — pausing container"
  CONTAINER_PAUSED=true
  docker pause "${CONTAINER}"
  docker cp -a "${CONTAINER}:${DATA_DIR}/." "${TMP_ON_HOST}/"
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
ls -1t "${BACKUP_DIR}"/vaultwarden-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
  log "removing ${old}"
  rm -f -- "${old}"
done

SIZE="$(du -h "${ARCHIVE}" | cut -f1)"
log "done: ${ARCHIVE} (${SIZE})"
