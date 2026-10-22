#!/usr/bin/env bash
#
# Off-Pi copy — pull the nightly backup archives from the Pi to this machine.
#
# Runs on the dev PC (systemd user timer, see storage/OFFPI-COPY.md), never on
# the Pi: the Pi holds no credential for the PC, so a compromised Pi cannot
# reach or wipe this copy. No --delete: archives rotated away on the Pi stay
# here, the PC keeps the longer history.
#
# Usage:
#   ./pull-backups.sh
#   PI_HOST=benoit@100.121.134.61 DEST=/path/to/dir ./pull-backups.sh

set -euo pipefail

PI_HOST="${PI_HOST:-benoit@bb-homelab}"
DEST="${DEST:-${HOME}/Documents/02_personal/bb-homelab-backups}"
# Pi source dir -> local subdir. Matches the BACKUP_DIR of each cron job.
SOURCES=(
  "backups/n8n/:n8n"
  "vaultwarden-backups/:vaultwarden"
)

log() { printf '[pull-backups] %s\n' "$*"; }

command -v rsync >/dev/null || { log "ERROR: rsync not found in PATH"; exit 1; }

umask 077
mkdir -p "${DEST}" && chmod 700 "${DEST}"
for entry in "${SOURCES[@]}"; do
  src="${entry%%:*}"
  dst="${DEST}/${entry##*:}"
  mkdir -p "${dst}"
  log "pulling ${PI_HOST}:${src} -> ${dst}"
  rsync -a --chmod=D700,F600 -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
    --include='*.tar.gz' --include='*.log' --exclude='*' \
    "${PI_HOST}:${src}" "${dst}/"
done
log "done"
