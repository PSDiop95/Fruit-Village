# M5 — Release : rapport

Objectif : AAB signé conforme Google Play, prêt pour le test fermé, fiche
store prête. **Rien n'a été téléversé.**

## Résultat de la vérification (24–25 octobre 2026)

Build complet `tools/build_release.sh` exécuté de bout en bout, signé avec une
**clé jetable** (scratchpad, jamais téléversable ; AAB supprimé ensuite) et un
`google-services.json` temporairement adapté au nouveau package puis restauré.
Rapport brut : `build/release/report_verification_cle_jetable.txt`.

| Point | Résultat |
|---|---|
| Tests GUT (M1–M5) | **173/173 verts** (157 existants + 16 M5 `test_release.gd`) |
| Package | `com.smartiaservices.fruitvillage` (à confirmer, voir plus bas) |
| Version | 1.0.0, version code 1 |
| targetSdk | **36** (exigé depuis le 31/08/2026 pour toute nouvelle app) |
| minSdk | **29** (Android 10) — voir « Décision » |
| ABI | arm64-v8a + armeabi-v7a, format AAB |
| 16 Ko | **Conforme** : toutes les `.so` 64 bits alignées 16 384 (libgodot_android, libc++_shared, libdatastore) ; `PAGE_ALIGNMENT_16K` dans la config du bundle (AGP 8.6.1, NDK r29, Godot 4.7.2) |
| Signature | jarsigner OK ; Play App Signing prévu (`docs/KEYSTORE.md`) |
| App ID AdMob du manifeste | réel en release (masqué dans les journaux), test Google en debug |
| Taille AAB | 78,6 Mo (les deux ABI) |
| **Téléchargement estimé** | **52,1 Mo** (arm64) / 53,6 Mo (armv7) — objectif < 60 Mo ✅ |
| Démarrage à froid (Galaxy A23, Android 14, mode avion) | 1er frame : **2,6 s** (moyenne de 4 lancements ; 4,2 s au tout premier lancement après installation) ; **écran titre jouable : ≈ 4,5 s** — objectif < 3 s **non atteint** |
| Plantage / ANR (même téléphone) | aucun : lancement, partie, accueil → retour, rotation forcée (reste en portrait), mode avion |

### Permissions du paquet final

| Permission | Origine | Pourquoi |
|---|---|---|
| `INTERNET` | preset | pubs, statistiques |
| `ACCESS_NETWORK_STATE` | preset | ne charger une pub que s'il y a du réseau |
| `com.google.android.gms.permission.AD_ID` | preset | identifiant publicitaire (AdMob) ; déclaré « Oui » dans la Play Console |
| `VIBRATE` | preset | vibrations de jeu (désactivables) |
| `WAKE_LOCK` | Firebase/WorkManager | envoi différé des événements ; le retirer peut planter WorkManager |
| `BIND_GET_INSTALL_REFERRER_SERVICE` | Firebase | source d'installation (utile pour les campagnes diaspora / Tier 1) ; retirable si tu préfères |
| `<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX | interne à l'app (signature), ni visible ni demandée |

Retirées (plugin `addons/_fv_release`, `tools:node="remove"`) :
`READ_BASIC_PHONE_STATE` (SDK pub), `FOREGROUND_SERVICE` (WorkManager, aucun
service au premier plan), `ACCESS_ADSERVICES_AD_ID` /
`ACCESS_ADSERVICES_ATTRIBUTION` (Privacy Sandbox, non utilisé),
`android.permission.AD_ID` (nom erroné ajouté par le plugin AdMob).
`tools/check_build.sh` fait échouer le build si une permission hors liste
apparaît (ex. après une mise à jour de SDK).

**`POST_NOTIFICATIONS` n'est pas déclarée** : aucun plugin de notifications
natif n'est installé (M4 : interface + mock seulement), les rappels
quotidiens ne partent donc pas en 1.0.0. Déclarer la permission sans s'en
servir serait inutile. Pour l'activer : installer le plugin Notification
Scheduler (16 Ko à vérifier), passer `permissions/post_notifications=true`,
l'ajouter à `ALLOWED_PERMISSIONS` dans `tools/inspect_build.py`.

### 10 plus gros fichiers de l'AAB et pistes

| Compressé | Fichier | Piste |
|---|---|---|
| 25,5 Mo | `lib/armeabi-v7a/libgodot_android.so` | servi seulement aux téléphones 32 bits (split par ABI) ; rien à gagner pour arm64 |
| 24,0 Mo | `lib/arm64-v8a/libgodot_android.so` | modèle d'export Godot sur mesure sans modules inutiles (XR, navigation, 2D physics…) : −30 à −40 % ; demande de compiler Godot |
| 3,9 + 2,7 + 2,0 Mo | `dex/classes*.dex` | activer R8 (`admob/general/android/enable_r8_optimization`) : −40 % environ, à tester (réflexion des plugins) |
| 2,8 Mo | `assets/ui/splash.png` (source brute) | le PNG source part en plus de sa version importée : passer le splash en JPG/WebP qualité 85 (≈ 0,4 Mo) |
| 2,8 Mo | `res/drawable-nodpi/fv_splash.png` | même image pour le lancement Android : JPG/WebP ≈ 0,4 Mo |
| 2,3 Mo | `.godot/imported/splash.png-….ctex` | même image une 3e fois : compression VRAM ou taille 720 de large |
| 1,8 Mo | `music.ogg` | **plugin AdMob** (`addons/admob/assets/music.ogg`, démo) : exclure `addons/admob/assets/*` du preset |
| 1,0 Mo | `tension.mp3` | débit 96 kb/s mono : −50 % |

Gain réaliste sans recompiler Godot : ≈ 9 Mo (splash ×3, musique de démo,
R8). Pas bloquant : on est déjà sous 60 Mo.

## Ce qui a été fait

- **Renommage** : « Fruit Village » partout (project.godot + nom traduit fr/en/wo,
  preset, CLAUDE.md, outils) ; plus aucune trace de l'ancien nom hors
  historique git. Logo `assets/branding/fruit-village-logo.png` (copie du
  fichier de ton site) à l'écran titre ; `assets/ui/logo.png` supprimé.
  Le jeu n'a **pas** de système de traduction : textes en français
  uniquement ; la fiche EN le dit honnêtement.
- **Identifiants pub** (`scripts/ads/ad_ids.gd`) : debug = test Google
  toujours ; release = uniquement les vrais de `ads_ids.cfg`, sinon format
  désactivé (jamais d'identifiant de test). En release sans SDK AdMob : aucune
  pub (avant : MockAds, qui donnait des récompenses gratuites).
  Le vrai App ID n'est plus dans `project.godot` ; le plugin
  `addons/_fv_release` le pose le temps de l'export release et retire
  `ads_ids.cfg` des exports debug.
  ⚠️ Trouvé en passant : les anciens APK debug M4 embarquaient
  `ads_ids.cfg` (vrais identifiants) et `google-services.json` ; corrigé.
- **Release** : menu debug non créé, FPS et sonde de perf déjà réservés au
  debug, `stdout` coupé (`run/disable_stdout.release`), fichiers de dev
  (`.mcp.json`, `.gutconfig.json`, `google-services.json`, `build/`) exclus du
  paquet et vérifiés par `check_build.sh`.
- **Scripts** : `tools/build_release.sh`, `tools/check_build.sh`
  (+ `inspect_build.py`), `tools/bump_version.sh`,
  `tools/make_upload_keystore.sh`, `tools/android_common.sh` (commun avec
  `build_android.sh`) ; `export_presets.cfg` désormais versionné (aucun
  secret, testé). bundletool 1.18.3 installé dans `C:\Users\hp\android-tools\bundletool`.
- **Store** : `store/` (textes FR/EN, icône 512, aperçus 48/96/128 px, image
  de présentation, 6 captures FR + 6 EN, `app-ads.txt`, script vidéo).
  Gabarit ré-exécutable : `tools/screenshots/make_screenshots.sh`
  (fenêtre sans bordure 1080x1920 sous Windows, `xvfb-run` sous Linux :
  `--headless` ne rend aucune image).
- **Docs** : `KEYSTORE.md`, `QA_CHECKLIST.md` (32 points), `PLAY_CONSOLE.md`,
  `LAUNCH_PLAN.md`.

## Points ouverts

1. **Décision minSdk** : Godot 4.7 impose 29 par défaut avec le renderer
   Mobile (Vulkan 1.1). Le cahier des charges dit Android 8+ (26). Passer à
   26 = repli OpenGL (Compatibility) sur les vieux téléphones, **jamais testé**
   (shaders toon, contours). Recommandation : garder 29 pour la 1.0.0 et
   mesurer la demande.
2. **Démarrage** ≈ 4,5 s jusqu'à l'écran titre : 2,6 s d'initialisation du
   moteur (chargement de la lib 71 Mo, Vulkan) + ≈ 2 s d'écran de chargement.
   Pistes : charger le décor 3D après l'affichage du titre, splash plus léger.
   À traiter en 1.0.1 si les testeurs le remontent ; Android vitals juge
   « lent » au-delà de 5 s.
3. Politique de confidentialité §2 : mentionne des rapports de plantage
   Firebase alors que Crashlytics n'est pas inclus (voir `PLAY_CONSOLE.md` §5).
4. Firebase : `google-services.json` ne connaît que `com.fruitvillage.game` ;
   le build release refuse de partir tant que la nouvelle app n'est pas ajoutée.
5. Ancien APK debug `com.fruitvillage.game` sur le Galaxy A23 : un plantage
   natif (thread Vulkan, `recursive_mutex::lock`) du 24/10 au soir est dans le
   journal ; non reproduit avec la release. À surveiller dans Android vitals.
6. Réglage « Rotation auto » du téléphone de test : vérifié à 1 (activée)
   après les tests ; si tu l'avais désactivée, remets-la.
