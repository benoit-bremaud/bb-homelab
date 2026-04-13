#!/usr/bin/env bash
# bb-homelab bootstrap — turn a freshly flashed Raspberry Pi (or any
# Debian/Raspberry Pi OS box) into a "ready to run services" machine.
#
# Idempotent: safe to re-run. Each step checks whether the desired state
# already holds before acting.
#
# Configurable via environment:
#   HOMELAB_HOSTNAME   target hostname               (default: bb-homelab)
#   HOMELAB_TZ         target timezone               (default: Europe/Paris)
#   HOMELAB_USER       user added to the docker group (default: $USER)
#   HOMELAB_SWAP_MB    swapfile size in MB           (default: 2048)
#
# Usage (from a fresh SSH session on the Pi):
#   curl -fsSL https://raw.githubusercontent.com/benoit-bremaud/bb-homelab/main/bootstrap/bootstrap.sh -o bootstrap.sh
#   less bootstrap.sh         # always inspect before running as root
#   sudo bash bootstrap.sh
#
# Or, if the repo is already cloned:
#   sudo bash bootstrap/bootstrap.sh

set -euo pipefail

# --- Configuration -----------------------------------------------------------

HOMELAB_HOSTNAME="${HOMELAB_HOSTNAME:-bb-homelab}"
HOMELAB_TZ="${HOMELAB_TZ:-Europe/Paris}"
HOMELAB_USER="${HOMELAB_USER:-${SUDO_USER:-${USER:-}}}"
HOMELAB_SWAP_MB="${HOMELAB_SWAP_MB:-2048}"

# --- Helpers -----------------------------------------------------------------

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Must run as root. Try: sudo bash $0"
  fi
}

require_debian_like() {
  if [ ! -f /etc/os-release ]; then
    die "/etc/os-release not found — unsupported system."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID_LIKE:-$ID}" in
    *debian*|*raspbian*) ;;
    *) warn "Untested on ${PRETTY_NAME:-this OS}. Continuing anyway." ;;
  esac
}

# --- Steps -------------------------------------------------------------------

step_apt_upgrade() {
  log "Updating apt index and upgrading installed packages…"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -yqq
}

step_install_tools() {
  log "Installing baseline tools (curl, htop, smartmontools, ufw, unattended-upgrades)…"
  DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
    ca-certificates curl htop smartmontools ufw unattended-upgrades
}

step_install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed ($(docker --version)). Skipping."
    return
  fi
  log "Installing Docker via the official convenience script…"
  local script
  script="$(mktemp)"
  curl -fsSL https://get.docker.com -o "$script"
  # We deliberately pin nothing here: the official script tracks the
  # current Docker stable release and is reviewed by the user via the
  # README before running.
  sh "$script"
  rm -f "$script"
  log "Docker installed: $(docker --version)"
  log "Compose plugin: $(docker compose version)"
}

step_add_user_to_docker_group() {
  if [ -z "${HOMELAB_USER}" ]; then
    warn "No target user resolved (HOMELAB_USER, SUDO_USER, USER all empty). Skipping docker group setup."
    return
  fi
  if ! id -u "$HOMELAB_USER" >/dev/null 2>&1; then
    warn "User '$HOMELAB_USER' does not exist on this system. Skipping."
    return
  fi
  if id -nG "$HOMELAB_USER" | tr ' ' '\n' | grep -qx docker; then
    log "User '$HOMELAB_USER' already in the docker group. Skipping."
    return
  fi
  log "Adding user '$HOMELAB_USER' to the docker group…"
  usermod -aG docker "$HOMELAB_USER"
  warn "Log out and log back in (or run 'newgrp docker') for the group change to take effect."
}

step_configure_swap() {
  if swapon --show=NAME --noheadings | grep -q .; then
    log "Swap already configured ($(swapon --show=NAME,SIZE --noheadings | tr '\n' ' '))."
    return
  fi
  log "Creating ${HOMELAB_SWAP_MB} MB swapfile at /swapfile…"
  fallocate -l "${HOMELAB_SWAP_MB}M" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  if ! grep -q '^/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >>/etc/fstab
  fi
}

step_set_timezone() {
  local current
  current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  if [ "$current" = "$HOMELAB_TZ" ]; then
    log "Timezone already $HOMELAB_TZ. Skipping."
    return
  fi
  log "Setting timezone to $HOMELAB_TZ…"
  timedatectl set-timezone "$HOMELAB_TZ"
}

step_set_hostname() {
  local current
  current="$(hostnamectl --static 2>/dev/null || hostname)"
  if [ "$current" = "$HOMELAB_HOSTNAME" ]; then
    log "Hostname already $HOMELAB_HOSTNAME. Skipping."
    return
  fi
  log "Setting hostname to $HOMELAB_HOSTNAME (was $current)…"
  hostnamectl set-hostname "$HOMELAB_HOSTNAME"
  # Keep /etc/hosts in sync so sudo and local DNS lookups stay happy.
  if grep -qE "^127\.0\.1\.1[[:space:]]+" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$HOMELAB_HOSTNAME/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "$HOMELAB_HOSTNAME" >>/etc/hosts
  fi
}

step_enable_unattended_upgrades() {
  log "Enabling unattended-upgrades for security packages only…"
  # Generate the default config (idempotent — debconf reuses existing answers).
  echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' \
    | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades
}

# --- Main --------------------------------------------------------------------

main() {
  require_root
  require_debian_like

  log "Configuration:"
  log "  hostname  = $HOMELAB_HOSTNAME"
  log "  timezone  = $HOMELAB_TZ"
  log "  user      = ${HOMELAB_USER:-<unresolved>}"
  log "  swap      = ${HOMELAB_SWAP_MB} MB"

  step_apt_upgrade
  step_install_tools
  step_install_docker
  step_add_user_to_docker_group
  step_configure_swap
  step_set_timezone
  step_set_hostname
  step_enable_unattended_upgrades

  log "Bootstrap complete."
  log "Next steps:"
  log "  - Log out / log back in so the docker group takes effect."
  log "  - Run 'docker run --rm hello-world' to verify Docker."
  log "  - Open the next backlog issues: SSH hardening (#4), Tailscale (#5)."
}

main "$@"
