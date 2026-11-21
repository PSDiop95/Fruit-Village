# V2-0 — Rapport d'implémentation

Branche `feature/fruit-village-v2-0` (depuis `main` 20f4afa), PR #31 (fusionnée) et #32. Aucune publication store.

## V2-0.1 Localisation FR / EN
- Système natif Godot (CSV → `.translation`), 202 clés, FR par défaut et en repli.
- `LocaleCore` (pur) + autoload `Locale` + helper `Loc` ; réglage `language` (vide = langue du téléphone).
- Tous les textes de l'interface V1 passent par des clés (titre, réglages, HUD, pause, fin de partie,
  missions, cadeau, album, carte de fruit, power-ups, niveau supérieur, bannières juice, notifications).
- Changement de langue à chaud, sans redémarrage. Sélecteur `FR | EN` dans l'en-tête des Réglages
  (la carte faisait déjà 1899 px sur 1920 en V1).
- Exportations `reminder_title/text`, `streak_text` retirées de `DailyRewardsConfig` (aucun `.tres` ne les
  utilisait ; textes désormais `NOTIF_*`).
- Guide : 02_LOCALIZATION_GUIDE.md.

## V2-0.2 TAMPERED (TD-10)
- Quarantaine vérifiée de tout fichier suspect (`.tampered`, `.corrupt`, `.future`, `.v1`, `.bak-invalid`).
- Copie de secours `.bak` après chaque écriture réussie.
- Récupération : secours + clôture anti-doublon, sinon données nettoyées (solde borné par l'historique).
- Statut `FUTURE` dans `SaveCodec` (fichier d'une version plus récente : jamais traité comme illisible).
- Écritures suspendues si la copie ne peut pas être sécurisée. Signal `integrity_issue`, statistique
  `save_recovery` sans données. Format v2 inchangé.
- Guide : 03_SAVE_RECOVERY_GUIDE.md.

## V2-0.3 `register_system` (TD-14)
- `save_data` part de toutes les sections connues : sections, réglages, champs inconnus conservés.
- `unregister_system`, enregistrement tardif, règles et ordre d'initialisation documentés.
- Guide : 04_SAVE_SYSTEM_RULES.md.

## V2-0.4 Crashlytics (TD-20) — option A (Android), autorisée le 21/11/2026
- AAR `android/firebase_crashlytics/` (godotx 3.1.0, même release que Core / Analytics / Messaging),
  `firebase-crashlytics` 20.1.0, plugin Gradle `firebase-crashlytics-gradle` 3.0.8, sans NDK.
- `firebase/enable_crashlytics=true` sur les presets « Android AdMob test » et « Android Release » ;
  MockAds et iOS inchangés (option C iOS non autorisée).
- `scripts/analytics/crash_reporter.gd` : initialisation après Core, collecte seulement avec consentement UMP
  **et** réglage « Statistiques d'usage » ; fil d'Ariane = noms d'événements ; jamais d'identifiant utilisateur.
  `privacy_safe_defaults` conservé (collecte coupée dans le manifeste jusqu'au consentement).
- Plantage de test dans le menu debug, refusé hors build debug. 8 tests (`test_crashlytics.gd`).
- Guide : 05_CRASHLYTICS_GUIDE.md.

## V2-0.5 CI
- `.github/workflows/tests.yml` : contrôles de configuration, import, GUT (JUnit + résumé + erreurs GDScript),
  export APK debug MockAds + `inspect_build.py`. Aucun secret.
- `tools/ci/check_config.py`, `tools/ci/gut_summary.py`.
- `tools/inspect_build.py` : en debug, un App ID AdMob **absent** n'est plus compté comme réel.
- Exécuté sur GitHub (PR #31) : `tests`, `android-debug`, `ios` verts. Guide : 06_CI_GUIDE.md.

## V2-0.6 Performance
- Démarrage PC jusqu'au titre : +1,7 % (médianes 3030 → 3083 ms ; bruit de mesure ±15 %).
- APK debug arm64 : 45,57 → 45,63 Mo (+0,06 Mo).
- Seule initialisation ajoutée au démarrage : `Locale` (choix de langue, essentiel à l'affichage).
  Coût d'écriture : une copie `.bak` en plus par sauvegarde (fichier de quelques Ko).
- `tools/startup_probe.gd` : sonde de démarrage réutilisable.

## Fichiers
**Créés** : `autoload/Locale.gd`, `scripts/locale/{locale_core,loc}.gd`, `localization/translations.csv`,
`scripts/meta/save_recovery.gd`, `tests/unit/{test_locale,test_save_recovery}.gd`, `tests/hooks/pre_run.gd`,
`tests/fixtures/saves/*` (9 fixtures + générateur), `.github/workflows/tests.yml`,
`tools/ci/{check_config,gut_summary}.py`, `tools/startup_probe.gd`, `scripts/analytics/crash_reporter.gd`,
`tests/unit/test_crashlytics.gd`, `android/firebase_crashlytics/*.aar`, `docs/phase_v2/v2_0/*` (10).

**Modifiés** : `project.godot` (autoload Locale, traductions), `.gutconfig.json` (hook FR),
`autoload/{SaveManager,Missions,Notifications}.gd`, `scripts/meta/save_codec.gd`,
`scripts/data/daily_rewards_config.gd`, `scripts/platform/notification_planner.gd`,
`scripts/{game_hud,juice/juice,visual/visual_quality}.gd`, `scripts/ui/{settings_panel,title_screen,
game_over_screen,fruit_catalog_names}.gd`, `scripts/ui/meta/*` (8 fichiers), 6 fichiers de tests,
`tools/{capture_m4.gd,inspect_build.py,android_common.sh}`, `autoload/Analytics.gd`, `scripts/juice/debug_menu.gd`,
`android/build/build.gradle` (plugin Crashlytics), `export_presets.cfg` (`firebase/enable_crashlytics` seul), `CLAUDE.md`.

**Non touchés** : physique, fusion, spawner, données d'équilibrage, économie, identifiants, signatures,
autres options des presets, plugins natifs existants. `assets/ui/letterbox_*.png` (non suivis, antérieurs) préservés.
