#!/usr/bin/env bash
#
# Disk usage check — fill-up alert through an Uptime Kuma Push monitor
# (issue #202).
#
# Pushes `up` while every checked mount point is mounted and below the
# threshold (space and inodes), `down` with the failing mount point in the
# message otherwise. A dead cron sends nothing, so the monitor also turns
# DOWN. Kuma runs on this Pi with its data on /mnt/appdata: a dead Pi or a
# missing HDD stops Kuma too and needs an outside watcher (ADR 0004,
# layer 2).
#
# Usage:
#   disk-usage-check.sh [mount-point...]     default: / /mnt/appdata
#
# Env:
#   THRESHOLD      alert threshold in percent, integer 1-99, default 80;
#                  a mount point at or above it fails
#   KUMA_PUSH_URL  optional Uptime Kuma Push URL without query string; keep
#                  it out of git, it carries a token
#
# Exit: 0 all mount points ok, 1 a check failed, bad input, or failed push.
# Logs only failures, so the log stays small on the SD card.

set -euo pipefail

log() { printf '[disk-usage-check] %s %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

THRESHOLD="${THRESHOLD:-80}"
[[ "${THRESHOLD}" =~ ^[1-9][0-9]?$ ]] || die "THRESHOLD must be 1-99 (got: '${THRESHOLD}')"
case "${KUMA_PUSH_URL:-}" in *[\"\\?]*|*$'\n'*) die "KUMA_PUSH_URL must have no query string or quotes" ;; esac
[ "$#" -gt 0 ] || set -- / /mnt/appdata

failed=""
for mnt in "$@"; do
  if ! mountpoint -q "${mnt}"; then
    log "FAIL ${mnt}: not a mount point"
    failed="${failed} ${mnt}:unmounted"
    continue
  fi
  # A df error aborts the run (pipefail): no push, the monitor times out.
  line="$(df --output=pcent,ipcent "${mnt}" | tail -n 1 | tr -d '%')"
  read -r use iuse <<<"${line}"
  # Filesystems without inodes report "-" in the inode column.
  [ "${iuse}" = "-" ] && iuse=0
  if ! [[ "${use}" =~ ^[0-9]+$ && "${iuse}" =~ ^[0-9]+$ ]]; then
    log "FAIL ${mnt}: no usage figure from df"
    failed="${failed} ${mnt}:unknown"
  elif [ "${use}" -ge "${THRESHOLD}" ] || [ "${iuse}" -ge "${THRESHOLD}" ]; then
    log "FAIL ${mnt}: ${use} % space, ${iuse} % inodes (threshold ${THRESHOLD} %)"
    failed="${failed} ${mnt}:$(( use > iuse ? use : iuse ))pct"
  fi
done

if [ -n "${failed}" ]; then
  status="down"
  msg="$(printf '%s' "${failed# }" | tr ' /' '_-')"
else
  status="up"
  msg="OK"
fi

# -K - keeps the token out of the process list (same as appdata-backup.sh).
if [ -n "${KUMA_PUSH_URL:-}" ]; then
  printf 'url = "%s?status=%s&msg=%s&ping="\n' "${KUMA_PUSH_URL}" "${status}" "${msg}" \
    | curl -fsS -m 10 --retry 2 -o /dev/null -K - \
    || die "push to Uptime Kuma failed"
fi

[ "${status}" = "up" ]
