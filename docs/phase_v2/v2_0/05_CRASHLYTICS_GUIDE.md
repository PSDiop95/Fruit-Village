# V2-0 — Crashlytics (TD-20) : option A (Android)

Option A autorisée par le propriétaire le 21/11/2026 (Android, sans NDK). iOS (option C) et NDK
(option B) **non** autorisés : non faits.

## Ce qui a été intégré
| Élément | Détail | Vérification |
|---|---|---|
| AAR `android/firebase_crashlytics/firebase_crashlytics.{debug,release}.aar` | release **godotx 3.1.0**, la même que Core / Analytics / Messaging déjà livrés | zip épinglé (SHA-256 `da7273de…` de `build_ios.sh`) ; AAR Core / Analytics / Messaging et addon du dépôt **identiques octet pour octet** à cette release |
| Dépendance Maven | `com.google.firebase:firebase-crashlytics:20.1.0` (défaut du plugin godotx 3.1.0) ; demande `firebase-common` ≥ 22.0.1 → résolu avec le 22.1.0 déjà utilisé | POM Google Maven |
| Plugin Gradle | `com.google.firebase:firebase-crashlytics-gradle:3.0.8` + `apply plugin: 'com.google.firebase.crashlytics'` dans `android/build/build.gradle` (et `tools/android_common.sh` si le gabarit est réinstallé) | AGP 8.6.1 / Gradle 8.11.1 ≥ minimum du plugin 3.x (AGP 8.1, Gradle 8.0) |
| Presets | `firebase/enable_crashlytics=true` sur « Android AdMob test » et « Android Release » ; MockAds et iOS inchangés | `test_crashlytics.gd`, `check_config.py` |
| Pas de NDK, pas de minification | rien à envoyer au build (mapping / symboles) | `build.gradle` |

## Confidentialité (aucun mécanisme de sécurité désactivé)
- `firebase/privacy_safe_defaults` (défaut vrai) : manifeste `firebase_crashlytics_collection_enabled=false` → **aucune collecte avant consentement**.
- `CrashReporter` (`scripts/analytics/crash_reporter.gd`) active la collecte seulement si
  `Analytics.is_allowed()` : consentement UMP **et** réglage « Statistiques d'usage ». Le couper la désactive aussitôt.
- Jamais d'identifiant utilisateur (`set_user_id` jamais appelé, vérifié par test) ; fil d'Ariane = noms d'événements
  analytics seuls (sans paramètres), messages tronqués à 200 caractères.
- Limite : un plantage survenu avant le consentement est gardé sur l'appareil par le SDK et peut partir une fois le
  consentement donné (comportement Firebase par défaut). Le plugin godotx n'expose pas `deleteUnsentReports`.

## Plantage de test
Menu debug (F1 / appui long à 3 doigts) → « Test plantage (Crashlytics) ». Double garde : le menu n'existe qu'en
build debug (`OS.is_debug_build`) et `CrashReporter.test_crash()` refuse hors debug. Jamais en production.

## Initialisation
Core initialisé une seule fois (`FirebaseBoot`), puis `initialize` Crashlytics ; sans plugin (PC, tests, iOS,
MockAds) tout est sans effet. Aucune initialisation bloquante ajoutée au démarrage.

## Tests
`tests/unit/test_crashlytics.gd` (8 tests) : sans plugin, ordre d'initialisation, échec de Core, consentement
et réglage, fil d'Ariane sans données, plantage de test, absence de `set_user_id`, configuration d'export.

## Build et mesures (21/11/2026, `tools/build_android.sh admob`, APK debug arm64)
| Contrôle | Résultat |
|---|---|
| Build Gradle | **OK** (AGP 8.6.1, Gradle 8.11.1) |
| Manifeste | `firebase_crashlytics_collection_enabled=false` ; plugin `GodotxFirebaseCrashlytics` enregistré ; registrars Crashlytics présents |
| SDK | 826 références de classes `com/google/firebase/crashlytics` dans le dex ; ressource `crashlytics.mapping_file_id` (build ID) générée |
| Permissions | **aucune nouvelle** : liste blanche `check_build.sh` OK |
| Alignement 16 Ko | OK (aucune bibliothèque native ajoutée) |
| Taille (même build, drapeau coupé puis activé) | 125,39 → 126,62 Mo (+1,23 Mo, dex stocké non compressé en debug) ; compressé ≈ 58,03 → 58,47 Mo (**+0,44 Mo**) |
| Démarrage | initialisation asynchrone après Core (`FirebaseBoot`), aucune attente ajoutée ; mesure appareil : **NOT TESTED** (checklist A23 §1) |
| Tests | 244/244 (dont 8 Crashlytics), 0 erreur GDScript |

Le job CI `android-debug` (preset MockAds, sans Gradle) ne couvre pas ce build : il reste local.

## Reste à faire
- Vérifier la **transmission** sur appareil (checklist A23, section 6) : nécessite le Galaxy A23 et la console Firebase.
- iOS (option C) et NDK (option B) : sur autorisation.
- Politique de confidentialité / Data safety : mentionner les rapports de plantage.
