# 08 — Synthèse décisionnelle

> Audit du dépôt au 21/11/2026 (commit `6939570`). Documents détaillés : 01 à 07 du même dossier.
> Note : le rapport « Bilan V1 et cap V2 » n'est pas dans le dépôt ; cette synthèse repose uniquement sur le code et les docs versionnés.

## 1. État réel de la V1
- Godot **4.7.2**, renderer Mobile, Jolt, ~15 700 lignes GDScript typé, architecture propre et homogène (logique pure `*Core` + autoloads façades + configs `.tres` + backends natifs derrière interfaces avec mocks).
- **193/193 tests GUT verts** (3 996 assertions, 137 s), exécutés pendant l'audit.
- Android 1.0.0 (code 6) et iOS 1.0 : AdMob rewarded (5 placements) + interstitiel encadré, UMP, Firebase Analytics + FCM, rappels locaux, économie, power-ups, missions, cadeau 7 j, album, XP — **opérationnels dans le code**.
- Écarts au cahier des charges : **pas de localisation** (FR en dur), Moment Baobab avec placeholder, partage sans plugin natif (copie presse-papiers), Game Center activé mais non utilisé, Crashlytics désactivé.

## 2. Immédiatement réutilisable
`Spawner` seedé, `MergeSystem`, `GameMeta` (bilan de partie), `Wallet`, `Progression`, `Collection`, `MissionsCore` (vocabulaire d'objectifs), `MetaClock`/`ClockGuard`, `RewardedSession`/`AdsManager`, `InterstitialPolicy`, `SaveManager.register_system` + `SaveCodec` v2, `Analytics` + `MemoryAnalytics`, scripts de build et contrôles (`check_build.sh`, `inspect_build.py`, `check_plist.py`).

## 3. À corriger avant / pendant la V2
1. Localisation absente (TD-01) — bloque tout nouvel écran.
2. `TAMPERED` efface la progression sans copie (TD-10) — bloque la sauvegarde cloud.
3. Clés de systèmes non enregistrés supprimées à l'écriture (TD-14) — règle à imposer aux modules V2.
4. Crashlytics désactivé (TD-20) — visibilité insuffisante pour une V2 à risque natif.
5. Pas de CI Android/GUT sur PR (TD-33).
6. Démarrage 4,5 s > objectif 3 s (TD-30) — budget à ne pas dégrader.

## 4. À développer
Défi du jour, Commandes du marché, Succès, IAP + boutique + restauration, Classements, Sauvegarde cloud, Remote Config, extensions d'Album/Progression/Analytics (sans nouveaux managers concurrents).

## 5. Risques majeurs
| Risque | Impact | Mitigation |
|---|---|---|
| Perte de sauvegarde (cloud, rollback, TAMPERED) | rétention, avis | format v2 conservé, correctif TAMPERED, fixtures réelles |
| Dépendances natives IAP / Play Games / Remote Config | crash, ANR, 16 Ko, taille | phases séparées, initialisation différée, `inspect_build.py` |
| Classement « cross-platform » | backend + auth + RGPD + triche | natifs par plateforme d'abord ; cross-platform = décision V2-4 |
| Équité du Défi | physique non déterministe entre appareils | promettre « mêmes fruits », graine UTC |
| App Review (IAP 3.1.1, restauration, ATT) | retard de sortie iOS | bouton Restaurer, notes de revue à jour |
| Régression du « feel » | cœur du jeu | aucune clé physique en Remote Config ; 193 tests V1 gardés |

## 6. Architecture V2 recommandée
Nouveaux autoloads **après** les existants : `DailyChallenge`, `MarketOrders`, `Achievements`, `IAP`, `Leaderboards`, `RemoteConfig`, et un `CloudSave` branché dans `SaveManager`. `Collection`, `Progression`, `Analytics` sont **étendus**, pas dupliqués. Chaque module = `*_core.gd` pur + autoload + `data/*.tres` + backend (interface + mock + natif). Les modes de jeu passent un « mode » à `Game` par composition ; les managers s'abonnent à `GameMeta.finalized`.

## 7. Ordre d'intégration
V2-0 Fondations → V2-1 Rétention (Défi, Commandes, Succès, Album, Progression, Analytics) → V2-2 IAP → V2-3 Classements, Cloud, Remote Config → V2-4 options.

## 8. Critères de validation
Portes G0–G3 détaillées dans `07_V2_ROADMAP.md` : tests verts (V1 + V2), sauvegardes réelles sans perte, Vitals sous seuils (plantage < 1,09 %, ANR < 0,47 %), démarrage ≤ V1 + 10 %, < 60 Mo, jouable hors ligne.

## 9. Blocages avant développement
- **Décisions à prendre** : plugins Billing/StoreKit et Play Games (nouvelles dépendances), cross-platform ou non, power-ups autorisés en Défi, niveaux de déblocage V2.
- **Comptes / consoles** : produits IAP, Play Games Services, Game Center leaderboards, accords de paiement.
- **Données** : chiffres réels Firebase / Vitals de la 1.0.0 (6) et état de la resoumission iOS (build 34) — non vérifiables depuis le dépôt.
- **Hygiène dépôt** : `assets/ui/letterbox_*.png` non suivis sur la branche `ios-metadata-4-1a` (à commiter ou écarter avant de brancher la V2 depuis `main`).

## Recommandation

### ✅ GO V2 SOUS CONDITIONS

La base V1 est saine, testée et conçue pour être étendue ; la V2 peut démarrer **à condition** de :
1. Ouvrir par la phase **V2-0 Fondations** (localisation, correctif TAMPERED + règle d'enregistrement des systèmes, Crashlytics, CI GUT) ;
2. Garder la V2-1 **sans nouvelle dépendance native** et 100 % hors ligne ;
3. Trancher les décisions de dépendances (IAP, Play Games, cross-platform) avant V2-2 / V2-3 ;
4. Confirmer la stabilité de la 1.0.0 (6) dans Android Vitals et l'acceptation iOS avant toute release V2.
