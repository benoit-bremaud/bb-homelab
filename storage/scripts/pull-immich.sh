#!/usr/bin/env bash
#
# Immich copy — mirror the Immich originals and database dumps from the Pi to
# the home laptop (#224, ADR 0010). Runs on the home laptop (systemd user
# timer, see services/immich/BACKUP.md), over the home network.
#
# The Pi side forces `rrsync -ro /mnt/appdata/immich` on this laptop's key, so
# paths below are relative to that root and the laptop can only read.
#
# Retention: a file deleted on the Pi moves to deleted/<date>/ here, purged
# after RETENTION_DAYS. Thumbnails and transcoded videos are rebuilt by Immich
# and not copied.
#
# Usage:
#   ./pull-immich.sh
#   PI_HOST=benoit@192.168.1.216 DEST=/path/to/dir ./pull-immich.sh

set -euo pipefail

PI_HOST="${PI_HOST:-benoit@bb-homelab.local}"
DEST="${DEST:-${HOME}/bb-homelab-immich}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
[[ "${RETENTION_DAYS}" =~ ^[1-9][0-9]*$ ]] \
  || { printf '[pull-immich] ERROR: RETENTION_DAYS must be a positive integer\n' >&2; exit 1; }
# Relative to the rrsync root /mnt/appdata/immich on the Pi.
SOURCES=(library/upload library/library library/profile library/backups db-dumps)

log() { printf '[pull-immich] %s\n' "$*"; }

command -v rsync >/dev/null || { log "ERROR: rsync not found in PATH"; exit 1; }

SSH_OPTS="ssh -o BatchMode=yes -o ConnectTimeout=15 -o ForwardAgent=no -o ClearAllForwardings=yes"
TODAY="$(date +%Y-%m-%d)"

umask 077
mkdir -p "${DEST}/current" "${DEST}/deleted" && chmod 700 "${DEST}"
rc=0
for src in "${SOURCES[@]}"; do
  dst="${DEST}/current/${src}"
  mkdir -p "${dst}"
  log "pulling ${PI_HOST}:${src}/ -> ${dst}"
  # --backup-dir is relative to the destination: deleted or replaced files
  # go to deleted/<date>/<src>/ instead of disappearing.
  if ! rsync -a --no-links --chmod=D700,F600 -e "${SSH_OPTS}" \
       --delete --backup --backup-dir="${DEST}/deleted/${TODAY}/${src}" \
       "${PI_HOST}:${src}/" "${dst}/"; then
    log "ERROR: pull of ${src} failed"; rc=1
  fi
done

log "purging deleted files older than ${RETENTION_DAYS} days"
find "${DEST}/deleted" -mindepth 1 -maxdepth 1 -type d -mtime +"${RETENTION_DAYS}" \
  -exec rm -rf -- {} +

if [ "${rc}" -eq 0 ]; then log "done"; else log "finished with errors"; fi
exit "${rc}"
