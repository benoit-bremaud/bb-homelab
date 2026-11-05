# ADR 0009 — Un réseau proxy par backend

- **Status**: Accepted
- **Date**: 2026-11-04

## Context

Le pentest du 2026-11-04 (carte CONTAINER, issue #200, gravité
moyenne) a montré que les six conteneurs web (Caddy, n8n, Jellyfin,
Uptime Kuma, Homepage, Vaultwarden) partagent un seul bridge externe,
`bb-homelab-proxy` (ADR 0002, point 2). Un processus dans n'importe quel
backend joint `vaultwarden:8080` en direct et contourne les règles que
Caddy applique au coffre : IP source limitée au tailnet, `/admin`
réservé au PC admin (#177, #179). Vaultwarden fait aussi confiance à
l'en-tête `X-Real-IP` : un client direct peut se faire passer pour le PC
admin auprès de l'alerte d'échec de connexion (#186) et du limiteur de
débit.

Les backends concernés tournent en root sans `cap_drop` (#160) et n8n
accepte des paquets communautaires (#196) : une prise de pied dans l'un
d'eux est plausible.

Contrainte : Uptime Kuma sonde aujourd'hui Vaultwarden, n8n et Caddy en
direct par leur nom DNS Docker sur ce même bridge.

## Decision

1. **Un bridge externe par backend**, nommé `bb-homelab-proxy-<svc>`
   (`-vaultwarden`, `-n8n`, `-jellyfin`, `-uptime-kuma`, `-homepage`).
   Seuls ce backend et Caddy le rejoignent. Chaque réseau est créé une
   fois sur l'hôte (`docker network create`) et déclaré
   `external: true` des deux côtés, pour la même raison de cycle de vie
   que l'ADR 0002.
2. **Un bridge `edge` propre à Caddy**, défini dans son compose et
   rejoint par aucun backend. Il porte la route par défaut de Caddy
   (`gw_priority`) et ses ports publiés. Sans lui, la passerelle de
   Caddy serait sur le bridge d'un backend, qui pourrait l'empoisonner
   en ARP (`NET_RAW` est accordé par défaut) et usurper une IP tailnet.
3. **Filtre tailnet sur tous les sites Caddy**, plus seulement sur
   Vaultwarden : toute IP hors `100.64.0.0/10` et `fd7a:115c:a1e0::/48`
   reçoit un 403, sauf le chemin de santé exact du service (bloc
   `tailnet_only` du Caddyfile). Sur Kuma, `/api/push/*` reste aussi
   ouvert : les scripts du Pi poussent via `127.0.0.1` (#161) et Caddy
   les voit depuis l'IP de la passerelle Docker. `/admin` de
   Vaultwarden reste réservé au PC admin. Tout autre appel lancé depuis
   l'hôte vers un site Caddy reçoit désormais un 403.
4. **Uptime Kuma sonde les backends via Caddy en HTTPS** sur leurs
   chemins de santé. Sur le réseau de Kuma, Caddy porte un alias Docker
   par nom de site, listé explicitement (Docker n'accepte pas de
   joker). Kuma ne monte que `root.crt` de la CA interne (en lecture
   seule, via `NODE_EXTRA_CA_CERTS`), jamais le dossier PKI qui
   contient les clés privées.

Matrices MCDA validées par le propriétaire (poids /100, notes 0–5) :

| Topologie | Sécurité 40 | Simplicité 25 | Cohérence 20 | Risque Pi 15 | Total /500 |
|---|---|---|---|---|---|
| A. Un réseau par backend | 5 | 3 | 5 | 3 | **430** |
| B. Vaultwarden et n8n seulement | 4 | 4 | 2 | 4 | 355 |
| C. Vaultwarden seul | 3 | 5 | 2 | 5 | 330 |

| Sondes Kuma | Isolement 40 | Signal 25 | Effort 20 | Risque 15 | Total /500 |
|---|---|---|---|---|---|
| A. Via Caddy en HTTPS | 5 | 5 | 2 | 3 | **410** |
| B. Kuma rejoint chaque réseau | 1 | 3 | 5 | 4 | 290 |
| C. Sondes TCP sur port hôte | 2 | 2 | 3 | 2 | 220 |

| Sites sans filtre | Latéral fermé 45 | KISS 30 | Clients 25 | Total /500 |
|---|---|---|---|---|
| A. Filtre tailnet partout | 5 | 3 | 3 | **390** |
| B. Risque documenté | 2 | 5 | 5 | 365 |

Sensibilité : la topologie A reste en tête même avec la simplicité à 40 ;
le filtre B passerait devant si le périmètre pesait plus de 40.

## Consequences

**Positive:**

- Parmi les conteneurs sur bridge, seul Caddy atteint Vaultwarden ;
  `X-Real-IP` ne peut plus venir que de Caddy, qui l'écrase.
- Un backend compromis ne gagne rien à passer par Caddy : il arrive
  d'une IP Docker et reçoit un 403 sur tous les sites.
- Les sondes Kuma testent aussi Caddy et TLS, de bout en bout.

**Negative:**

- Ajouter un service demande de créer son réseau, de l'ajouter au
  compose de Caddy et de recréer Caddy (plus un simple `caddy reload`).
  Chaque recréation fait tomber toutes les sondes ensemble : régler
  les sondes Kuma à au moins deux essais.
- La liste des alias Caddy sur le réseau de Kuma doit suivre le
  Caddyfile.
- Kuma doit être redémarré si la CA interne est régénérée.
- Le widget de statut Uptime Kuma prévu en L2 de l'[ADR 0006](0006-homepage-dashboard.md)
  est bloqué : Homepage n'atteint plus Kuma que par Caddy, et la page de
  statut y reçoit un 403. À rouvrir si le widget est repris.
- Écart avec l'[ADR 0001](0001-dip-layering.md) : Uptime Kuma dépend du
  chemin de stockage de Caddy (`root.crt` sous `/mnt/appdata/caddy/`)
  et non d'une abstraction ; limité à ce seul fichier public.

**Risque résiduel** : l'exemption `/api/push/*` de Kuma ne dépend que
du chemin : tout client qui atteint Caddy, backend compromis inclus,
peut appeler le push ; un jeton valide reste nécessaire. Restreindre
cette exemption à la passerelle `edge` : #217.

**Risque résiduel** : les conteneurs en `network_mode: host`
(cloudflared, Home Assistant) partagent l'espace réseau de l'hôte,
passerelle de tous les bridges, et joignent l'IP du conteneur
Vaultwarden. Hors du périmètre de #200 ; suivi dans #216.

## Alternatives considered

- **Kuma rejoint chaque réseau backend** : écarté, il redeviendrait le
  pivot que le correctif supprime.
- **Liste blanche du sous-réseau de Kuma dans Caddy** : demande un
  adressage IP figé et élargit la règle ; l'exemption par chemin de
  santé suffit.
- **Isoler seulement Vaultwarden et n8n** : laisse deux modèles de
  réseau et ne protège pas les autres sites.

## Refs

- Issue #200, rapport `docs/security/reports/2026-11-04-pentest.md`
- Remplace le point 2 de l'[ADR 0002](0002-caddy-reverse-proxy.md)
- [ADR 0007](0007-docker-published-ports-binding.md) — liaison des ports
- Diagramme
  [`08-deployment.md`](../architecture/diagrams/network-isolation/08-deployment.md)

## Bascule et retour arrière

Ordre sur le Pi, en présence du propriétaire :

1. Inventorier les sondes Kuma, les workflows n8n et les appels de Home
   Assistant qui joignent un autre service par son nom Docker ou son
   IP, et vérifier que `*.bb-homelab.local` ne résout qu'en IPv4
   tailnet sur les clients (aucun port n'est publié en IPv6 : la
   connexion serait refusée).
2. Créer les cinq réseaux, puis recréer Caddy (alias inclus).
3. Recréer chaque backend sur son réseau, puis basculer les sondes Kuma
   vers les noms Caddy (Kuma ne les résout qu'une fois recréé), puis
   supprimer `bb-homelab-proxy`.
4. Rejouer la carte LATERAL **par IP** depuis n8n, Jellyfin, Kuma et
   Homepage : la connexion à Vaultwarden:8080 doit échouer.

Retour arrière : `git revert` du changement, `docker network create
bb-homelab-proxy`, recréer les six conteneurs.
