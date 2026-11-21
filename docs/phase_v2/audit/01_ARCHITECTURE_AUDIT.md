# 01 — Audit d'architecture (V1 en production)

> Audit du 21/11/2026, branche `ios-metadata-4-1a` (commit `6939570`). Lecture seule : aucun fichier existant modifié.
> Convention : **[FAIT]** = constaté dans le dépôt (chemin cité) ; **[RECO]** = recommandation.

## 1. Moteur et configuration

| Élément | Valeur | Source |
|---|---|---|
| Moteur | **Godot 4.7.2 stable** (binaire local `C:/Program Files/Godot/Godot.exe`, CI iOS : cache `godot-4.7.2`) | `project.godot` (`config/features = "4.7","Mobile"`), `.github/workflows/ios.yml` |
| Renderer | `mobile` | `project.godot [rendering]` |
| Physique | **Jolt Physics** (intégré) | `project.godot [physics]` |
| Résolution | 1080×1920 portrait, `canvas_items` + `keep_width` | `project.godot [display]` |
| Mise à l'échelle 3D | `scaling_3d/mode=1` (FSR1), `scale=0.8` | `project.godot` — ⚠️ voir dette TD-04 |
| Scène principale | `res://scenes/Main.tscn` | `project.godot` |
| Langage | GDScript typé, ~15 700 lignes (scripts + autoloads + tests) | `wc -l` |

[FAIT] Le fichier `CLAUDE.md` cite « Godot 4.4+ », `data/physics.tres`, `locale/*.po`, `scripts/Juice.gd` : la réalité est 4.7.2, `data/game_config.tres`, **aucun dossier `locale/`**, `scripts/juice/juice.gd`. Le cahier des charges n'est plus une description fidèle du code.

## 2. Arborescence réelle

```
autoload/        10 singletons (voir §3)
data/            16 ressources .tres d'équilibrage (+ data/ambiances/*.tres)
scenes/          Main.tscn, Game.tscn (le reste est construit en code)
scripts/
  game.gd, fruit.gd, merge_system.gd, spawner.gd, combo_tracker.gd,
  danger_monitor.gd, powerup_controller.gd, game_hud.gd, main.gd, fruit_badge.gd
  ads/           AdProvider (interface), AdMobAds, MockAds, AdIds, overlays mock
  analytics/     AnalyticsBackend (interface), FirebaseAnalytics, Console, Memory
  data/          classes Resource des configs (FruitDef, EconomyConfig, AdsConfig…)
  meta/          logique pure testable : *_core.gd, SaveCodec, InterstitialPolicy,
                 RewardedSession, MetaClock/FakeClock, ClockGuard, GameMeta
  platform/      FirebaseBoot, FirebasePush, MobileNotifications, NotificationPlanner,
                 ScreenFit, ShareService
  juice/         Juice (855 l.), FruitVisual, FruitFace, particules, pool, shake, time scaler
  visual/        MarketScene, FruitModels, FruitBatcher, Mascot, VisualQuality, FestiveLights
  ui/            TitleScreen, GameOverScreen, SettingsPanel, LoadingScreen, UiTheme, meta/*
  debug/         PerfProbe
tests/unit/      9 fichiers GUT, 193 tests
tools/           build Android/iOS, contrôle AAB, Blender, captures store, simulateur d'économie
addons/          admob, godotx_firebase, NotificationSchedulerPlugin, GMPShared, gut, _fv_release
android/         template Gradle + .aar Firebase (core, analytics, messaging)
ios/plugins/     NotificationSchedulerPlugin (xcframework statique)
store/           fiches FR/EN Play + iOS, app-ads.txt
docs/            rapports M3–M5, IOS_RELEASE, PLAY_CONSOLE, QA_CHECKLIST, LAUNCH_PLAN…
```

Constat d'architecture [FAIT] : schéma **« Core pur + autoload façade »** appliqué de façon homogène :
`WalletCore`/`Wallet`, `ProgressionCore`/`Progression`, `CollectionCore`/`Collection`, `MissionsCore`/`Missions`, `DailyRewardsCore`/`DailyRewards`, `InterstitialPolicy`/`AdsManager`. Les *Core* sont des `RefCounted` sans dépendance au moteur, horloge injectée (`MetaClock`/`FakeClock`) → testables. **C'est le patron à reproduire en V2.**

Les UI sont construites en code (pas de `.tscn` par écran) : seules `Main.tscn` et `Game.tscn` existent.

## 3. Autoloads (ordre de chargement = `project.godot`)

| # | Autoload | Rôle | Clé de sauvegarde |
|---|---|---|---|
| 1 | `SaveManager` | Fichier `user://save.json` (format v2), réglages, `register_system()` | `core` |
| 2 | `Audio` | Musique, SFX, voix, vibrations | — |
| 3 | `Analytics` | Façade d'événements, consentement | — |
| 4 | `Wallet` | Pièces + stock de power-ups | `wallet` |
| 5 | `Progression` | XP, niveau, déblocages | `progression` |
| 6 | `Collection` | Album 11 fruits, thème doré | `collection` |
| 7 | `Missions` | 3 missions/jour seedées par joueur | `missions` |
| 8 | `DailyRewards` | Calendrier 7 j, série, bouclier | `daily` |
| 9 | `AdsManager` | Consentement UMP, rewarded, interstitiel | `ads` |
| 10 | `Notifications` | Rappels locaux + push FCM | — |

[FAIT] L'ordre compte : `SaveManager._ready()` charge le fichier **avant** que les autres autoloads s'enregistrent ; `register_system()` pousse immédiatement l'état lu. Tout nouveau manager V2 persistant doit être placé **après** `SaveManager` (et après `Wallet`/`Progression` s'il les utilise dans `load_state`).

Couplages directs entre autoloads [FAIT] : `Progression → Wallet, Analytics` ; `Collection → SaveManager.set_setting` ; `Notifications → DailyRewards, Progression` ; `AdsManager → Analytics.set_consent` ; `GameMeta → Wallet, Missions, Progression, Collection, AdsManager, Analytics`. Ces dépendances sont implicites (ordre d'autoload), non documentées ailleurs.

## 4. Flux principal

`Main.tscn` (`scripts/main.gd`) → `LoadingScreen` (cache shaders) → `TitleScreen` → `start_game()` instancie `Game.tscn` (`scripts/game.gd`) qui construit en code : environnement, panier, `GameMeta`, `PowerupController`, `GameHud`, `Juice`, `Mascot`, `FruitBatcher`. Rejouer : `main._replay()` tente un interstitiel (`AdsManager.try_interstitial(start_game)`, `main.gd:95`).

Boucle physique (`game.gd:379`) : `_rescan_contacts()` → `_process_merges()` (file `MergeSystem`, une fusion par fruit et par tick) → `_check_danger()` (`DangerMonitor`).

## 5. Services natifs et plugins

| Plugin | Version (source) | Plateformes | Usage |
|---|---|---|---|
| Godot AdMob (Poing Studios) | 5.1.0 (cache CI) | Android, iOS | `scripts/ads/admob_ads.gd`, accès **dynamique** (le projet compile sans) |
| Godotx Firebase | 3.1.0, SDK iOS 12.16.0 | Android (.aar), iOS (téléchargé par `tools/ios/build_ios.sh`) | Core + Analytics + Messaging ; Crashlytics **désactivé** (`export_presets.cfg` : `firebase/enable_crashlytics=false`) |
| NotificationSchedulerPlugin (+ GMPShared) | v6 | Android .aar, iOS xcframework | rappels locaux (`scripts/platform/mobile_notifications.gd`) |
| GUT | `addons/gut` | éditeur/CI | tests |
| `_fv_release` (maison) | — | export | injecte l'App ID AdMob réel au moment de l'export release, retire les permissions inutiles |

[FAIT] Aucun plugin de partage natif, d'IAP (Play Billing / StoreKit), de Game Center / Play Games, ni de Remote Config n'est présent.

## 6. Configuration plateformes

**Android** (`export_presets.cfg`, preset 2 « Android Release ») : package `com.smartiaservices.fruitvillage`, version 1.0.0 / code 6, minSdk 29, targetSdk 36, Gradle build, export AAB (`export_format=1`), `post_notifications=false` dans le preset (la permission arrive par le manifeste du plugin et est autorisée dans `tools/inspect_build.py:32`). Presets 0 et 1 (MockAds / AdMob test) gardent `0.4.0-m4`.

**iOS** (preset 3) : bundle `com.smartiaservices.fruitvillage`, `short_version=1.0.0`, `version=1` (le numéro de build réel est injecté par la CI : `BUILD_NUMBER=${{ github.run_number }}`), `entitlements/game_center=true`, push `Production`, `NSUserTrackingUsageDescription` présent, `UIBackgroundModes=remote-notification`.

## 7. Pipeline de build et publication

| Étape | Outil | Notes |
|---|---|---|
| Android debug/test | `tools/build_android.sh`, `tools/android_common.sh` | patch Gradle Firebase, splash |
| Android release | `tools/build_release.sh` → `tools/check_build.sh` + `tools/inspect_build.py` | contrôle permissions, alignement 16 Ko, App ID réel ; signature par `export_credentials.cfg` (non versionné) |
| Version | `tools/bump_version.sh` | |
| iOS | `.github/workflows/ios.yml` (runner `macos-26`) → `tools/ios/build_ios.sh` + `tools/ios/check_plist.py` | PR = contrôle non signé ; `workflow_dispatch` + `upload` = TestFlight. Soumission App Review manuelle |
| Secrets | `ads_ids.cfg`, `google-services.json`, `GoogleService-Info.plist`, `export_credentials.cfg` : présents localement, **ignorés par git** (`.gitignore`) | iOS : secrets GitHub |

[FAIT] Pas de CI Android ni d'exécution automatique de GUT sur PR Android ; la CI iOS exécute les tests en mode upload (« tests + export release », commentaire `ios.yml`).
