#!/usr/bin/env bash
# bb-homelab Tailscale installation — installs Tailscale from the
# official signed apt repository, then runs `tailscale up` so the user
# can authenticate the device against their Tailscale account.
#
# Idempotent: safe to re-run. Already-installed and already-connected
# cases are detected and skipped.
#
# Usage:
#   sudo bash network/install-tailscale.sh
#
# What to expect:
#   - If already connected, the script reports the Tailscale IP and
#     exits.
#   - Otherwise, `tailscale up` prints an auth URL. Open it in a
#     browser, sign in to your Tailscale account, approve the device.
#     The command then returns.
#
# After this script, the Pi is reachable from any other Tailscale-
# enabled device (laptop, phone) using its 100.x.y.z IP address.

set -euo pipefail

# --- Helpers -----------------------------------------------------------------

log()  { printf '\033[1;34m[tailscale]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tailscale]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[tailscale]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Must run as root. Try: sudo bash $0"
  fi
}

# --- Steps -------------------------------------------------------------------

preflight_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    die "curl is required but not installed. Run 'sudo apt-get install -y curl ca-certificates' (or run bootstrap.sh first), then re-run this script."
  fi
}

# resolve_distro_and_codename — sets DISTRO + CODENAME to values
# accepted by pkgs.tailscale.com. Dies with a clear message if the
# host's distro can't be mapped.
DISTRO=""
CODENAME=""
resolve_distro_and_codename() {
  if [ ! -f /etc/os-release ]; then
    die "/etc/os-release not found — cannot determine distro for Tailscale repo URL."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release

  case "$ID" in
    ubuntu)   DISTRO="ubuntu" ;;
    raspbian) DISTRO="raspbian" ;;
    debian)   DISTRO="debian" ;;
    *)
      die "Unsupported distro ID='$ID' (PRETTY_NAME='${PRETTY_NAME:-?}'). Tailscale's apt repo is published for debian / raspbian / ubuntu. Install manually from https://tailscale.com/download/linux for any other system."
      ;;
  esac

  # VERSION_CODENAME is the canonical field; some derivatives leave it
  # empty and expose UBUNTU_CODENAME instead.
  CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  if [ -z "$CODENAME" ] && command -v lsb_release >/dev/null 2>&1; then
    CODENAME="$(lsb_release -cs 2>/dev/null || true)"
  fi
  if [ -z "$CODENAME" ]; then
    die "Could not determine the distro codename (VERSION_CODENAME / UBUNTU_CODENAME / lsb_release -cs all empty). Tailscale apt URL would 404."
  fi
}

step_install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale already installed ($(tailscale version | head -1)). Skipping install."
    return
  fi

  preflight_curl
  resolve_distro_and_codename

  log "Installing Tailscale via the official signed apt repository (${DISTRO} / ${CODENAME})…"
  install -m 0755 -d /usr/share/keyrings
  curl -fsSL "https://pkgs.tailscale.com/stable/${DISTRO}/${CODENAME}.noarmor.gpg" \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL "https://pkgs.tailscale.com/stable/${DISTRO}/${CODENAME}.tailscale-keyring.list" \
    -o /etc/apt/sources.list.d/tailscale.list

  # Make both files world-readable so the unprivileged `_apt` user can
  # access them during `apt-get update`. Without this, a restrictive
  # root umask leaves the keyring at 0600 and apt fails verification.
  chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg
  chmod 0644 /etc/apt/sources.list.d/tailscale.list

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -yqq tailscale

  log "Tailscale installed: $(tailscale version | head -1)"
}

step_ensure_tailscaled_running() {
  # `tailscale status` / `tailscale up` need tailscaled. The package
  # post-install enables the unit on systemd hosts but it may have
  # been stopped/disabled, or we may be on a non-systemd host.
  if [ -d /run/systemd/system ]; then
    if ! systemctl is-active --quiet tailscaled; then
      log "Starting tailscaled service…"
      systemctl enable --now tailscaled
    fi
  else
    if ! service tailscaled status >/dev/null 2>&1; then
      log "Starting tailscaled service (non-systemd)…"
      service tailscaled start
    fi
  fi
}

step_connect_tailscale() {
  # `tailscale status` exits non-zero when logged out or not running,
  # and returns the "Logged out" marker in the first line. Use its exit
  # status as the simplest "already connected?" check.
  if tailscale status >/dev/null 2>&1; then
    log "Tailscale is already up. Current status:"
    tailscale status | sed 's/^/  /'
    return
  fi

  log "Starting Tailscale…"
  log "A browser-login URL will be printed below."
  log "Open it on any device with a browser, sign in to your Tailscale"
  log "account, approve this machine. The command will return once"
  log "authentication completes."
  echo
  # No flags: let Tailscale prompt with the default settings.
  tailscale up
}

step_show_connection_info() {
  echo
  log "Tailscale is up. Connection info:"
  log "  Hostname in tailnet : $(tailscale status --self --json 2>/dev/null | grep -oE '"DNSName": *"[^"]*"' | head -1 | cut -d'"' -f4 || echo '(unknown)')"
  log "  IPv4 address        : $(tailscale ip -4 2>/dev/null | head -1 || echo '(none)')"
  log "  IPv6 address        : $(tailscale ip -6 2>/dev/null | head -1 || echo '(none)')"
  echo
  log "From any other device on your tailnet you can reach this Pi via:"
  log "  ssh <user>@$(tailscale ip -4 2>/dev/null | head -1 || echo '<tailscale-ip>')"
  echo
  log "Once you've confirmed this works, you can tighten SSH to the"
  log "tailnet only by re-running:"
  log "  sudo SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh"
}

# --- Main --------------------------------------------------------------------

main() {
  require_root
  step_install_tailscale
  step_ensure_tailscaled_running
  step_connect_tailscale
  step_show_connection_info
}

main "$@"
