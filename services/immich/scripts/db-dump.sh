#!/usr/bin/env bash
#
# Immich database dump — nightly pg_dumpall of the Immich Postgres (#224,
# ADR 0010). Runs from the Pi's crontab. The dump lands on the appdata HDD,
# next to the library, where the home laptop pulls both (pull-immich.sh).
#
# Usage:
#   db-dump.sh
#
# Env:
#   DUMP_DIR       default /mnt/appdata/immich/db-dumps
#   CONTAINER      default bb-homelab-immich-postgres
#   KEEP           dumps kept, default 7
#   KUMA_PUSH_URL  optional Uptime Kuma Push URL, pinged on success only;
#                  keep it out of git, it carries a token

set -euo pipefail

log() { printf '[immich-db-dump] %s\n' "$*"; }
die() { printf '[immich-db-dump] ERROR: %s\n' "$*" >&2; exit 1; }

DUMP_DIR="${DUMP_DIR:-/mnt/appdata/immich/db-dumps}"
CONTAINER="${CONTAINER:-bb-homelab-immich-postgres}"
KEEP="${KEEP:-7}"
[[ "${KEEP}" =~ ^[1-9][0-9]*$ ]] || die "KEEP must be a positive integer (got: '${KEEP}')"
DUMP="${DUMP_DIR}/immich-db-$(date +%Y-%m-%d_%H%M%S).sql.gz"

command -v docker >/dev/null || die "docker not found in PATH"
# The dump dir is created by hand (services/immich/BACKUP.md): a missing dir
# means the HDD is not mounted, and the dump must not land on the SD card.
[ -d "${DUMP_DIR}" ] || die "dump dir '${DUMP_DIR}' missing (HDD not mounted?)"
docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}" \
  || die "container '${CONTAINER}' is not running"

trap 'rm -f "${DUMP}.part"' EXIT
trap 'exit 130' INT TERM HUP

log "dumping ${CONTAINER}"
# Same command as Immich's backup procedure: pg_dumpall keeps database-level
# settings that a single-database pg_dump drops. Each database is a consistent
# snapshot taken without stopping Immich. pipefail turns a failed dump into a
# failed run, so no heartbeat is sent.
(umask 077; docker exec "${CONTAINER}" pg_dumpall --clean --if-exists --username=postgres \
  | gzip > "${DUMP}.part")
gzip -t "${DUMP}.part" || die "dump archive is corrupt"
mv "${DUMP}.part" "${DUMP}"

log "rotation: keep last ${KEEP} dumps"
# shellcheck disable=SC2012  # filenames are controlled by this script
ls -1t "${DUMP_DIR}"/immich-db-*.sql.gz | tail -n +"$((KEEP + 1))" | while read -r old; do
  log "removing ${old}"
  rm -f -- "${old}"
done

log "done: ${DUMP} ($(du -h "${DUMP}" | cut -f1))"

# Same success-only heartbeat as appdata-backup.sh: the URL goes to curl on
# stdin so the token never shows in `ps`; a failed ping is only a warning.
if [ -n "${KUMA_PUSH_URL:-}" ]; then
  if printf 'url = "%s"\n' "${KUMA_PUSH_URL}" | curl -fsS -m 10 --retry 2 -o /dev/null -K - ; then
    log "heartbeat sent to Uptime Kuma"
  else
    log "warning: heartbeat to Uptime Kuma failed (dump itself is fine)"
  fi
fi
