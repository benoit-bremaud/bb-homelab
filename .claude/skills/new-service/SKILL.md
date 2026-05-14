---
name: new-service
description: Scaffold a new Docker service under services/<name>/ for bb-homelab. Creates docker-compose.yml (pinned image, joins bb-homelab-proxy network, named volume, healthcheck), README.md (French per docs-conventions), .env.example (placeholder values). Optionally appends a Caddy route. Invoke with /new-service <name> for any new container deployment.
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
   — `appdata` services keep a named Docker volume
   (`bb-homelab-<name>-data`); `archive` / `media` / `backup`
   services bind-mount to `/mnt/<role>/<service>/data` per
   Pattern Y (cf. `infra-patterns` skill §Pattern Y).

3. **Image + version** (pinned!)
   — e.g. `louislam/uptime-kuma:1.23.13`, never `:latest`.

4. **Required env vars** (e.g. `TZ`, custom API tokens, admin
   credentials)
   — placeholders go in `.env.example`, never real values.

5. **Persistent data location** (volume name)
   — convention: `bb-homelab-<name>-data`.

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
      - <name>_data:/<container-data-path>
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

volumes:
  <name>_data:
    name: bb-homelab-<name>-data
```

Replace `<name>`, `<NAME>`, `<registry>`, `<image>`, `<version>`,
`<container-data-path>`, `<healthcheck-command>` with the values
from Q&A.

## `README.md` template (French per `docs-conventions`)

````markdown
# services/<name>

<1-line purpose>.

## Stack

- Image : `<image>:<version>` (épinglée — bump déliberé via
  `.env`).
- Volume persistant : `bb-homelab-<name>-data`.
- Réseau : `bb-homelab-proxy` (partagé avec Caddy).
- URL interne : `https://<name>.bb-homelab.local` (via Caddy).

## Bootstrap

```bash
cd services/<name>
cp .env.example .env
# Éditer .env pour remplir les valeurs
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
