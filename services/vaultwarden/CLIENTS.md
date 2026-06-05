# Vaultwarden — Client onboarding

How to connect a Bitwarden client (browser extension, desktop app, CLI,
mobile) to the self-hosted Vaultwarden over the tailnet. The lightweight
clients — **not** the browser Web Vault — are the intended daily path.

This service is reachable **on the tailnet only**, behind Caddy with the
internal CA (ADR 0002, decision #28). Every client therefore needs two
one-time prerequisites: name resolution and trust of the internal CA.

## The two passwords — do not confuse them

There are two distinct secrets, for two different things:

- **Master password** — unlocks the **vault**. The raw password never
  leaves your device: the server only ever sees a derived authentication
  hash and stores an encrypted blob it cannot decrypt. It is
  **unrecoverable** if lost (no backup can restore it) and lives **only**
  in your external password manager.
- **Admin token** — the server `/admin` panel. Stored at rest as an
  Argon2 hash in `.env` (never plaintext); the plaintext lives only in
  your external password manager as a break-glass key.

> A client login (extension / app / mobile) uses the **master password**,
> never the admin token. The admin token is only for `/admin` in a
> browser.

## Why a client, not the browser Web Vault

- The **Web Vault** (the full single-page app at
  `https://vaultwarden.bb-homelab.local`) ships several MB of JavaScript.
  Over the Pi's relayed uplink it can time out — an infinite spinner. That
  is **bandwidth**, not a server fault (small API calls still answer
  instantly).
- The **browser extension** and **mobile app** are packaged clients:
  their UI is bundled locally and they only make small API calls (config,
  token, sync). They work fine on a slow link, and they keep an encrypted
  **local copy** of the vault — so autofill keeps working even if the Pi
  is offline (only new items wait for sync).

So the extension / app is the daily path. The Web Vault is for occasional
admin (e.g. encrypted exports) and only on a good link.

## Prerequisites — one-time, per client device

### 1. Name resolution

`vaultwarden.bb-homelab.local` must resolve to the Pi's Tailscale IP.

- **Desktop**: one line in `/etc/hosts` (see
  [../caddy/README.md](../caddy/README.md) for the IP and the shared
  routing convention).
- **Mobile**: needs split-DNS — see the **Mobile** section below.

### 2. Trust the internal CA

The client must trust the Caddy internal CA (ADR 0002), otherwise TLS is
refused. Export the CA root from Caddy on a machine with tailnet access:

```bash
ssh benoit@bb-homelab \
  'docker exec bb-homelab-caddy cat /data/caddy/pki/authorities/local/root.crt' \
  > ~/bb-homelab-root.crt
```

Verify it is the expected root:

```bash
openssl x509 -in ~/bb-homelab-root.crt -noout -subject -dates
# subject=CN = Caddy Local Authority - <year> ECC Root
```

Optional end-to-end sanity check — the whole chain (resolution + TLS via
the CA + Caddy vhost) is healthy if this returns a timestamp string:

```bash
curl -sf --cacert ~/bb-homelab-root.crt \
  https://vaultwarden.bb-homelab.local/alive
```

## Firefox — browser extension (the daily path)

Firefox keeps its **own** certificate store, separate from the system, so
the CA must be imported into Firefox itself. Do it from the Firefox menu —
safe while Firefox is running, and it targets the active profile (the one
where the extension is installed):

1. **Import the CA**:
   - `≡` menu → Settings → Privacy & Security → scroll to Certificates →
     View Certificates…
   - **Authorities** tab → Import… → choose `~/bb-homelab-root.crt`
   - tick "Trust this CA to identify websites" → OK

2. **Point the extension at the self-hosted server** (before logging in):
   - Click the Bitwarden extension icon.
   - On the login screen, open the region / server selector (top of the
     screen, or the gear) → choose **Self-hosted**.
   - Server URL: `https://vaultwarden.bb-homelab.local` → Save.

3. **Log in — not "Create account"**:
   - The extension defaults to the Bitwarden **cloud** and may offer
     "Create account". Do **not** create a cloud account.
   - Enter your account email (the one in your password manager) →
     Continue → master password → Log in.

4. **Verify**: open a site with saved credentials → the extension offers
   autofill; create a test item → it syncs to the Pi.

## Desktop app & CLI — optional

- **Desktop app**: `sudo snap install bitwarden`. Same self-hosted server
  URL and CA trust. Snap-confined apps read the **system** trust store, so
  also install the CA there:

  ```bash
  sudo cp ~/bb-homelab-root.crt \
    /usr/local/share/ca-certificates/bb-homelab-root.crt
  sudo update-ca-certificates
  ```

- **CLI (`bw`)**: `sudo snap install bw`, then point it at the server and
  log in:

  ```bash
  bw config server https://vaultwarden.bb-homelab.local
  bw login
  ```

  The CLI is what the separate `bb-vault` conventions toolkit will use
  later (`bw get …`) — tracked there, not here.

## Mobile — deferred

Not onboarded yet. Two frictions specific to our tailnet-only + internal
CA setup:

1. **Name resolution + TLS** — there is no `/etc/hosts` on mobile.
   Tailscale MagicDNS resolves the machine (`bb-homelab`) but **not** the
   Caddy vhost (`vaultwarden.bb-homelab.local`). Caddy does publish `:443`
   on the host, but it only routes that vhost — and presents its
   certificate — for the matching hostname, so reaching the Pi by IP does
   not help: the name still has to resolve and the certificate has to
   match.
2. **CA trust** — the Caddy CA must be installed on the phone.

Planned resolution: a split-DNS resolver on the tailnet (dnsmasq / CoreDNS,
or via Pi-hole — issue #24) that maps `*.bb-homelab.local` to the Pi's
Tailscale IP, declared as **split DNS** in the Tailscale admin; plus the CA
installed on the phone. Alternative: a public domain + Let's Encrypt
(decision #28) removes both frictions but is deferred; this client-pairing
work is tracked under issue #25.

## Troubleshooting

- **Infinite spinner** on `https://vaultwarden.bb-homelab.local` in a
  browser tab → the Web Vault SPA is too large for the current uplink. Use
  the extension instead; for the Web Vault, use a faster link.
- **"Secure Connection Failed" / certificate warning** → this client does
  not trust the Caddy CA. Re-do the CA import (Firefox: Authorities tab;
  system store: `update-ca-certificates`).
- **Extension stuck on cloud login / "Create account"** → the server URL
  was not set to self-hosted. Re-open the region selector and set
  `https://vaultwarden.bb-homelab.local` **before** logging in.
- **"Username or password is incorrect"** → you are using the admin token
  instead of the master password, or the email is wrong. A client login
  uses the **master password**.
- **Name does not resolve** → missing `/etc/hosts` line (desktop) or
  split-DNS not configured (mobile).

## Refs

- [README.md](README.md) — service overview, bootstrap, signup dance.
- [BACKUP.md](BACKUP.md) — backup / restore, break-glass, Tier-0 gate.
- [../caddy/README.md](../caddy/README.md) — CA export and `/etc/hosts`
  routing convention.
- ADR [0002](../../docs/decisions/0002-caddy-reverse-proxy.md) —
  internal Caddy reverse proxy + internal CA.
- ADR [0005](../../docs/decisions/0005-vaultwarden-deployment.md) —
  Vaultwarden deployment (tailnet-only, internal CA, Tier-0 gating).
- Issue #25 — Vaultwarden deployment (browser extension + mobile pairing
  acceptance criteria).
- Issue #24 — Pi-hole (potential split-DNS resolver for mobile).
