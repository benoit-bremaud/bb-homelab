#!/usr/bin/env bash
#
# Appdata backup — nightly snapshot of a container's data directories.
#
# Generic sibling of services/n8n/scripts/backup.sh (path B): the container
# is paused (cgroup freezer) while `docker cp -a` copies the directories to a
# host temp dir, then resumed. The freeze makes SQLite files and their WAL
# sidecars a consistent set. `docker cp` runs through the Docker daemon, so
# root-owned bind mounts (Caddy PKI, Uptime Kuma) are read without sudo.
#
# Usage:
#   appdata-backup.sh <name> <container> <path-in-container>...
#   e.g. appdata-backup.sh caddy bb-homelab-caddy /data
#
# Env:
#   BACKUP_DIR     default ~/backups/<name>
#   KEEP           archives kept, default 7
#   KUMA_PUSH_URL  optional Uptime Kuma Push URL, pinged on success only
#                  (issue #133); keep it out of git, it carries a token
#
# Archive layout: one top-level dir per path, named after the path with
# slashes turned into underscores (/app/data -> app_data).

set -euo pipefail

log() { printf '[appdata-backup] %s\n' "$*"; }
die() { printf '[appdata-backup] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$#" -ge 3 ] || die "usage: $0 <name> <container> <path-in-container>..."
NAME="$1"
CONTAINER="$2"
shift 2

[[ "${NAME}" =~ ^[a-z0-9-]+$ ]] || die "name must be lowercase kebab-case (got: '${NAME}')"
BACKUP_DIR="${BACKUP_DIR:-${HOME}/backups/${NAME}}"
KEEP="${KEEP:-7}"
[[ "${KEEP}" =~ ^[1-9][0-9]*$ ]] || die "KEEP must be a positive integer (got: '${KEEP}')"
ARCHIVE="${BACKUP_DIR}/${NAME}-$(date +%Y-%m-%d_%H%M%S).tar.gz"

command -v docker >/dev/null || die "docker not found in PATH"
command -v tar >/dev/null || die "tar not found in PATH"
command -v timeout >/dev/null || die "timeout not found in PATH"
docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}" \
  || die "container '${CONTAINER}' is not running"

mkdir -p "${BACKUP_DIR}"
TMP="$(mktemp -d)"
PAUSED=false
cleanup() {
  if [ "${PAUSED}" = "true" ]; then
    docker unpause "${CONTAINER}" >/dev/null 2>&1 \
      || log "warning: failed to unpause '${CONTAINER}' — run: docker unpause ${CONTAINER}"
  fi
  rm -rf "${TMP}" "${ARCHIVE}.part"
}
trap cleanup EXIT
# Route signals through exit so cleanup always resumes the container.
trap 'exit 130' INT TERM HUP

log "pausing ${CONTAINER} and copying: $*"
PAUSED=true
docker pause "${CONTAINER}" >/dev/null
for path in "$@"; do
  dest="${TMP}/$(printf '%s' "${path#/}" | tr '/' '_')"
  mkdir -p "${dest}"
  # Bounded so a stuck copy cannot leave the container paused forever.
  timeout 120 docker cp -a "${CONTAINER}:${path}/." "${dest}/"
done
docker unpause "${CONTAINER}" >/dev/null
PAUSED=false
log "container resumed"

(umask 077; tar -czf "${ARCHIVE}.part" -C "${TMP}" .)
mv "${ARCHIVE}.part" "${ARCHIVE}"
chmod 600 "${ARCHIVE}"

log "rotation: keep last ${KEEP} archives"
# shellcheck disable=SC2012  # filenames are controlled by this script
ls -1t "${BACKUP_DIR}/${NAME}"-*.tar.gz | tail -n +"$((KEEP + 1))" | while read -r old; do
  log "removing ${old}"
  rm -f -- "${old}"
done

log "done: ${ARCHIVE} ($(du -h "${ARCHIVE}" | cut -f1))"

# Same success-only heartbeat as the n8n script: the URL goes to curl on
# stdin so the token never shows in `ps`; a failed ping is only a warning.
if [ -n "${KUMA_PUSH_URL:-}" ]; then
  if printf 'url = "%s"\n' "${KUMA_PUSH_URL}" | curl -fsS -m 10 --retry 2 -o /dev/null -K - ; then
    log "heartbeat sent to Uptime Kuma"
  else
    log "warning: heartbeat to Uptime Kuma failed (backup itself is fine)"
  fi
fi
