---
name: new-service
description: Scaffold a new Docker service under services/<name>/ for bb-homelab. Creates docker-compose.yml (pinned image, joins bb-homelab-proxy network, HDD bind-mount per Pattern Y, healthcheck), README.md (French per docs-conventions), .env.example (placeholder values). Optionally appends a Caddy route. Invoke with /new-service <name> for any new container deployment.
disable-model-invocation: true
---

# /new-service <name> — scaffold a new service

Run this skill to bootstrap the boilerplate for adding a new Docker
service to bb-homelab. Follows the `infra-patterns` skill conventions.

## Q&A — clarify with user FIRST

Before writing any file, gather these via `AskUserQuestion`:

1. **Service name** (e.g. `kuma`, `jellyfin`, `vaultwarden`)
   — kebab-case, becomes both the directory name and Caddy hostname.

2. **Role** (`appdata` / `archive` / `media` / `backup`)
   — determines the data location. Every role bind-mounts under the
   per-service directory `/mnt/<role>/<name>/` on the HDD per
   Pattern Y, with `create_host_path: false` (Docker refuses to start
   if the bind source is absent — the common "HDD not mounted" case;
   the real invariant is `mountpoint -q /mnt/<role>`, see LAYOUT.md).
   Mount the directory **directly** for a single-volume
   service (e.g. n8n → `/mnt/appdata/n8n`) or via **subdirs** for a
   multi-volume one (e.g. Caddy → host `/mnt/appdata/caddy/data` and
   `/mnt/appdata/caddy/config`, mapped to container `/data` and
   `/config`). See [storage/LAYOUT.md](../../../storage/LAYOUT.md) and
   the `infra-patterns` skill §Pattern Y.

3. **Image + version** (pinned!)
   — e.g. `louislam/uptime-kuma:1.23.13`, never `:latest`.

4. **Required env vars** (e.g. `TZ`, custom API tokens, admin
   credentials)
   — placeholders go in `.env.example`, never real values.

5. **Persistent data location** (host path)
   — convention: `/mnt/<role>/<name>/` (bind-mount, created on the HDD
   before first `up`; one or more subdirs if the service needs several
   volumes).

6. **Network needs**:
   - Just `bb-homelab-proxy` (typical web service)?
   - Plus other dependencies (e.g. Postgres)?

7. **Caddy route?**
   - If yes, hostname: `<name>.bb-homelab.local`
   - Port to forward to: `<name>:<port>`

8. **Issue / PR**:
   - Is there an existing issue tracking this service? If not,
     create one first.

## Scaffold layout

```text
services/<name>/
├── docker-compose.yml
├── README.md
├── .env.example
└── (optional) scripts/
    └── (helper scripts, e.g. backup.sh)
```

## `docker-compose.yml` template

```yaml
services:
  <name>:
    image: <registry>/<image>:${<NAME>_IMAGE_TAG:-<version>}
    container_name: bb-homelab-<name>
    restart: unless-stopped
    environment:
      - TZ=${TZ:-Europe/Paris}
      # (other env vars; secrets via .env)
    volumes:
      # Host bind-mount on the HDD (Pattern Y). create_host_path: false
      # makes Docker refuse to start if the source is absent (the common
      # HDD-not-mounted case) instead of auto-creating it on the SD card;
      # the real invariant is `mountpoint -q /mnt/<role>`. Create the dir
      # first: see storage/LAYOUT.md.
      # Single-volume default below (mounts the service dir directly).
      # For a multi-volume service, use subdirs instead, e.g.
      #   source: /mnt/<role>/<name>/data   target: /data
      #   source: /mnt/<role>/<name>/config target: /config
      - type: bind
        source: /mnt/<role>/<name>
        target: /<container-data-path>
        bind:
          create_host_path: false
    networks:
      - default
      - proxy
    healthcheck:
      test: ["CMD-SHELL", "<healthcheck-command>"]
      interval: 30s
      timeout: 5s
      retries: 5

networks:
  default:
    driver: bridge
  proxy:
    name: bb-homelab-proxy
    external: true
```

Replace `<name>`, `<NAME>`, `<role>`, `<registry>`, `<image>`,
`<version>`, `<container-data-path>`, `<healthcheck-command>` with the
values from Q&A.

## `README.md` template (French per `docs-conventions`)

````markdown
# services/<name>

<1-line purpose>.

## Stack

- Image : `<image>:<version>` (épinglée — bump déliberé via
  `.env`).
- Données persistantes : bind-mount `/mnt/<role>/<name>/` (HDD,
  Pattern Y).
- Réseau : `bb-homelab-proxy` (partagé avec Caddy).
- URL interne : `https://<name>.bb-homelab.local` (via Caddy).

## Bootstrap

```bash
cd services/<name>
cp .env.example .env
# Éditer .env pour remplir les valeurs
# Créer la cible bind-mount sur le HDD (le disque doit être monté) :
mountpoint -q /mnt/<role> || { echo "ERREUR : /mnt/<role> non monté"; exit 1; }
sudo mkdir -p /mnt/<role>/<name>
# Service multi-volumes : créer aussi chaque sous-dossier monté
# (sinon create_host_path: false fera échouer le démarrage), ex. :
#   sudo mkdir -p /mnt/<role>/<name>/data /mnt/<role>/<name>/config
docker compose up -d
docker compose logs -f <name>
```

## Configuration

(Variables d'environnement, comptes admin, étapes post-démarrage.)

## Opérations

(Backup / restore, mises à jour, troubleshooting.)
````

## `.env.example` template

```bash
# Copy to .env and fill in. .env is gitignored.

# Image tag — bump deliberately
# <NAME>_IMAGE_TAG=<version>

# Required secrets / config
# <NAME>_ADMIN_PASSWORD=<placeholder>
# <NAME>_API_TOKEN=<placeholder>
```

## Caddy route (if applicable)

Append to `services/caddy/Caddyfile`:

```caddyfile
<name>.bb-homelab.local {
    tls internal
    reverse_proxy <name>:<port>
}
```

Then reload Caddy:

```bash
docker exec bb-homelab-caddy caddy reload --config /etc/caddy/Caddyfile
```

And on each client device, add to `/etc/hosts`:

```text
100.121.134.61  <name>.bb-homelab.local
```

## ADR (if architectural decision involved)

If the new service introduces a non-trivial architectural choice
(new database type, new authentication, new public surface), write
an ADR per `docs-conventions` rule §ADR pattern.

## Open the PR

Use the `pr-cycle` skill: `/pr-cycle <issue-number>`.

Branch convention: `feat/<issue-number>-deploy-<name>`.

## Related

- `pr-workflow` skill — branch + commit + merge gate
- `infra-patterns` skill — Docker compose patterns
- `docs-conventions` rule — README language + structure
- `pr-cycle` skill — full PR workflow
