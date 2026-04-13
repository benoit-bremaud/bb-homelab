# Tailscale

Tailscale is the VPN we use for remote access to the homelab. It gives
every device (the Pi, your laptop, your phone, invited family/troupe
members) a stable `100.x.y.z` IP on a private mesh network. No router
config, no port forwarding, no public IP exposure.

## Install on the Pi

See [install-tailscale.sh](install-tailscale.sh) — run it once on a
fresh Pi:

```bash
sudo bash network/install-tailscale.sh
```

The script installs Tailscale from its signed apt repository, then runs
`tailscale up` which prints a browser-login URL. Open it from any
device, sign in to your Tailscale account (free Personal plan, login
via Google / Microsoft / GitHub), approve the device. The Pi is now on
your tailnet.

## Install Tailscale on your own devices

You (and anyone you invite) needs Tailscale installed on each device
they will use to reach the Pi:

- Desktop / laptop (Linux, macOS, Windows): <https://tailscale.com/download>
- iOS / Android: App Store / Play Store, search "Tailscale"

On each device: install, sign in with the same account used on the Pi.
You're done — the device is on the tailnet.

## Reach the Pi

From any device on the tailnet, use either the Tailscale IP or the
MagicDNS hostname:

```bash
# Using the Tailscale IPv4 address (printed at the end of install-tailscale.sh)
ssh <user>@100.x.y.z

# Or, if MagicDNS is enabled (it is by default on the Personal plan)
ssh <user>@<pi-hostname>
```

## Inviting the circle of trust

When a service is ready to be shared (e.g. Nextcloud for family,
Jellyfin for the theatre troupe), invite the relevant people. Two
patterns:

### Pattern A — Share with an existing Tailscale user

If the person already has a Tailscale account (yours or someone else's
tailnet), use **node sharing**:

1. Go to <https://login.tailscale.com/admin/machines>
2. Click the Pi (or the specific service machine) → **Share** → enter
   the invitee's Tailscale email
3. They accept the invitation in their Tailscale admin. The shared
   machine appears on their tailnet as a read-only peer.

### Pattern B — Add them to your tailnet (family members)

If the person is family and you'll admin their Tailscale for them:

1. Go to <https://login.tailscale.com/admin/users>
2. **Invite users** → enter their email
3. They receive a sign-up link. Once signed in they install Tailscale
   on their devices and everything on your tailnet is visible.

Tailscale's Personal plan supports up to **100 devices** and
**3 users** for free. Beyond that: Personal Pro (free) or paid tiers.

## Tightening SSH to tailnet-only

Once Tailscale is up and you've confirmed SSH works via the tailnet,
lock SSH down so it's only reachable through Tailscale:

```bash
sudo SSH_UFW_SCOPE=tailscale bash bootstrap/harden-ssh.sh
```

This sets a `ufw` rule allowing port 22 only from `100.64.0.0/10` (the
Tailscale CGNAT range). SSH from the public internet or even from the
LAN (unless the LAN device is on the tailnet) is refused.

## Useful commands

```bash
tailscale status          # who's on the tailnet + health
tailscale ip -4           # this machine's Tailscale IPv4
tailscale ping <host>     # latency + routing (direct vs DERP relay)
tailscale up --reset      # re-authenticate from scratch
tailscale logout          # leave the tailnet (does not uninstall)
```
