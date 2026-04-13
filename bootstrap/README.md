# bootstrap/ — Layer 3 (Host / OS)

Everything that turns a freshly flashed Raspberry Pi (or any Linux box)
into a "ready to host services" machine: kernel/OS settings, Docker
install, swap, hostname, time zone, security hardening.

## Target end state

A single command (`./bootstrap.sh`) brings any vanilla
Raspberry Pi OS Lite 64-bit machine to the same baseline:

- Latest security patches applied (`apt update && apt upgrade`).
- Docker engine + Compose v2 installed.
- Current user added to the `docker` group.
- Swap configured (zram or 2 GB swapfile, depending on RAM).
- Hostname + timezone set (Europe/Paris by default).
- `unattended-upgrades` enabled for security packages only.
- Useful CLI tools available: `htop`, `smartmontools`, `ufw`, `curl`.

## Running the script

```bash
# Option 1: from a fresh SSH session, fetch + inspect + run
curl -fsSL https://raw.githubusercontent.com/benoit-bremaud/bb-homelab/main/bootstrap/bootstrap.sh -o bootstrap.sh
less bootstrap.sh         # always inspect what you're about to run as root
sudo bash bootstrap.sh

# Option 2: from a clone of the repo on the Pi
git clone git@github.com:benoit-bremaud/bb-homelab.git
cd bb-homelab
sudo bash bootstrap/bootstrap.sh
```

Override defaults via environment variables:

```bash
sudo HOMELAB_HOSTNAME=my-pi HOMELAB_TZ=Europe/London \
  bash bootstrap/bootstrap.sh
```

The script is **idempotent** — every step checks whether the desired
state already holds before acting. Re-run it after a Raspberry Pi OS
upgrade or any time you want to converge the host back to baseline.

## Manual procedure (without the script)

If you'd rather do it by hand:

1. Flash Raspberry Pi OS Lite 64-bit with Raspberry Pi Imager. In
   Imager's "Advanced options": set hostname, username, password (or SSH
   key), enable SSH, configure wifi if needed.
2. Boot the Pi, find its IP via the home router admin page or
   `hostname -I` directly on the device.
3. SSH in: `ssh <user>@<ip>`.
4. Update the OS: `sudo apt update && sudo apt upgrade -y`.
5. Install Docker via the official **apt repository** (GPG-verified;
   preferred over `curl ... | sh` because every package install is
   integrity-checked):

   ```bash
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
     -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   . /etc/os-release
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
   https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin docker-compose-plugin
   ```

   See <https://docs.docker.com/engine/install/debian/> for the upstream
   reference.
6. Add your user to the docker group: `sudo usermod -aG docker $USER`,
   then log out and log back in.

SSH hardening (key-only auth, no root login) is tracked separately as
**issue #4**.
