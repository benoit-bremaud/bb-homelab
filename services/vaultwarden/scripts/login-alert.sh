#!/usr/bin/env bash
# Alert on failed-login bursts against Vaultwarden (bb-vault#25).
#
# Counts the failed authentication lines Vaultwarden logs at ERROR level
# (wrong master password, wrong admin token, wrong 2FA code) over the last
# WINDOW, then reports to an Uptime Kuma Push monitor:
#   - count <  THRESHOLD -> status=up   (heartbeat)
#   - count >= THRESHOLD -> status=down (Kuma sends its notification)
# A missing heartbeat (cron or script broken) also turns the monitor DOWN,
# so silence is never mistaken for "no attack".
#
# Run from cron every WINDOW minutes, e.g.:
#   */5 * * * * KUMA_PUSH_URL="$(cat ~/.config/bb-homelab/kuma-push-vaultwarden-logins)" \
#     /bin/bash ~/bb-homelab/services/vaultwarden/scripts/login-alert.sh
#
# Environment:
#   KUMA_PUSH_URL   Push URL without query string (required, kept out of git)
#   VW_CONTAINER    container name (default bb-homelab-vaultwarden)
#   WINDOW          docker logs --since window (default 5m)
#   THRESHOLD       failures that trigger the alert (default 5)

set -euo pipefail

CONTAINER="${VW_CONTAINER:-bb-homelab-vaultwarden}"
WINDOW="${WINDOW:-5m}"
THRESHOLD="${THRESHOLD:-5}"

die() { printf '[login-alert] ERROR: %s\n' "$*" >&2; exit 1; }

[ -n "${KUMA_PUSH_URL:-}" ] || die "KUMA_PUSH_URL is not set"
case "${THRESHOLD}" in ''|*[!0-9]*) die "THRESHOLD must be a positive integer" ;; esac

PATTERN='Username or password is incorrect|Invalid admin token|Invalid TOTP code|Invalid two factor|Invalid WebAuthn'

# grep -c exits 1 on zero matches; that is a valid result, not an error.
logs="$(docker logs --since "${WINDOW}" "${CONTAINER}" 2>&1)" || die "cannot read logs of '${CONTAINER}'"
count="$(printf '%s\n' "${logs}" | grep -c -E "${PATTERN}" || true)"

if [ "${count}" -ge "${THRESHOLD}" ]; then
  status="down"
  msg="${count}_failed_logins_in_${WINDOW}"
else
  status="up"
  msg="OK_${count}_failures"
fi

# -K - keeps the token out of the process list.
printf 'url = "%s?status=%s&msg=%s&ping="\n' "${KUMA_PUSH_URL}" "${status}" "${msg}" \
  | curl -fsS -m 10 --retry 2 -o /dev/null -K - \
  || die "push to Uptime Kuma failed"

printf '[login-alert] %s: %s failures in %s\n' "${status}" "${count}" "${WINDOW}"
