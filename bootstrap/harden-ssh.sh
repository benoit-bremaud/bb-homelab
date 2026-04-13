#!/usr/bin/env bash
# bb-homelab SSH hardening — disable password auth, disable root login,
# enforce key-only access, and ensure UFW allows SSH.
#
# Idempotent: each setting is checked before being applied; safe to
# re-run.
#
# Safety guarantees:
#   - Refuses to run if the target user has no authorized SSH keys
#     (prevents lock-out).
#   - Validates the new sshd_config with `sshd -t` before reloading.
#   - Uses `reload` (not `restart`) so the current SSH session stays
#     alive while the daemon picks up the new config.
#   - Backs up the original sshd_config to /etc/ssh/sshd_config.bak.<ts>
#
# Configurable via environment:
#   SSH_USER       user whose ~/.ssh/authorized_keys we verify
#                  (default: $SUDO_USER or current invoking user)
#   SSH_UFW_SCOPE  one of: any | lan | tailscale
#                  - any        : ufw allow 22/tcp from anywhere (default)
#                  - lan        : ufw allow 22/tcp from $SSH_LAN_CIDR
#                  - tailscale  : ufw allow 22/tcp from 100.64.0.0/10
#                                 (Tailscale CGNAT range — recommended once
#                                 issue #5 has installed Tailscale)
#   SSH_LAN_CIDR   required when SSH_UFW_SCOPE=lan, e.g. 192.168.1.0/24
#
# Usage:
#   sudo bash bootstrap/harden-ssh.sh
#   sudo SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh
#   sudo SSH_UFW_SCOPE=lan SSH_LAN_CIDR=192.168.1.0/24 bash bootstrap/harden-ssh.sh
#
# After running, **open a new terminal** and verify SSH still works
# before closing the current session.

set -euo pipefail

# --- Configuration -----------------------------------------------------------

SSH_USER="${SSH_USER:-${SUDO_USER:-${USER:-}}}"
SSH_UFW_SCOPE="${SSH_UFW_SCOPE:-any}"
SSH_LAN_CIDR="${SSH_LAN_CIDR:-}"
SSHD_CONFIG=/etc/ssh/sshd_config

# --- Helpers -----------------------------------------------------------------

log()  { printf '\033[1;34m[harden-ssh]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[harden-ssh]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[harden-ssh]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Must run as root. Try: sudo bash $0"
  fi
}

# --- Pre-flight checks -------------------------------------------------------

preflight_user() {
  if [ -z "${SSH_USER}" ]; then
    die "Could not resolve target user (SSH_USER, SUDO_USER, USER all empty)."
  fi
  if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    die "User '$SSH_USER' does not exist on this system."
  fi
  log "Target user: $SSH_USER"
}

preflight_authorized_keys() {
  local home keys
  home="$(getent passwd "$SSH_USER" | cut -d: -f6)"
  keys="$home/.ssh/authorized_keys"
  if [ ! -s "$keys" ]; then
    die "$keys is missing or empty for $SSH_USER. Disabling password auth would lock you out. Run \`ssh-copy-id $SSH_USER@<this-host>\` from your PC first, then re-run this script."
  fi
  local count
  count="$(grep -cE '^(ssh-|ecdsa-|sk-)' "$keys" || true)"
  if [ "$count" -eq 0 ]; then
    die "$keys exists but contains no recognised public keys (ssh-rsa / ssh-ed25519 / ecdsa-* / sk-*). Aborting."
  fi
  log "$keys looks good ($count public key(s))."
}

preflight_ufw_scope() {
  case "$SSH_UFW_SCOPE" in
    any|tailscale) ;;
    lan)
      if [ -z "$SSH_LAN_CIDR" ]; then
        die "SSH_UFW_SCOPE=lan requires SSH_LAN_CIDR (e.g. SSH_LAN_CIDR=192.168.1.0/24)."
      fi
      ;;
    *)
      die "Invalid SSH_UFW_SCOPE='$SSH_UFW_SCOPE'. Expected: any | lan | tailscale."
      ;;
  esac
}

# --- sshd_config tightening --------------------------------------------------

# set_sshd_directive KEY VALUE — idempotent. Only edits if the active value
# differs from the target. Comments out duplicates of the same key.
set_sshd_directive() {
  local key="$1" value="$2"
  local current
  current="$(awk -v k="$key" 'BEGIN{IGNORECASE=1} $1==k {print $2; found=1; exit} END{if(!found) print ""}' "$SSHD_CONFIG")"
  if [ "$current" = "$value" ]; then
    log "  $key already $value"
    return
  fi
  log "  setting $key $value (was: ${current:-<unset>})"
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$SSHD_CONFIG"; then
    sed -i "s|^[[:space:]]*#\?[[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$SSHD_CONFIG"
  else
    printf '\n%s %s\n' "$key" "$value" >>"$SSHD_CONFIG"
  fi
}

step_backup_sshd_config() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local bak="${SSHD_CONFIG}.bak.${ts}"
  cp -p "$SSHD_CONFIG" "$bak"
  log "Backed up $SSHD_CONFIG to $bak"
}

step_tighten_sshd() {
  log "Applying hardened sshd settings…"
  set_sshd_directive PasswordAuthentication no
  set_sshd_directive PermitRootLogin no
  set_sshd_directive ChallengeResponseAuthentication no
  set_sshd_directive KbdInteractiveAuthentication no
  set_sshd_directive PubkeyAuthentication yes
  set_sshd_directive UsePAM yes
}

step_validate_sshd_config() {
  log "Validating sshd_config with 'sshd -t'…"
  if ! sshd -t; then
    die "sshd -t failed — refusing to reload. Restore from backup if needed."
  fi
}

step_reload_sshd() {
  log "Reloading sshd (current session stays alive)…"
  if [ -d /run/systemd/system ]; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
  else
    service ssh reload 2>/dev/null || service sshd reload
  fi
}

# --- UFW ---------------------------------------------------------------------

step_configure_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    warn "ufw is not installed — skipping firewall step. Install it via bootstrap.sh first."
    return
  fi

  case "$SSH_UFW_SCOPE" in
    any)
      if ufw status | grep -qE '^22/tcp[[:space:]]+ALLOW[[:space:]]+Anywhere'; then
        log "ufw already allows 22/tcp from anywhere."
      else
        log "ufw: allowing 22/tcp from anywhere"
        ufw allow 22/tcp
      fi
      ;;
    lan)
      local rule="from ${SSH_LAN_CIDR} to any port 22 proto tcp"
      if ufw status | grep -qE "22/tcp[[:space:]]+ALLOW[[:space:]]+${SSH_LAN_CIDR//./\\.}"; then
        log "ufw already allows 22/tcp from ${SSH_LAN_CIDR}."
      else
        log "ufw: allowing 22/tcp from ${SSH_LAN_CIDR}"
        # shellcheck disable=SC2086
        ufw allow $rule
      fi
      ;;
    tailscale)
      if ufw status | grep -qE '22/tcp[[:space:]]+ALLOW[[:space:]]+100\.64\.0\.0/10'; then
        log "ufw already allows 22/tcp from Tailscale CGNAT range."
      else
        log "ufw: allowing 22/tcp from Tailscale (100.64.0.0/10)"
        ufw allow from 100.64.0.0/10 to any port 22 proto tcp
      fi
      ;;
  esac

  if ! ufw status | head -1 | grep -q "Status: active"; then
    warn "ufw is installed but inactive. Enable it explicitly with 'sudo ufw enable' once you've confirmed the rules above are correct."
  fi
}

# --- Main --------------------------------------------------------------------

main() {
  require_root

  log "Configuration:"
  log "  user            = $SSH_USER"
  log "  ufw scope       = $SSH_UFW_SCOPE"
  [ "$SSH_UFW_SCOPE" = "lan" ] && log "  lan cidr        = $SSH_LAN_CIDR"

  preflight_user
  preflight_authorized_keys
  preflight_ufw_scope

  step_backup_sshd_config
  step_tighten_sshd
  step_validate_sshd_config
  step_reload_sshd
  step_configure_ufw

  log "Hardening complete."
  log ""
  log "IMPORTANT — verify SSH still works BEFORE closing this session:"
  log "  1. Open a NEW terminal window on your PC."
  log "  2. Run: ssh ${SSH_USER}@<this-host>"
  log "  3. If it works, you can close this session safely."
  log "  4. If it fails, the original config is at \${SSHD_CONFIG}.bak.<timestamp>;"
  log "     restore with: sudo cp <backup> $SSHD_CONFIG && sudo systemctl reload ssh"
}

main "$@"
