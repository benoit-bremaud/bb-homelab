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
5. Install Docker. Piping `curl ... | sh` as root is convenient but
   executes arbitrary network content with elevated privileges; download
   the script first and inspect it before running it:

   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   less get-docker.sh                 # quick sanity check
   sudo sh get-docker.sh
   rm get-docker.sh
   ```

   Alternatively, follow the official Docker Engine install steps for
   Debian/Raspberry Pi OS, which add Docker's apt repository and let you
   install via `apt install docker-ce docker-ce-cli containerd.io
   docker-buildx-plugin docker-compose-plugin`:
   <https://docs.docker.com/engine/install/debian/>.
6. Add your user to the docker group: `sudo usermod -aG docker $USER`,
   then log out and log back in.

SSH hardening (key-only auth, no root login) is tracked separately as
**issue #4**.
