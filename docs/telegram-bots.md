# Bots Telegram — qui fait quoi

Inventaire de tous les bots Telegram créés par le propriétaire, homelab
et autres projets confondus, avec le service qui utilise chacun et la
décision prise à son sujet (issue #227).

## Règles

- Les tokens ne vivent que dans le gestionnaire de mots de passe et dans
  la configuration du service qui les utilise (`.env`, credential n8n,
  notification Uptime Kuma, intégration Healthchecks.io), donc aussi
  dans ses sauvegardes. Ce document ne donne que le nom de l'entrée du
  gestionnaire.
- Un bot par domaine ([ADR 0004](decisions/0004-monitoring-architecture.md)) :
  les alertes d'infrastructure ont leur bot, chaque application a le
  sien ; aucun bot n'est partagé entre l'infrastructure et une
  application.
- Supprimer un bot : `/deletebot` dans BotFather (ce qui révoque son
  token), retirer son entrée du gestionnaire de mots de passe, noter la
  décision dans `PROJECT_LOG.md`. Avant, vérifier qu'aucun service de la
  colonne « Utilisé par » ne s'en sert encore.

## Inventaire (relevé du 2026-11-06)

Source : la liste des discussions de Telegram Web (aucune conversation
ouverte), croisée avec le dépôt, la configuration des services du Pi et
la liste des notifications d'Uptime Kuma. Un bot jamais démarré par le
propriétaire n'y apparaîtrait pas ; `/mybots` dans BotFather fait foi.

Chat cible : celui du propriétaire (…7563) pour Uptime Kuma et n8n ; à
vérifier pour les autres. « Dernier usage » est la date du dernier
message visible dans la conversation avec le bot.

| Bot | @username | Rôle | Utilisé par | Dernier usage | Entrée du gestionnaire | Décision |
|---|---|---|---|---|---|---|
| BB Infra Alerts | `@bb_infra_alerts_bot` | Alertes d'infrastructure (sondes, sauvegardes, disques, Pi injoignable) | Uptime Kuma (notification `BB Infra Alerts`) ; Healthchecks.io, intégration webhook en panne seulement (timers de `home-infra-watchdog`), ADR 0004 | 2026-11-05 | à compléter | garder |
| BB Homelab | `@bb_homelab_bot` | Aucun connu | Aucun service trouvé (Healthchecks.io à vérifier avant suppression) | 2026-06-16 | à compléter | supprimer (2026-11-06) |
| Impropedia Feedback | `@impropedia_feedback_bot` | Retours des correcteurs Impropedia | n8n, credential `Telegram account` ([services/n8n](../services/n8n/README.md)) | 2026-10-24 | à compléter | garder |
| Kaggle Watcher | `@kaggle_watcher_bb_bot` | Surveillance Kaggle | `n8n-kaggle-watcher` (n8n local du portable) | 2026-10-24 | à compléter | garder, réservé à Kaggle |
| Feedback Pipeline | `@bbd_feedback_pipeline_bot` | Résumés des retours du site | `feedback-pipeline-worker` (projet benoitbremaud.fr) | 2026-10-31 | à compléter | garder |
| bb_notif | `@brasse_bouillon_notif_bot` | Notifications Brasse-Bouillon (inscriptions, alertes) | `brasse-bouillon` | 2026-11-02 | à compléter | garder |
| My Personal Crypto Balance Bot | `@BalanceBotWeeklyBot` | Usage personnel | Plus utilisé | 2026-09-25 | à compléter | supprimer (2026-11-06) |

Décisions validées par le propriétaire le 2026-11-06.

À identifier : le bot utilisé par `aristech` (variables
`ARISTECH_TELEGRAM_TOKEN`, `ARISTECH_TELEGRAM_CHAT_ID`, ADR 0032 du
dépôt aristech).

Hors inventaire, car ce sont des bots publics et pas ceux du
propriétaire : `@BotFather`, `@HealthchecksBot`, `@InfousersTgbot`.
