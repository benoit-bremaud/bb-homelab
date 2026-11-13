# Diagramme d'activité — libérer de l'espace sur le téléphone

> **Fonctionnalité** : issue #224 — Immich, source des captures d'écran
> **ADR liés** : ADR 0010
> **Décisions capturées** : suppression sur le téléphone seulement après une
> copie vérifiée, captures de plus de 2 jours, premier test de restauration
> réussi

## Contexte

Une fois la pellicule vidée, Immich garde la seule copie vivante des
captures. Cette activité garantit qu'une capture n'est effacée du
téléphone qu'après sa sauvegarde hors du Pi.

## Diagramme

```mermaid
flowchart TD
  start([Le propriétaire veut libérer de l'espace]) --> drill{Premier test de<br/>restauration réussi ?}
  drill -- non --> wait([Ne rien supprimer : faire le test<br/>de restauration du runbook])
  drill -- oui --> copy{Captures visibles dans la<br/>copie du portable de la maison ?}
  copy -- non --> check([Vérifier la sonde Kuma<br/>et le timer de copie])
  copy -- oui --> age[Sélectionner les captures<br/>de plus de 2 jours]
  age --> free[Libérer de l'espace dans l'app Immich]
  free --> done([Fin])
```
