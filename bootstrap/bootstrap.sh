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

has_systemd() {
  # /run/systemd/system is the canonical marker that systemd is the
  # active init (per `man systemd`). `command -v timedatectl` is not
  # enough: the binary may be installed without systemd actually
  # running (containers, WSL, chroots).
  [ -d /run/systemd/system ]
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
  local has_engine=false has_compose=false
  command -v docker >/dev/null 2>&1 && has_engine=true
  if [ "$has_engine" = "true" ] && docker compose version >/dev/null 2>&1; then
    has_compose=true
  fi

  if [ "$has_engine" = "true" ] && [ "$has_compose" = "true" ]; then
    log "Docker engine + Compose v2 already installed ($(docker --version | head -1)). Skipping."
    return
  fi

  if [ "$has_engine" = "true" ] && [ "$has_compose" = "false" ]; then
    # Engine present but Compose plugin missing — common on older installs.
    # Add the plugin without re-running the engine installer.
    log "Docker engine present but Compose v2 missing — installing docker-compose-plugin…"
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq docker-compose-plugin
    log "Compose plugin: $(docker compose version)"
    return
  fi

  log "Installing Docker via the official apt repository (GPG-verified)…"
  # GPG-verified apt repo install — the upstream get.docker.com pipe is
  # convenient but executes unverified shell as root. apt + signed
  # repository gives us integrity verification on every install/update.
  install -m 0755 -d /etc/apt/keyrings

  # Pick the right Docker repo path per distro. require_debian_like
  # accepts both Debian/Raspbian and Ubuntu (ID_LIKE=debian), but Docker
  # publishes them at different URLs and signs them with different keys.
  # shellcheck disable=SC1091
  . /etc/os-release
  local docker_repo
  case "$ID" in
    ubuntu)         docker_repo="ubuntu" ;;
    raspbian)       docker_repo="raspbian" ;;
    debian|*)       docker_repo="debian" ;;
  esac

  curl -fsSL "https://download.docker.com/linux/${docker_repo}/gpg" \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  local arch
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${docker_repo} ${VERSION_CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
  # Idempotency: only skip if the configured /swapfile is already active
  # at the configured size. Pre-existing distro swap (zram, default Pi
  # swapfile of a different size) does NOT count as "already done"
  # because it would silently ignore HOMELAB_SWAP_MB.
  local target_bytes=$((HOMELAB_SWAP_MB * 1024 * 1024))
  if swapon --show=NAME,SIZE --bytes --noheadings 2>/dev/null \
       | awk -v p=/swapfile -v s="$target_bytes" '$1==p && $2==s {found=1} END {exit !found}'; then
    log "Swap already configured at /swapfile (${HOMELAB_SWAP_MB} MB). Skipping."
    return
  fi

  # If /swapfile exists at the wrong size, swap it off and recreate.
  if [ -f /swapfile ]; then
    log "/swapfile exists but does not match target size — recreating."
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile
  fi

  log "Creating ${HOMELAB_SWAP_MB} MB swapfile at /swapfile…"
  fallocate -l "${HOMELAB_SWAP_MB}M" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  if ! grep -q '^/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >>/etc/fstab
  fi

  # Note: pre-existing distro swap (zram, etc.) is left alone on
  # purpose. HOMELAB_SWAP_MB only governs /swapfile.
}

step_set_timezone() {
  local current=""
  if has_systemd; then
    current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  elif [ -f /etc/timezone ]; then
    current="$(cat /etc/timezone)"
  fi

  if [ "$current" = "$HOMELAB_TZ" ]; then
    log "Timezone already $HOMELAB_TZ. Skipping."
    return
  fi

  log "Setting timezone to $HOMELAB_TZ…"
  if has_systemd; then
    timedatectl set-timezone "$HOMELAB_TZ"
  else
    # Non-systemd fallback (containers, WSL, chroot).
    if [ ! -f "/usr/share/zoneinfo/$HOMELAB_TZ" ]; then
      warn "Zoneinfo for '$HOMELAB_TZ' not found. Skipping."
      return
    fi
    ln -sf "/usr/share/zoneinfo/$HOMELAB_TZ" /etc/localtime
    echo "$HOMELAB_TZ" >/etc/timezone
  fi
}

step_set_hostname() {
  local current
  if has_systemd; then
    current="$(hostnamectl --static 2>/dev/null || hostname)"
  else
    current="$(hostname)"
  fi

  if [ "$current" != "$HOMELAB_HOSTNAME" ]; then
    log "Setting hostname to $HOMELAB_HOSTNAME (was $current)…"
    if has_systemd; then
      hostnamectl set-hostname "$HOMELAB_HOSTNAME"
    else
      # Non-systemd fallback (containers, WSL, chroot).
      echo "$HOMELAB_HOSTNAME" >/etc/hostname
      hostname "$HOMELAB_HOSTNAME"
    fi
  else
    log "Hostname already $HOMELAB_HOSTNAME."
  fi

  # Always reconcile /etc/hosts to the configured hostname, even if the
  # active hostname already matches. /etc/hosts can drift independently
  # (manual edit, image with stale 127.0.1.1 line) and would silently
  # break sudo + local DNS resolution.
  if grep -qE "^127\.0\.1\.1[[:space:]]+" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$HOMELAB_HOSTNAME/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "$HOMELAB_HOSTNAME" >>/etc/hosts
  fi
}

step_enable_unattended_upgrades() {
  log "Enabling unattended-upgrades for security packages only…"

  # Enable the periodic auto-update timer (idempotent).
  echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' \
    | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades

  # Enforce "security packages only" by overriding any patterns the
  # distro's 50unattended-upgrades may have set. APT list options like
  # Origins-Pattern are ADDITIVE across config files unless explicitly
  # cleared with `#clear`, so we drop the inherited list first.
  #
  # On Raspberry Pi OS, Raspbian itself does not ship a separate
  # security pocket: security fixes for Raspbian-only packages flow as
  # regular updates. We deliberately do NOT include
  # `origin=Raspbian,label=Raspbian` here because it would auto-update
  # *everything* from the main repo (not just security). Pi OS based
  # on Debian inherits Debian-Security via the configured ports repo,
  # which is matched by the Debian-Security pattern below.
  cat >/etc/apt/apt.conf.d/52unattended-upgrades-bb-homelab <<'CONF'
// Managed by bb-homelab/bootstrap/bootstrap.sh — edits will be overwritten.

// Discard whatever 50unattended-upgrades inherited so our list below
// is the single source of truth.
#clear "Unattended-Upgrade::Origins-Pattern";
#clear "Unattended-Upgrade::Allowed-Origins";

// Allow security updates only.
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};

// Never automatically reboot after unattended upgrades — even if a
// package signals it requires one. Service restarts stay manual to
// avoid surprise downtime.
Unattended-Upgrade::Automatic-Reboot "false";
CONF
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
