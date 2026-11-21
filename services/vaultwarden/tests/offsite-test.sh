#!/usr/bin/env bash
#
# Test of scripts/offsite.sh (#263) with stubbed `restic` and `curl`: checks
# that stale locks are cleared before the backup, that a failed unlock stops
# the run without a heartbeat, and that a normal run sends the heartbeat.
# Needs bash and flock (`bash services/vaultwarden/tests/offsite-test.sh`).

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/offsite.sh"
T="$(mktemp -d)"
trap 'rm -rf "${T}"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; cat "${T}/out" >&2 2>/dev/null || true; exit 1; }
pass() { printf 'ok - %s\n' "$*"; }

mkdir -p "${T}/bin" "${T}/backups"
printf 'RESTIC_REPOSITORY=s3:example/bucket\n' > "${T}/restic.env"
# restic stub: logs its arguments, fails `unlock` when FAIL_UNLOCK is set.
# shellcheck disable=SC2016  # $1 and $* belong to the stub, not to this script
printf '#!/bin/sh\necho "$*" >> "%s/calls"\n[ "$1" = unlock ] && [ -n "${FAIL_UNLOCK:-}" ] && exit 1\nexit 0\n' \
  "${T}" > "${T}/bin/restic"
printf '#!/bin/sh\ncat > /dev/null\necho ping >> "%s/calls"\n' "${T}" > "${T}/bin/curl"
chmod +x "${T}/bin/"*

run() {
  rm -f "${T}/calls"
  PATH="${T}/bin:${PATH}" RESTIC_ENV_FILE="${T}/restic.env" BACKUP_DIR="${T}/backups" \
    XDG_RUNTIME_DIR="${T}" KUMA_PUSH_URL="https://kuma.example/push" \
    bash "${SCRIPT}" > "${T}/out" 2>&1
}

run || fail "normal run exited non-zero"
[ "$(head -n 1 "${T}/calls")" = "unlock" ] \
  || fail "first call is not a plain unlock (never --remove-all): $(head -n 1 "${T}/calls")"
[ "$(cut -d ' ' -f 1 "${T}/calls" | tr '\n' ' ')" = "unlock backup forget check ping " ] \
  || fail "unexpected call order: $(cut -d ' ' -f 1 "${T}/calls" | tr '\n' ' ')"
pass "stale locks cleared before backup, heartbeat sent"

if FAIL_UNLOCK=1 run; then fail "run succeeded although unlock failed"; fi
[ "$(cat "${T}/calls")" = "unlock" ] || fail "run went on after a failed unlock"
pass "failed unlock stops the run without heartbeat"
