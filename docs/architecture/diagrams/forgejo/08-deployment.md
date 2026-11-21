# dep — Forgejo — forge git sur le tailnet (prod)

> **Fonctionnalité** : issue #260 — déployer la forge git Forgejo
> **ADR liés** : ADR 0011 (Forgejo comme forge git), ADR 0009 (un réseau
> proxy par backend), ADR 0007 (liaison des ports publiés)
> **Décisions capturées** : image rootless LTS, base SQLite, web via
> Caddy sur `git.bb-homelab.local`, SSH intégré publié sur l'IP tailnet
> seule (port 2222), données sur `/mnt/appdata/forgejo`

## Contexte

Les projets personnels sont hébergés sur GitHub. Forgejo ajoute une
forge git auto-hébergée sur le Pi, joignable depuis le tailnet seul.

Ce diagramme montre où tourne Forgejo, par quels chemins un client
l'atteint et où vivent ses données. Il ne redessine pas les autres
backends (voir
[`network-isolation/08-deployment.md`](../network-isolation/08-deployment.md))
ni le détail de la sauvegarde (`storage/APPDATA-BACKUP.md`).

## Diagramme

```mermaid
flowchart TB
  client["«device» Poste du tailnet (navigateur, git)"]
  lan["«device» Machine hors tailnet"]

  subgraph pi5 ["«device» Raspberry Pi 5"]
    subgraph docker ["«executionEnvironment» Docker 29"]
      subgraph edge ["edge (bridge, route par défaut de Caddy)"]
        caddy["«artifact» caddy:2.11.8"]
      end
      subgraph netfj ["bb-homelab-proxy-forgejo"]
        fj["«artifact» forgejo:15.0.12-rootless (uid 1000)"]
      end
      subgraph netkuma ["bb-homelab-proxy-uptime-kuma"]
        kuma["«artifact» louislam/uptime-kuma"]
      end
    end
    subgraph hdd ["«device» HDD /mnt/appdata"]
      data["«artifact» forgejo/ (dépôts, SQLite, configuration)"]
    end
    backup["«artifact» ~/backups/forgejo/*.tar.gz (7 archives)"]
  end

  client -->|"HTTPS :443 git.bb-homelab.local (IP tailnet)"| caddy
  caddy -->|"HTTP :3000 via proxy-forgejo"| fj
  client -->|"SSH :2222 (IP tailnet seule, clé publique)"| fj
  lan -.->|"refusé : 443 et 2222 ne sont pas liés à l'IP du LAN"| pi5
  kuma -.->|"HTTPS :443 /api/healthz (alias explicite)"| caddy
  fj -->|"montage bind, create_host_path: false"| data
  fj -.->|"03:35 appdata-backup.sh (pause, docker cp)"| backup
```

Légende : Caddy est rattaché à `edge`, à `bb-homelab-proxy-forgejo` et
à `bb-homelab-proxy-uptime-kuma` ; Mermaid ne permet pas de dessiner un
nœud dans plusieurs sous-graphes, l'appartenance est donc portée par
les arêtes.

## Notes

- **Deux chemins d'entrée** : le web passe par Caddy (`tls internal`,
  filtre `tailnet_only`, seul `/api/healthz` reste ouvert) ; git en SSH
  arrive directement sur le serveur SSH intégré de Forgejo, sans passer
  par Caddy.
- **Port SSH** : publié sur `100.121.134.61:2222` seulement. Docker
  contourne UFW (ADR 0007) : la liaison à l'IP tailnet est le seul
  filtre, elle ne doit jamais devenir `0.0.0.0`. Le sshd de l'hôte
  (port 22) n'est pas concerné.
- **Authentification SSH** : par clé publique seulement, gérée dans
  Forgejo ; aucun compte système n'est créé sur le Pi.
- **Isolement** : Forgejo ne partage un réseau qu'avec Caddy
  (ADR 0009). Aucun autre backend ne le joint en direct.
- **Durcissement du conteneur** : utilisateur 1000, `cap_drop: [ALL]`,
  `no-new-privileges`, racine en lecture seule, `mem_limit` et
  `memswap_limit` à 512 Mo, `pids_limit` à 256 (même patron que les
  autres services, #256).
- **Données** : tout l'état vit sous `/mnt/appdata/forgejo` (dépôts,
  base SQLite, configuration). `create_host_path: false` empêche un
  démarrage sur la carte SD si le HDD n'est pas monté.
- **Hors périmètre** : pas de runner Forgejo Actions, pas d'inscription
  ouverte, pas d'exposition Internet.
- **Anti-pattern évité** : faire passer git par le sshd de l'hôte
  (compte `git` système et script relais), qui lie la forge à la
  configuration SSH d'administration du Pi.
