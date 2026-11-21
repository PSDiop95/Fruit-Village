# 02 — Inventaire des fonctionnalités V1

Statuts : **OPERATIONAL** (code présent, branché, testé) · **PARTIAL** (présent mais incomplet / écart au cahier des charges) · **NOT_IMPLEMENTED** (absent du code) · **NEEDS_VERIFICATION** (présent mais non vérifiable sans appareil / console store).

## A. Gameplay

| Fonctionnalité | Statut | Preuve | Remarque |
|---|---|---|---|
| Lâcher visé + cooldown 0,4 s | OPERATIONAL | `game.gd:292-345`, `data/game_config.tres` (`drop_cooldown`) | |
| 11 fruits, 5 lâchables pondérés | OPERATIONAL | `data/fruits.tres`, `scripts/data/fruit_catalog.gd`, `test_logic.gd` | poids 1 / 1 / 0,9 / 0,7 / 0,5 |
| Fusion sans double fusion | OPERATIONAL | `scripts/merge_system.gd`, `test_triple_contact_merges_only_one_pair` | ids 64 bits |
| Physique Jolt 2,5D, colliders calés sur modèles | OPERATIONAL | `project.godot`, `scripts/fruit.gd`, `collider_from_model=true` | |
| Génération seedée | OPERATIONAL (graine) | `scripts/spawner.gd`, `game.gd:79` | graine = horodatage ms si `seed_value == 0` ; **aucun mode n'injecte de graine fixe** |
| Fruit suivant (aperçu) | OPERATIONAL | `spawner.upcoming()`, `preview_count=1` | |
| Score + combo (fenêtre 1,5 s, max x8) | OPERATIONAL | `combo_tracker.gd`, `game.gd:_merge` | |
| Game over (alerte 1 s, fin 2 s) | OPERATIONAL | `danger_monitor.gd`, `game.gd:446` | |
| Moment Baobab | PARTIAL | `juice.gd:205-218, 498` : ralenti + effets ; baobab = **placeholder** (cylindre + sphères) | 500 pts (`top_merge_points`) |
| Power-ups Secouer / Pilon / Échange / Agrandir | OPERATIONAL | `scripts/powerup_controller.gd`, `data/powerups.tres` | Secouer gratuit via rewarded `shake_free` |
| « Continuer » après game over (1×/partie, retire 3 fruits) | OPERATIONAL | `game.gd:504`, `game_hud.gd:572-582` | |
| Bonus « Panier propre » | NOT_IMPLEMENTED | aucune occurrence | spec §5.1 |
| Objectif « Prochain fruit » / barre de record | NEEDS_VERIFICATION | HUD `game_hud.gd` (627 l.) | non audité ligne à ligne |
| Squash & stretch, visages, particules, hit-stop, shake | OPERATIONAL | `scripts/juice/*`, `test_juice.gd` (26 tests) | |
| Qualité auto Bas/Moyen/Haut | OPERATIONAL | `scripts/visual/visual_quality.gd`, `test_auto_quality_rules` | |

## B. Modes de jeu

| Mode | Statut | Remarque |
|---|---|---|
| Marché classique (infini) | OPERATIONAL | seul mode existant |
| Défi du jour | NOT_IMPLEMENTED | seule la brique `Spawner` seedée existe |
| Commandes du marché | NOT_IMPLEMENTED | `data/levels.tres` = courbe XP, **pas** des niveaux à objectifs (nom trompeur) |
| Rush 90 s | NOT_IMPLEMENTED | |

## C. Économie et progression

| Fonctionnalité | Statut | Preuve | Remarque |
|---|---|---|---|
| Pièces (gain score/150, plafond 999 999) | OPERATIONAL | `data/economy.tres`, `wallet_core.gd` | spec dit /100 : la valeur réelle est 150 |
| Achat de power-ups (200–300 pièces) | OPERATIONAL | `Wallet.buy_powerup`, `test_wallet_buy_powerup_and_stock` | |
| Doubler les pièces (rewarded) | OPERATIONAL | `game_meta.gd:grant_double_coins`, `game_hud.gd:604-625` | |
| Missions du jour (3, seedées joueur+jour) | OPERATIONAL | `missions_core.gd`, `data/missions.tres` (8 défs) | doublement rewarded `double_mission` |
| Cadeau de connexion 7 j + série + bouclier rewarded | OPERATIONAL | `daily_rewards_core.gd`, `data/daily_rewards.tres` | anti-triche horloge `clock_guard.gd` |
| Niveau joueur / XP, déblocages (missions 2, power-ups 3, cadeau 4, album 5) | OPERATIONAL | `progression_core.gd`, `data/levels.tres` | ordre différent de la spec (spec : missions 2, défi 3, Commandes 5) |
| Album 11 cartes « Le savais-tu ? » + thème doré | OPERATIONAL | `Collection.gd`, `data/fruits_lore.tres`, `album_panel.gd` | |
| Skins / étals / fonds achetables | PARTIAL | `basket_skin` (normal / gold) + 3 ambiances jour/coucher/nuit (`data/ambiances/`) | aucune boutique de skins |
| Succès (30+) | NOT_IMPLEMENTED | aucune occurrence | |
| Diamants (monnaie premium) | NOT_IMPLEMENTED | | |
| Sauvegarde locale v2 (checksum, atomique, migration v1→v2) | OPERATIONAL | `SaveManager.gd`, `save_codec.gd`, 3 tests | |
| Autosave en arrière-plan | OPERATIONAL | `SaveManager._notification` | uniquement si une sauvegarde est en attente |

## D. Publicités et monétisation

| Fonctionnalité | Statut | Preuve | Remarque |
|---|---|---|---|
| AdMob rewarded (5 placements) | OPERATIONAL | `data/ads.tres`, `AdsManager.gd` | continue, shake_free, double_coins, double_mission, streak_shield |
| Interstitiel (≥5e partie, 3 parties ET 180 s, 90 s après rewarded, 120 s de grâce) | OPERATIONAL | `interstitial_policy.gd`, 5 tests | |
| Consentement UMP + « Gérer mon consentement » | OPERATIONAL | `admob_ads.gd:start`, `settings_panel.gd` | en erreur UMP : pubs non personnalisées demandées quand même (`_consent_error`) |
| ATT (iOS) | NEEDS_VERIFICATION | `NSUserTrackingUsageDescription` dans le preset ; aucun appel ATT en GDScript | invite supposée portée par le message UMP/IDFA (cf. `docs/APP_REVIEW_NOTES.md`) |
| IDs prod/test séparés | OPERATIONAL | `scripts/ads/ad_ids.gd`, `ads_ids.cfg` (non versionné), `test_release.gd` | debug = toujours test |
| Init SDK différée (anti-ANR) | OPERATIONAL | `AdsManager.START_DELAY=1.5`, `START_FALLBACK=20` | correctif 1.0.0 (6) |
| Médiation (AppLovin, LevelPlay…) | NOT_IMPLEMENTED | classes d'extras du plugin présentes, non utilisées | |
| IAP / « Retirer les pubs » / restauration | NOT_IMPLEMENTED | aucun plugin Billing/StoreKit | |

## E. Backend et services

| Service | Statut | Preuve | Remarque |
|---|---|---|---|
| Firebase Analytics (Android + iOS) | OPERATIONAL (code) / NEEDS_VERIFICATION (données console) | `firebase_analytics.gd`, `firebase_boot.gd` | soumis au consentement + réglage `analytics_on` ; événements perdus avant init |
| Firebase Cloud Messaging | PARTIAL | `firebase_push.gd` | jeton reçu mais **jamais envoyé ni stocké** côté serveur ; campagnes console uniquement |
| Notifications locales (rappel + série, max 2/j) | OPERATIONAL (code) / NEEDS_VERIFICATION (appareils) | `Notifications.gd`, `notification_planner.gd` | |
| Crashlytics | NOT_IMPLEMENTED | `firebase/enable_crashlytics=false` | crashs vus uniquement via Android Vitals / Xcode Organizer |
| Game Center | PARTIAL | entitlement `game_center=true`, vérifié par `build_ios.sh:169-174` | **aucune intégration GDScript** (ni auth, ni classement) |
| Google Play Games | NOT_IMPLEMENTED | | |
| Identifiant joueur | NOT_IMPLEMENTED | `missions_core.player_seed` est une graine locale, pas un ID | |
| Sauvegarde cloud | NOT_IMPLEMENTED | | |
| Remote Config | NOT_IMPLEMENTED | | |
| Partage | PARTIAL | `share_service.gd` | plugin Share absent → image enregistrée + texte copié dans le presse-papiers (Android et iOS) ; appelé seulement depuis la carte d'album |

## F. Interface

| Écran | Statut | Fichier |
|---|---|---|
| Chargement | OPERATIONAL | `scripts/ui/loading_screen.gd` |
| Titre (Jouer, Réglages, Missions/Cadeau/Album verrouillés par niveau) | OPERATIONAL | `scripts/ui/title_screen.gd` |
| HUD de jeu + pause | OPERATIONAL | `scripts/game_hud.gd` |
| Fin de partie | OPERATIONAL | `scripts/ui/game_over_screen.gd` |
| Barre de power-ups (achat en jeu) | OPERATIONAL | `scripts/ui/meta/powerup_bar.gd` |
| Boutique dédiée | NOT_IMPLEMENTED | achats uniquement via la barre de power-ups |
| Album, Missions, Cadeau, Level-up | OPERATIONAL | `scripts/ui/meta/*` |
| Réglages (sons, vibrations, qualité, ambiance, notifications, statistiques, consentement, confidentialité) | OPERATIONAL | `scripts/ui/settings_panel.gd` |
| Adaptation écrans / zone sûre | OPERATIONAL (code) / NEEDS_VERIFICATION (parc) | `scripts/platform/screen_fit.gd` ; `assets/ui/letterbox_*.png` **non suivis par git** (travail en cours hors audit) |
| Localisation FR/EN/Wolof | NOT_IMPLEMENTED | aucun `tr()`, aucun `.po` ; textes FR en dur (UI + `display_name` des `.tres`) — reconnu dans `docs/m5_rapport.md` |

## G. Qualité

| Élément | Statut | Remarque |
|---|---|---|
| Suite GUT | OPERATIONAL | **193/193 verts, 3 996 assertions, 136,9 s** (exécution locale du 21/11/2026, Godot 4.7.2 headless) |
| CI Android | NOT_IMPLEMENTED | builds locaux uniquement |
| CI iOS | OPERATIONAL | `.github/workflows/ios.yml` (tests GUT en mode upload) |
| Mesures perf sur appareil modeste | PARTIAL | `docs/perf_m3.md` = PC Intel UHD ; Galaxy A23 : démarrage ≈ 4,5 s jusqu'au titre (`docs/m5_rapport.md`) |
| Taille | OPERATIONAL | AAB 78,6 Mo, téléchargement estimé 52 Mo arm64 (`docs/m5_rapport.md`, version code 1 — à remesurer pour code 6) |
