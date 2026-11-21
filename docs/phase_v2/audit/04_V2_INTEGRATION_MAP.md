# 04 — Carte d'intégration V1 → V2

Principe directeur [RECO] : **réutiliser le patron existant** « `XxxCore` (RefCounted pur, horloge injectée, `to_dict`/`from_dict`) + autoload façade enregistré via `SaveManager.register_system()` + config `.tres` dans `data/` + backend natif derrière une interface avec mock (comme `AdProvider`/`AnalyticsBackend`/`NotificationBackend`) ». Aucun nouveau manager ne doit dupliquer un manager existant.

## Vue d'ensemble

| Module V2 demandé | Décision | Existant réutilisé |
|---|---|---|
| 1. DailyChallengeManager | **Nouveau** | `Spawner`, `MetaClock`, `ClockGuard`, `RewardedSession`, `Game.seed_value` |
| 2. MarketOrdersManager | **Nouveau** | `Game`, `GameMeta`, `MissionsCore` (compteurs d'objectifs) |
| 3. IAPManager | **Nouveau** + backend natif | `Wallet`, `AdsConfig.interstitial_enabled`, patron `AdProvider` |
| 4. LeaderboardManager | **Nouveau** + backends Game Center / Play Games | entitlement Game Center, `SaveManager.best_score` |
| 5. AchievementManager | **Nouveau** | signaux `Game`, `GameMeta`, `Collection`, `Progression` |
| 6. CollectionManager | **Pas de nouveau manager** : étendre `Collection` / `CollectionCore` | `autoload/Collection.gd` |
| 7. CloudSaveManager | **Nouveau**, branché *dans* `SaveManager` | `SaveCodec`, `register_system` |
| 8. RemoteConfigManager | **Nouveau**, surcouche des `.tres` | toutes les ressources `data/*.tres` |
| 9. AnalyticsManager | **Pas de nouveau manager** : étendre `Analytics` | `autoload/Analytics.gd`, `AnalyticsBackend` |
| 10. PlayerProgressionManager | **Pas de nouveau manager** : étendre `Progression` | `autoload/Progression.gd`, `ProgressionCore` |

> Créer `CollectionManager`, `AnalyticsManager` ou `PlayerProgressionManager` à côté de `Collection`, `Analytics`, `Progression` créerait deux sources de vérité : à proscrire.

---

## 1. DailyChallengeManager
- **Réutiliser** : `Spawner.setup(seed)` (déjà déterministe, `test_spawner_same_seed_same_sequence`) ; `Game.seed_value` (`game.gd:38`, export déjà prévu) ; `MetaClock` / `ClockGuard` ; `AdsManager.show_rewarded` pour l'essai supplémentaire (nouveau placement dans `data/ads.tres`).
- **Modifier** : `scripts/main.gd` (`start_game(mode)`), `scripts/game.gd` (recevoir graine + mode sans toucher la boucle), `title_screen.gd` (bouton), `data/ads.tres` (placement `daily_extra`), `ProgressionCore` (déblocage `CHALLENGE`).
- **Nouveaux** : `scripts/meta/daily_challenge_core.gd`, `autoload/DailyChallenge.gd`, `data/daily_challenge.tres`, `scripts/ui/meta/challenge_panel.gd`.
- **Graine** : `hash([jour_UTC, "fv-daily", version_regles])` — **jour UTC** (TD-41), version des règles pour pouvoir changer l'équilibrage sans casser l'équité du jour.
- **Dépendances** : LeaderboardManager pour le classement du jour (optionnel en V2-1 : record local d'abord).
- **Risques** : régression de `game.gd` (mode classique doit rester identique) ; triche par changement d'horloge (réutiliser `ClockGuard`) ; non-déterminisme physique (TD-40).
- **Tests** : même jour UTC → même graine sur fuseaux différents ; 1 essai gratuit + 1 rewarded max ; horloge reculée → pas d'essai bonus ; mode classique inchangé (graine aléatoire).

## 2. MarketOrdersManager (Commandes)
- **Réutiliser** : signaux `Game.merged`, `dropped`, `danger_changed`, `game_over` ; `MissionDef.Kind` comme vocabulaire d'objectifs (MERGES, CREATE_RANK, SCORE_SINGLE…) ; `Wallet.earn` pour les récompenses.
- **Modifier** : `main.gd`, `game.gd` (fin de partie sur objectif atteint / lâchers épuisés : nouvelle « cause » passée à `GameMeta.finalize(cause)` qui accepte déjà une cause), `game_hud.gd` (affichage objectif).
- **Nouveaux** : `scripts/meta/orders_core.gd` (évaluation d'objectifs, étoiles), `autoload/MarketOrders.gd`, `scripts/data/order_def.gd`, `data/orders/*.tres` (**ne pas réutiliser** `data/levels.tres`, qui est la courbe XP), écran de sélection.
- **Risques** : collision de nom avec `LevelsConfig` ; lâchers limités = nouveau chemin de fin de partie non couvert par `DangerMonitor`.
- **Tests** : chaque type d'objectif, attribution 1/2/3 étoiles, meilleure note conservée, déblocage séquentiel, aucune récompense en double.

## 3. IAPManager
- **Réutiliser** : `Wallet.earn(amount, &"iap")` pour les packs de pièces ; `AdsConfig.interstitial_enabled` / `InterstitialPolicy.block_reason` pour « Retirer les pubs » (ajouter une raison `no_ads`) ; patron `AdProvider` pour `IapProvider` (Mock / GooglePlayBilling / StoreKit).
- **Modifier** : `autoload/AdsManager.gd` (respect du droit `no_ads` — **interstitiels seulement**, les rewarded restent proposés), `settings_panel.gd` (Restaurer les achats, obligatoire iOS).
- **Nouveaux** : `scripts/iap/iap_provider.gd`, `mock_iap.gd`, `google_billing_iap.gd`, `storekit_iap.gd`, `autoload/IAP.gd`, `data/iap.tres` (SKU), écran boutique.
- **Dépendances bloquantes** : plugins natifs Billing (Android) et StoreKit (iOS) — **nouvelle dépendance** à arbitrer ; produits créés dans les consoles ; contrat de paiement / fiscalité signés.
- **Risques** : droit stocké seulement en local (TD-12) ; achat validé mais crédit perdu si crash (acquitter **après** crédit + sauvegarde) ; double crédit ; App Review 3.1.1.
- **Tests** : achat → crédit unique ; achat en attente ; annulation ; restauration ; idempotence par jeton de transaction ; `no_ads` bloque l'interstitiel mais pas les rewarded.

## 4. LeaderboardManager
- **Réutiliser** : `SaveManager.best_score` / record de la semaine à ajouter ; entitlement Game Center déjà présent.
- **Nouveaux** : `scripts/social/leaderboard_backend.gd` (interface) + `game_center_backend.gd`, `play_games_backend.gd`, `mock_leaderboard.gd`, `autoload/Leaderboards.gd`.
- **Cross-platform** : Game Center et Play Games **ne sont pas cross-platform** entre eux. Un classement mondial commun Android+iOS impose un backend tiers (Firebase Firestore/Functions, ou autre) **+ authentification** → coût, RGPD, anti-triche serveur. [RECO] V2 : classements natifs par plateforme ; cross-platform reporté en V3 sauf décision business.
- **Risques** : connexion obligatoire perçue comme friction ; scores truqués (validation serveur impossible sans replay).
- **Tests** : mock — soumission différée hors ligne, file d'attente persistée, pas de soumission sans consentement/connexion.

## 5. AchievementManager
- **Réutiliser** : les mêmes signaux que `GameMeta` ; compteurs déjà persistés (`games_played`, `Collection.count()`, `Progression.level()`, `Wallet.core.earned_total`).
- **Nouveaux** : `scripts/meta/achievements_core.gd`, `autoload/Achievements.gd`, `data/achievements.tres` (30+ définitions, compteurs génériques), UI liste ; pont optionnel vers Game Center / Play Games.
- **Rétro-attribution** : au premier chargement V2, débloquer les succès déjà mérités à partir des données V1 (best_rank, games_played, album).
- **Tests** : déblocage unique, rétro-attribution depuis une sauvegarde V1, persistance.

## 6. Collection (évolution de l'album)
- **Modifier** : `CollectionCore` (ajouter compteurs par fruit — « 100 mangues » — et paliers), `Collection.gd`, `album_panel.gd`, `fruit_card.gd`.
- **Contrainte** : `from_dict` doit lire l'ancien format `{"found": [...]}` (cf. migration `save_codec.gd:migrate`) sans perte.
- **Tests** : sauvegarde V1 → album identique ; nouveaux compteurs à 0.

## 7. CloudSaveManager
- **Réutiliser** : `SaveCodec.encode/decode` (le blob cloud = le fichier v2 entier) ; `SaveManager.load_data/save_data`.
- **Modifier** : `SaveManager.gd` uniquement via un point d'extension (`after_save` / `merge_remote`) ; ne pas changer le format v2 (TD-11).
- **Nouveaux** : `scripts/platform/cloud_save_backend.gd` (interface) + Play Games Saved Games / iCloud (ou Firebase), `scripts/meta/save_merge.gd` (règle de fusion pure).
- **Règle de fusion [RECO]** : par système — max pour les compteurs monotones (best_score, xp, earned, album), union pour l'album, **le plus récent** pour les réglages, pièces = arbitrage explicite (risque de duplication/perte).
- **Prérequis bloquant** : TD-10 (TAMPERED sans sauvegarde de secours).
- **Tests** : matrice de fusion, conflit deux appareils, hors ligne, fichier V1 distant, fichier plus récent que la version locale.

## 8. RemoteConfigManager
- **Réutiliser** : les `.tres` restent la **valeur par défaut** hors ligne (exigence 100 % hors ligne).
- **Nouveaux** : `autoload/RemoteConfig.gd`, backend Firebase Remote Config (module Godotx à vérifier — **nouvelle dépendance native**), liste blanche de clés surchargeables avec bornes (ex. `coin_score_divisor ∈ [80, 300]`).
- **Règle** : valeurs appliquées **au lancement suivant** ou entre deux parties, jamais en cours de partie ; aucune clé de physique en V2 (risque de casser le « feel »).
- **Tests** : absence réseau → valeurs `.tres` ; valeur hors bornes ignorée ; aucune mutation pendant une partie.

## 9. Analytics (KPI V2)
- **Modifier** : `autoload/Analytics.gd` uniquement pour ajouter des propriétés utilisateur ; nouveaux événements émis par les nouveaux managers : `challenge_start/end`, `order_start/end(stars)`, `iap_view/purchase/restore`, `achievement_unlocked`, `leaderboard_submit`, `cloud_sync(result)`.
- **Contraintes** : garder le respect du consentement (`is_allowed()`), conventions Firebase (≤ 40 caractères, ≤ 25 paramètres).
- **Tests** : `MemoryAnalytics` (existant) pour vérifier chaque événement et l'absence d'envoi sans consentement.

## 10. Progression joueur
- **Modifier** : `ProgressionCore` (nouvelles constantes de déblocage : `CHALLENGE`, `ORDERS`, `SHOP`), `data/levels.tres` (niveaux de déblocage), `title_screen.gd`.
- **Contrainte** : ne pas changer la courbe XP V1 (`xp_thresholds`) → un joueur V1 garde son niveau. Les nouvelles fonctions débloquées à un niveau déjà dépassé doivent être annoncées une fois (popup « Nouveau ! »), pas silencieusement.
- **Tests** : sauvegarde V1 niveau 7 → mêmes niveau/XP, nouvelles fonctions accessibles.
