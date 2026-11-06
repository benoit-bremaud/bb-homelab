# Bots Telegram — qui fait quoi

Inventaire de tous les bots Telegram créés par le propriétaire, homelab
et autres projets confondus, avec le service qui utilise chacun et la
décision prise à son sujet (issue #227).

## Règles

- Les tokens ne quittent jamais le gestionnaire de mots de passe et le
  `.env` (ou le credential n8n) du service qui les utilise. Ce document
  ne donne que le nom de l'entrée du gestionnaire.
- Un bot par usage : un service qui alerte ne partage pas son bot avec
  un autre projet.
- Un bot supprimé voit son token révoqué dans BotFather, puis la
  décision est notée dans `PROJECT_LOG.md`.

## Inventaire (relevé du 2026-11-06)

Le chat cible est celui du propriétaire (…7563) pour tous les bots.
« Dernier usage » est la date du dernier message visible dans la
conversation avec le bot.

| Bot | @username | Rôle | Utilisé par | Dernier usage | Entrée du gestionnaire | Décision |
|---|---|---|---|---|---|---|
| BB Infra Alerts | `@bb_infra_alerts_bot` | Alertes du homelab (sondes, sauvegardes, disques) | Uptime Kuma, notification `BB Infra Alerts` | 2026-11-05 | à compléter | garder |
| BB Homelab | `@bb_homelab_bot` | Aucun connu | Aucun service | 2026-06-16 | à compléter | supprimer (2026-11-06) |
| Impropedia Feedback | `@impropedia_feedback_bot` | Retours des correcteurs Impropedia | n8n, credential `Telegram account` ([services/n8n](../services/n8n/README.md)) | 2026-10-24 | à compléter | garder |
| Kaggle Watcher | `@kaggle_watcher_bb_bot` | Surveillance Kaggle | Kaggle watcher | 2026-10-24 | à compléter | garder, réservé à Kaggle |
| Feedback Pipeline | `@bbd_feedback_pipeline_bot` | Résumés des retours du site | `feedback-pipeline-worker` (projet benoitbremaud.fr) | 2026-10-31 | à compléter | garder |
| bb_notif | `@brasse_bouillon_notif_bot` | Notifications Brasse-Bouillon (inscriptions, alertes) | `brasse-bouillon` | 2026-11-02 | à compléter | garder |
| My Personal Crypto Balance Bot | `@BalanceBotWeeklyBot` | Solde crypto hebdomadaire | Plus utilisé | 2026-09-25 | à compléter | supprimer (2026-11-06) |

Décisions validées par le propriétaire le 2026-11-06. Un bot supprimé
est effacé dans BotFather (`/deletebot`), ce qui révoque son token,
puis son entrée est retirée du gestionnaire de mots de passe.

À identifier : le bot utilisé par `aristech` (variable `TELEGRAM_TOKEN`).

Hors inventaire, car ce sont des bots publics et pas ceux du
propriétaire : `@BotFather`, `@HealthchecksBot`, `@InfousersTgbot`.
