# V2-0 — Crashlytics (TD-20) : BLOCKED

## Audit
| Élément | État |
|---|---|
| `export_presets.cfg` : `firebase/enable_crashlytics` | `false` (Android Release, AdMob test) |
| Plugin godotx_firebase (`addons/godotx_firebase/export_plugin.gd`) | sait ajouter `com.google.firebase:firebase-crashlytics` et l'AAR `android/firebase_crashlytics/*.aar` si le drapeau est vrai |
| AAR `android/firebase_crashlytics/firebase_crashlytics.{debug,release}.aar` | **absent** (seuls core, analytics, messaging sont livrés) |
| Gabarit Gradle `android/build/build.gradle` | plugin `google-services` seulement ; **pas** de plugin Gradle `com.google.firebase.crashlytics` |
| iOS (`tools/ios/build_ios.sh`) | télécharge Core / Analytics / Messaging seulement ; pas de FirebaseCrashlytics ni d'envoi des dSYM |
| Code de jeu | aucun appel Crashlytics ; `firebase_crashlytics_helper.gd` (addon) inutilisé |
| Crashs natifs du moteur (C++) | nécessiteraient en plus `firebase-crashlytics-ndk` et les symboles |

## Pourquoi on n'active pas le drapeau
Passer `enable_crashlytics=true` avec les fichiers actuels : l'AAR godotx manque (singleton absent) et la
dépendance Maven seule, sans le plugin Gradle Crashlytics, n'injecte pas l'identifiant de build ;
le SDK refuse alors de démarrer (risque de plantage au lancement, à vérifier sur appareil).
Les deux corrections sont une **nouvelle dépendance native** et un **changement majeur de configuration
de build** : interdits sans autorisation (règle 8). Aucun code de test de plantage n'a donc été ajouté.

## Options (décision du propriétaire)
| Option | Contenu | Coût / risque |
|---|---|---|
| A (recommandée) | AAR `firebase_crashlytics` de la **même release godotx 3.1.0** + plugin Gradle Crashlytics dans le gabarit + drapeau vrai sur les presets Android ; collecte coupée par défaut (`privacy_safe_defaults`), activée avec le consentement UMP ; plantage de test réservé aux builds debug (menu debug) ; vérification de la console Firebase sur appareil | ~1 j ; build Android à revalider (taille, 16 Ko, permissions) |
| B | A + NDK (crashs du moteur) | +0,5 j ; symboles natifs (~70 Mo) à envoyer à chaque release |
| C | iOS : FirebaseCrashlytics depuis le Firebase.zip signé 12.16.0 + script d'envoi des dSYM dans `build_ios.sh` | ~1 j ; contrôle Apple (manifestes de confidentialité) |
| D | Reporter Crashlytics ; s'appuyer sur Android vitals / Xcode Organizer | 0 ; crashs moins détaillés |

## Confidentialité (pour A–C)
Aucune donnée personnelle ni jeton dans les clés personnalisées ; collecte seulement après consentement ;
mention dans la politique de confidentialité et la fiche Data safety / App Privacy.

## Statut
**BLOCKED** : en attente de l'autorisation d'ajouter la dépendance native et de modifier le gabarit Gradle.
Le contrôle CI `tools/ci/check_config.py` affiche l'état du drapeau à chaque exécution.
