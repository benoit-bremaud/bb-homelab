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

## Until the script lands

The script is tracked as **issue #3**. Manual procedure for now:

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
