# FIRSTBOOT — from a fresh Pi 5 to a hardened, Tailscale-connected homelab

This is the end-to-end recipe that was actually proven to work on a
Raspberry Pi 5 + Raspberry Pi OS Lite 64-bit (Bookworm/Trixie-based).
Follow the steps in order. Every non-obvious gotcha the author hit
during the first run is called out inline.

Target end state at the bottom of this document:

- Pi boots 24/7 on ethernet
- SSH with public-key auth only, password auth disabled, root login
  disabled
- `sudo` requires a password (Pi OS's default NOPASSWD rule removed)
- Docker engine + Compose v2 ready to run services
- UFW active, port 22 allowed
- Tailscale up, the Pi reachable from anywhere at `100.x.y.z`

Total time: 30–60 minutes for a first-time run, ~15 minutes once you
have the recipe internalised.

---

## 0. Prerequisites

On your **PC**:

- `rpi-imager` installed (`sudo apt install -y rpi-imager` on
  Debian/Ubuntu, or from the Raspberry Pi Foundation site)
- An SSH keypair you'll use to reach the Pi. Per the author's
  per-context-key hygiene, generate a dedicated one:

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_bb-homelab \
    -C "benoit@bb-homelab" -N ""
  ```

- `gh` CLI logged in (optional but convenient for later steps)

Physical:

- Raspberry Pi 5 (4 GB or 8 GB RAM)
- Fresh microSD card (32 GB minimum; class A1 or better for random I/O)
- Official Raspberry Pi 5 USB-C power supply (5 V / 5 A). Generic chargers
  trigger undervoltage warnings and can cause random hangs.
- Ethernet cable (RJ45) to the home router. Wifi is possible but
  ethernet avoids a whole class of first-boot connectivity bugs.

---

## 1. Flash the SD card with `rpi-imager`

Launch `rpi-imager`, then:

1. **Choose device** → Raspberry Pi 5
2. **Choose OS** → Raspberry Pi OS (other) → **Raspberry Pi OS Lite
   (64-bit)**. *Lite*, not the desktop variant — a headless server
   doesn't need a graphical environment.
3. **Choose storage** → the SD card (double-check the capacity matches
   what you inserted; never pick your internal NVMe by mistake)
4. Click **Next** → **Edit Settings**:

   **General tab**
   - ☑ Set hostname → `bb-homelab`
   - ☑ Set username and password → `benoit` + a strong password
     (note it in your password manager)
   - ☐ Configure wireless LAN (leave unchecked — we use ethernet)
   - ☑ Set locale settings → `Europe/Paris` + keyboard `fr`

   **Services tab**
   - ☑ Enable SSH → **Allow public-key authentication only**
   - Paste the content of `~/.ssh/id_ed25519_bb-homelab.pub` into
     **authorized_keys for 'benoit'**

   **Options tab**
   - ☐ Play sound when finished (optional)
   - ☑ Eject media when finished
   - ☐ Enable telemetry (uncheck — no need to ping RPi Foundation)

5. **Save** → back on the main dialog, click **Yes** to apply the
   customisation, then flash.

Wait for **Write + Verify + Write Successful** before removing the SD.

### ⚠️ VERIFICATION — do this BEFORE inserting the SD into the Pi

`rpi-imager` has been observed to **silently fail** to inject the OS
customisation into cloud-init's `user-data` file on the bootfs
partition. When that happens, SSH never comes up, the hostname stays
`raspberrypi`, and the user you set in the UI never gets created.

**Always verify** right after flashing, while the SD is still in the
PC's reader:

```bash
# Wait a moment for the SD to re-mount automatically after eject
cat /media/$USER/bootfs/user-data
```

Expected: a non-empty YAML with **your** hostname, user, password
hash, and SSH key. If instead you see the default Ubuntu cloud-init
template with every directive commented out (lots of `#hostname:
raspberrypi` etc.), jump to the **Manual cloud-init fallback**
section below before proceeding.

---

## 1bis. Manual cloud-init fallback (only if verification failed)

Overwrite the broken `user-data` by hand.

First, generate a password hash (do NOT use the interactive prompt,
it's too error-prone — use the quoted form):

```bash
openssl passwd -6 "YOUR-STRONG-PASSWORD"
# output: $6$abc...$longHashHere...
```

Copy the hash. Then:

```bash
cat > /media/$USER/bootfs/user-data <<EOF
#cloud-config
hostname: bb-homelab
manage_etc_hosts: true

users:
- name: benoit
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: \$6\$PASTE-YOUR-HASH-HERE
  ssh_authorized_keys:
  - $(cat ~/.ssh/id_ed25519_bb-homelab.pub)

ssh_pwauth: false

timezone: Europe/Paris

keyboard:
  model: pc105
  layout: fr

runcmd:
- systemctl enable ssh
- systemctl start ssh
EOF
```

Note the backslash-escaped `\$6\$` — heredoc interprets `$` so the
hash needs escaping. Only the dollar signs in the hash need escaping;
the public key line substitutes at write time.

### The `ssh` sentinel file (always do this)

Pi OS Bookworm/Trixie disables `sshd` by default on first boot unless
either:

- cloud-init's `runcmd` explicitly enables it (the block above does
  that), OR
- an empty file named `ssh` is present on the bootfs partition

Belt and suspenders — create it regardless:

```bash
touch /media/$USER/bootfs/ssh
```

Eject cleanly before removing the card:

```bash
sudo umount /media/$USER/bootfs /media/$USER/rootfs 2>/dev/null
sudo eject /dev/sdX    # the SD device reported by lsblk
```

---

## 2. Insert the SD, boot the Pi, find its IP

1. Insert the SD into the Pi
2. Plug in ethernet
3. Plug in USB-C power (last) — the Pi starts booting
4. Wait **90–120 seconds** (first boot expands rootfs, runs cloud-init,
   reboots)

Find the LAN IP via your router's admin page:

- Bouygues box: `http://192.168.1.254` → **Appareils connectés** →
  look for `bb-homelab`
- Other boxes: same idea, the device name should match the hostname
  we set

Keep the IP handy (e.g. `192.168.1.216`).

---

## 3. First SSH

From the PC:

```bash
ssh -i ~/.ssh/id_ed25519_bb-homelab benoit@<LAN-IP>
```

Accept the host-key fingerprint (`yes`). You should land on
`benoit@bb-homelab:~ $` with no password prompt.

### If SSH is refused

Most of the time this is a timing issue — first boot's cloud-init is
still running. Wait 60–90 seconds more and retry.

If it's still refused after 3–4 minutes, eject + re-insert the SD into
the PC and re-verify `cat /media/$USER/bootfs/user-data` (step 1). If
still missing, go back to the **Manual cloud-init fallback** section.

---

## 4. Clone the repo and run `bootstrap.sh`

Pi OS Lite doesn't ship `git`. Install it once, then clone:

```bash
sudo apt update && sudo apt install -y git
```

Then clone. Two options — pick one.

**Option A — HTTPS (simplest, works immediately, no GitHub key needed):**

```bash
git clone https://github.com/benoit-bremaud/bb-homelab.git
cd bb-homelab
sudo bash bootstrap/bootstrap.sh
```

**Option B — SSH (required if you plan to push from the Pi):**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github \
  -C "bb-homelab-pi@github" -N ""
cat ~/.ssh/id_ed25519_github.pub
# Copy the output, add it at https://github.com/settings/ssh/new
# (title: "bb-homelab Pi", type: Authentication Key)

cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

ssh -T git@github.com  # confirm fingerprint, should say "Hi <you>!"

git clone git@github.com:benoit-bremaud/bb-homelab.git
cd bb-homelab
sudo bash bootstrap/bootstrap.sh
```

`bootstrap.sh` installs Docker + Compose, adds `benoit` to the
`docker` group, configures swap, hostname, timezone, and
unattended-upgrades. **5–10 minutes** on a Pi 5.

Log out and back in for the `docker` group change to take effect:

```bash
exit
# then from the PC
ssh -i ~/.ssh/id_ed25519_bb-homelab benoit@<LAN-IP>
docker run --rm hello-world   # should print the welcome banner
```

---

## 5. Remove the Pi OS NOPASSWD sudoers rule

Pi OS ships `/etc/sudoers.d/010_pi-nopasswd` that grants the main user
passwordless sudo. Acceptable on a throwaway dev board, **not**
acceptable on an internet-reachable server.

```bash
sudo rm /etc/sudoers.d/010_pi-nopasswd

# Verify sudo now asks for the password
sudo -k
sudo echo "now protected"   # prompts for password
```

---

## 6. Harden SSH

```bash
sudo bash ~/bb-homelab/bootstrap/harden-ssh.sh
```

The script:

- Refuses to run if `~/.ssh/authorized_keys` is empty (lock-out guard)
- Backs up `sshd_config`
- Sets `PasswordAuthentication no`, `PermitRootLogin no`,
  `PubkeyAuthentication yes`
- Validates with `sshd -t` before reloading
- Adds a UFW rule allowing port 22 (scope `any` by default)

**Critical verification** — open a **new terminal** on your PC and
`ssh benoit@<LAN-IP>`. If it works, you can close the original
session. If it fails, the previous `sshd_config` is at
`/etc/ssh/sshd_config.bak.<timestamp>`.

Activate UFW (the script left it inactive on purpose, so you test
the rule first):

```bash
sudo ufw enable     # 'y' to proceed
sudo ufw status verbose
```

---

## 7. Install Tailscale

```bash
sudo bash ~/bb-homelab/network/install-tailscale.sh
```

The script pulls the official apt repo, installs, and runs
`tailscale up` interactively.

### If `tailscale up` prints nothing

Observed on Pi OS Trixie / Tailscale 1.96.x: the interactive URL never
appears on the terminal, even though `tailscaled` is running and the
control plane is reachable. The auth-key flow works reliably as a
bypass:

1. From any browser, go to
   <https://login.tailscale.com/admin/settings/keys>
2. Click **Generate auth key**. Description: `bb-homelab Pi — first
   login`. Reusable: off. Ephemeral: off. 1 day expiration is fine.
3. Copy the key (`tskey-auth-...`). It's shown once.
4. On the Pi (Ctrl+C the stuck `install-tailscale.sh` first):

   ```bash
   sudo tailscale up --auth-key=tskey-auth-XXXXXX --hostname=bb-homelab
   sudo tailscale status
   tailscale ip -4
   ```

5. Install Tailscale on your PC too
   (`curl -fsSL https://tailscale.com/install.sh | sudo sh` +
   `sudo tailscale up`), sign in with the same account, then SSH the
   Pi via its `100.x.y.z` address to confirm the tunnel works
   end-to-end.

---

## 8. Optional — tighten SSH to the tailnet only

Once Tailscale is proven working, lock SSH down so only devices on
your tailnet can reach port 22:

```bash
sudo SSH_UFW_SCOPE=tailscale bash ~/bb-homelab/bootstrap/harden-ssh.sh
```

This replaces the broad `22/tcp ALLOW Anywhere` rule with an allow
scoped to Tailscale's CGNAT range (`100.64.0.0/10`). LAN and WAN SSH
is refused; only `ssh benoit@100.x.y.z` from a tailnet device works.

Test from a new terminal first, same drill as step 6.

---

## 9. You're done

At this point:

- `docker ps` on the Pi is empty but Docker + Compose are ready to run
  services
- From the PC: `ssh -i ~/.ssh/id_ed25519_bb-homelab benoit@<tailscale-ip>`
  works from anywhere on the tailnet
- UFW is the outer door; SSH + services bind on the right loopback or
  bridge; cloudflared tunnels expose only what needs public access
- The Pi will reboot automatically after power loss and pick up from
  where it left off thanks to `restart: unless-stopped` on every
  Compose service

Next: deploy your first service (e.g. `services/n8n/` — see
[../services/n8n/README.md](../services/n8n/README.md)).

---

## Troubleshooting — quick index

| Symptom | Where to look |
| --- | --- |
| Hostname stays `raspberrypi` on the router | Step 1 verification failed — see 1bis |
| SSH refused after 3+ minutes | cloud-init not applied, or `ssh` sentinel missing — see 1bis |
| `openssl passwd -6` keeps saying "Verify failure" | Use the quoted form: `openssl passwd -6 "password"` |
| `sudo` doesn't ask for a password | Step 5 not done — remove `/etc/sudoers.d/010_pi-nopasswd` |
| `tailscale up` prints nothing | Use the auth-key flow in step 7 |
| `docker compose up` fails with `unexpected type map[string]interface {}` | YAML parsing issue on an env var containing a colon followed by a space. Wrap the list entry in double quotes. |
| n8n starts but workflow doesn't trigger after migration | DB schema newer than image. Bump the image pin (see `services/n8n/.env.example`). |
