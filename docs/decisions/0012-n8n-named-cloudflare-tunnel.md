# ADR 0012 — Tunnel Cloudflare nommé pour n8n

- **Status**: Accepted
- **Date**: 2026-11-22

## Context

n8n est exposé à Internet par cloudflared, seul chemin entrant vers le
Pi (box 5G sans IPv4 publique, ADR 0007). Jusqu'ici c'était un tunnel
rapide (`cloudflared tunnel --url`), au nom `*.trycloudflare.com`
aléatoire.

Deux problèmes :

1. **Le nom change à chaque recréation de cloudflared** (montée de
   version, redémarrage de Docker, reboot) : il faut alors corriger
   `WEBHOOK_URL` et `N8N_HOST` dans le `.env` du Pi, recréer n8n,
   repointer le moniteur Uptime Kuma et le widget Impropedia (audit de
   sécurité du 2026-10-23, R2 et R6, issue #143).
2. **Incident du 2026-11-22** : le connecteur n8n de claude.ai affiche
   « Server not responding ». n8n est sain (`/healthz` à 200,
   `/mcp-server/http` à 401 sans jeton) et l'OAuth aboutit (consentement
   donné, code et jeton de rafraîchissement en base), mais aucune requête
   MCP n'atteint n8n. La documentation Cloudflare indique que les
   tunnels rapides ne prennent pas en charge les Server-Sent Events : le
   bord met en tampon `text/event-stream`, sur lequel repose le transport
   HTTP streamable du serveur MCP de n8n.

Le propriétaire possède la zone `benoitbremaud.fr` chez Cloudflare (HSTS
avec `includeSubDomains` et preload).

## Decision

Remplacer le tunnel rapide par un **tunnel Cloudflare nommé, géré à
distance**, `bb-homelab-n8n`, avec le nom public stable
**`n8n.benoitbremaud.fr`** routé vers `http://127.0.0.1:5678`
(cloudflared reste dans le réseau de l'hôte).

- Le conteneur lance `tunnel --no-autoupdate run` ; le jeton vient du
  `.env` du Pi (`CLOUDFLARE_TUNNEL_TOKEN`, passé comme `TUNNEL_TOKEN`) ;
  le compose refuse de démarrer sans lui.
- n8n reçoit `N8N_HOST`, `N8N_WEBHOOK_URL` (qui remplace `WEBHOOK_URL`,
  dépréciée depuis n8n 2.35, #151) et `N8N_PROXY_HOPS=1`.
- Le jeton n'expire pas : rotation annuelle, procédure dans
  `services/n8n/README.md`.

Matrice MCDA validée par le propriétaire le 2026-11-22 (poids /100,
notes 0–5, total /500) : tunnel nommé **470**, Tailscale Funnel 410,
tunnel rapide gardé avec une liste de contrôle de rotation 155.

Nom d'hôte, matrice validée le 2026-11-22 :

| Critère (poids) | A. `n8n.` | B. `hooks.` | C. `automation.` |
| --- | --- | --- | --- |
| Clarté, correspondance au service (40) | 5 | 3 : ne couvre ni l'UI ni le MCP | 4 |
| Cohérence avec les noms Caddy internes (30) | 5 : schéma `<service>` | 2 | 2 |
| Discrétion face aux scans (30) | 2 : nomme le logiciel, déjà visible par l'UI | 4 | 4 |
| **Total /500** | **450** | 310 | 340 |

Sensibilité : avec la discrétion à 50 et la clarté à 20, A reste devant
(410 contre 360 pour C).

## Consequences

Positives :

- Le nom ne change plus : une recréation de cloudflared ne demande plus
  aucune correction (`.env`, moniteur, widget).
- Les Server-Sent Events passent : le connecteur MCP de claude.ai
  fonctionne.
- Le certificat est celui du bord Cloudflare ; le HSTS de la zone est
  respecté.
- Fini l'avertissement `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` d'express-rate-limit
  (`N8N_PROXY_HOPS=1`).

Négatives :

- Un secret de plus à garder : quiconque détient le jeton peut faire
  tourner le tunnel. Il vit dans le `.env` du Pi et le gestionnaire de
  mots de passe, avec une rotation annuelle.
- La route du nom public vit dans le tableau de bord Cloudflare, hors du
  dépôt ; elle est décrite dans `services/n8n/README.md`.
- L'éditeur n8n est joignable sur un nom stable, plus facile à trouver
  qu'un nom aléatoire. Un Cloudflare Access sur l'UI, hors webhooks, MCP
  et OAuth, réduirait cette surface : suivi à part.

## Alternatives considered

- **Tailscale Funnel (410)** : pas de domaine à gérer, mais un nom en
  `*.ts.net`, des ports imposés et un second rôle pour Tailscale, qui ne
  sert aujourd'hui qu'à l'accès privé.
- **Tunnel rapide avec liste de contrôle (155)** : ne règle ni la
  rotation du nom ni l'absence de Server-Sent Events, donc ni le
  connecteur MCP.

## Refs

- Issues #143, #151 ; audit `docs/security/AUDIT.md` (R2, R6) ; #28
  (achat du domaine)
- ADR 0007 (liaison des ports publiés), ADR 0009 (réseau proxy de n8n)
- `services/n8n/docker-compose.yml`, `services/n8n/README.md`
