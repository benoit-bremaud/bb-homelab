# ADR 0007 — Ports publiés par Docker liés à la boucle locale et au tailnet

- **Status**: Accepted
- **Date**: 2026-11-02

## Context

L'audit de sécurité (#46, risque R10 de `docs/security/AUDIT.md`) a
montré que les ports publiés par Docker contournent UFW : Docker écrit
ses propres règles iptables dans la chaîne `FORWARD`, que la politique
`deny incoming` d'UFW ne filtre pas. Caddy (80, 443/tcp, 443/udp) et
Jellyfin (8096) écoutaient sur `0.0.0.0` et `[::]`, donc sur tout le
LAN, alors que les ADR 0002 et 0003 les destinent au tailnet.

Relevé du 2026-11-02 sur le Pi : sur 30 jours, les journaux de Caddy ne
montrent que des clients du tailnet, ceux de Jellyfin aucun client LAN ;
le tailnet ne compte que le Pi, un téléphone et un PC. Aucun appareil
hors Tailscale n'a besoin de ces ports. Le Pi pousse lui-même vers Uptime
Kuma par `127.0.0.1 status.bb-homelab.local` (#161).

## Decision

Lier chaque port publié de Caddy et de Jellyfin à `127.0.0.1` et à l'IP
tailnet du Pi (`100.121.134.61`), écrite en dur dans les compose : elle
est stable et déjà publique dans les README des services.

Docker démarre au boot sans attendre `tailscaled` ; le sysctl
`net.ipv4.ip_nonlocal_bind = 1` (`bootstrap/sysctl/`) permet la liaison
avant que `tailscale0` existe.

Matrice MCDA validée par le propriétaire (poids /100, notes 0–5) :

| Option | Exposition 35 | Risque 25 | Simplicité 20 | Usages LAN 20 | Total /500 |
|---|---|---|---|---|---|
| A. Liaison `127.0.0.1` + IP tailnet | 5 | 4 | 5 | 1 | **395** |
| B. Règles `DOCKER-USER` (after.rules) | 4 | 2 | 2 | 5 | 330 |
| D. Accepter l'exposition (ADR seul) | 0 | 5 | 5 | 5 | 325 |
| C. Outil tiers `ufw-docker` | 4 | 2 | 2 | 4 | 310 |

Sensibilité : si les usages LAN pèsent 40, D passe devant ; le relevé
des journaux montre qu'aucun usage LAN n'existe, donc A tient.

## Consequences

- Positives : plus aucun port de Caddy ni de Jellyfin sur le LAN, en
  IPv4 comme en IPv6 (la question de l'UDP/443 en IPv6 disparaît) ;
  décision déclarative et versionnée, aucune règle de pare-feu à
  maintenir.
- Négatives : un appareil du LAN sans Tailscale (TV, Chromecast) ne
  peut plus joindre Jellyfin ; il faudrait alors ajouter son accès par
  l'option B. Si l'IP tailnet du Pi change (nœud recréé), les deux
  compose sont à mettre à jour : Docker écoute alors sur une adresse
  morte sans erreur, et les sondes Kuma, qui passent par `127.0.0.1`,
  ne le voient pas. Reprise : nouvelle IP dans les deux compose, puis
  `docker compose up -d`.
- `ip_nonlocal_bind` vaut pour tout l'hôte (IPv4 seulement) : tout
  processus local peut se lier à une adresse que le Pi ne porte pas ;
  risque faible sur un Pi mono-utilisateur.
- Déploiement : installer le sysctl **avant** le `docker compose up -d`
  des deux services.
- Mosquitto 1883 (dépôt `home-assistant`) reste exposé sur le LAN, par
  choix (ESP32) : suivi dans ce dépôt.

## Alternatives considered

- **B. Chaîne `DOCKER-USER`** : filtre fin par hôte, mais règles iptables
  IPv4 et IPv6 hors des compose et modification du pare-feu d'un Pi
  joignable seulement par Tailscale.
- **C. `ufw-docker`** : même mécanisme que B, avec une dépendance tierce.
- **D. Accepter** : aucune réduction du risque.

## Refs

- #139, #46 (R10), #161
- ADR 0002, ADR 0003
- `services/caddy/docker-compose.yml`, `services/jellyfin/docker-compose.yml`,
  `bootstrap/sysctl/99-bb-homelab-nonlocal-bind.conf`
