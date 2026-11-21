# 07 — Feuille de route V2

Ordre fixé par trois critères : (1) prérequis techniques d'abord, (2) valeur rétention avant monétisation avancée, (3) **aucune nouvelle dépendance native avant que le cœur V2 soit validé**. Une phase ne commence qu'après la porte de validation de la précédente (règle CLAUDE.md §11).

## V2-0 — Fondations (aucune fonctionnalité joueur visible)
**Contenu**
- Localisation : `TranslationServer` + fichiers de traduction, extraction des textes FR existants (TD-01), EN complet, Wolof court.
- `SaveManager` : copie de secours en `TAMPERED` (TD-10), fixtures de sauvegardes réelles, test « module désactivé conservé » (TD-14).
- Crashlytics activé (plugin déjà embarqué, TD-20) + mise à jour Data Safety / App Privacy.
- CI GUT sur chaque PR (TD-33).
- Point d'extension « fin de partie » : managers V2 abonnés à `GameMeta.finalized` (TD-03).
- Remesure démarrage / FPS / taille sur version code 6 (référence de non-régression).
- Mise à jour de `CLAUDE.md` avec les faits de l'audit (TD-02).

**Porte G0** : 193 tests V1 + nouveaux verts ; jeu identique en FR ; EN jouable de bout en bout ; Crashlytics reçoit un crash de test ; aucune régression de démarrage > 10 %.

## V2-1 — Rétention (100 % hors ligne, pas de dépendance nouvelle)
**Contenu**
- `DailyChallenge` (graine UTC, 1 essai + 1 rewarded, record local du jour).
- `MarketOrders` (20–30 commandes, 3 étoiles, débloquées au niveau défini dans `data/levels.tres`).
- `Achievements` (30+, locaux, rétro-attribution V1).
- `Collection` étendue (compteurs par fruit, paliers).
- `Progression` : nouveaux déblocages + popup « Nouveau ! ».
- `Analytics` : événements V2.

**Porte G1** : tests Core + intégration verts ; sauvegardes V1/V2 réelles chargées sans perte ; test interne 1 semaine (Play fermé + TestFlight) : 0 crash bloquant, Vitals sous les seuils ; KPIs de base remontent dans Firebase.

## V2-2 — Monétisation (nouvelles dépendances natives)
**Prérequis** : décision sur les plugins Billing / StoreKit ; produits créés dans les consoles ; accords de paiement.
**Contenu**
- `IAP` : Retirer les pubs forcées (non-consommable + restauration), packs de pièces, pack de démarrage.
- Écran boutique.
- Interstitiel bloqué pour `no_ads` (rewarded conservés).

**Porte G2** : achats sandbox OK sur les 2 plateformes (achat, annulation, attente, restauration, réinstallation) ; aucun double crédit sur 100 achats simulés ; App Review acceptée.

## V2-3 — Services en ligne
**Contenu**
- `Leaderboards` natifs : Game Center (iOS) et Play Games (Android) — hebdo + global par plateforme ; classement du Défi du jour.
- `CloudSave` : Play Games Saved Games / iCloud (ou Firebase si cross-platform décidé).
- `RemoteConfig` borné (économie, fréquence interstitiel, interrupteurs de modules).

**Porte G3** : jeu 100 % jouable hors ligne (mode avion) ; file d'attente de scores fiable ; fusion cloud testée sur 2 appareils ; RemoteConfig désactivable sans nouvelle version.

## V2-4 — Options (décision business)
Classement **cross-platform** (backend + authentification), partage natif WhatsApp avec image, médiation pub (AppLovin MAX / LevelPlay), mobile money, mode Rush.

## Dépendances entre phases

```
V2-0 Fondations ──► V2-1 Rétention ──► V2-2 IAP ──► V2-3 En ligne ──► V2-4 Options
       │                  │                               ▲
       │                  └─ Défi du jour (local) ────────┘ (classement du jour)
       └─ TD-10 TAMPERED ─────────────────────────────────► CloudSave
```

| Dépendance bloquante | Bloque |
|---|---|
| Localisation (V2-0) | tous les nouveaux écrans |
| Correctif TAMPERED + fixtures (V2-0) | CloudSave |
| Plugins Billing / StoreKit (décision) | IAP |
| Play Games Services (plugin + console) | Leaderboards / CloudSave Android |
| Backend serveur + auth (décision) | classement cross-platform |
| Firebase Remote Config (module natif à vérifier) | RemoteConfig |

## Critères d'acceptation communs à chaque phase
- Aucun fichier de signature, identifiant d'application ou certificat modifié.
- Économie V1 inchangée sauf décision écrite.
- Valeurs d'équilibrage dans `data/`, jamais en dur.
- GDScript typé ; managers communiquant par signaux.
- Tests Core avant UI ; 193 tests V1 toujours verts.
- Démarrage et FPS dans les budgets de 06 §3.
