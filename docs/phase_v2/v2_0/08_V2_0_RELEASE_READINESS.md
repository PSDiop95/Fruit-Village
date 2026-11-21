# V2-0 — Rapport de clôture (actualisé le 21/11/2026)

Branche `feature/fruit-village-v2-0` : PR #31 (fondations, fusionnée), PR #32 (Crashlytics, relecture, checklist). Aucune publication store, aucun développement V2-1.

## Critères d'acceptation
| ID | Critère | Statut | Preuve |
|---|---|---|---|
| G0-01 | 193 tests V1 conservés et verts | **PASS** | 193/193 local et CI ; 1 test réécrit volontairement (TD-10), voir 07 |
| G0-02 | Nouveaux tests verts | **PASS** | 51/51 (20 localisation, 23 sauvegardes, 8 Crashlytics) ; total 244/244 local (CI : 236 avant Crashlytics, relancée au push) |
| G0-03 | Aucune régression d'assertions inexpliquée | **PASS** | tests V1 identiques ; seul écart : test de session à durée réelle, variable en V1 aussi |
| G0-04 | FR et EN complets | **PASS** | 202 clés, 0 vide, formats identiques ; relecture anglaise complète (09) : 5 corrections, 14 points « à valider » par un natif |
| G0-05 | Langue conservée après redémarrage | **PASS** | `test_choice_persists_and_reloads` ; appareil : NOT TESTED (checklist 10 §4) |
| G0-06 | TAMPERED : aucune perte silencieuse | **PASS** | 23 tests ; appareil : NOT TESTED (checklist 10 §3) |
| G0-07 | Sections inconnues préservées | **PASS** | `test_unknown_sections_survive_writes`, `test_late_registration_…` |
| G0-08 | Crashlytics : transmission vérifiée ou blocage documenté | **PASS (intégration) / NOT TESTED (transmission)** | option A intégrée, build Gradle AdMob test réussi (plugin enregistré, build ID présent, collecte `false` dans le manifeste) ; transmission réelle à vérifier sur A23 avec la console Firebase (10 §6) |
| G0-09 | Tests GUT automatiques sur PR | **PASS** | `tests.yml` exécuté sur PR #31 : 236 tests, 0 échec ; régression Linux corrigée (51a9b72) |
| G0-10 | Démarrage ≤ 110 % de V1 | **PASS (PC) / NOT TESTED (A23)** | PC +1,7 % ; Crashlytics : initialisation asynchrone après Core, rien de bloquant ajouté ; A23 : checklist 10 §1 |
| G0-11 | Build < 60 Mo | **PASS** | APK MockAds 45,6 Mo (CI) ; APK AdMob test avec Crashlytics : +1,23 Mo sur l'APK debug (dex non compressé), ≈ +0,44 Mo compressé (estimation téléchargement) ; AAB release non reconstruit (secrets) |
| G0-12 | Jeu V1 opérationnel hors ligne | **NOT TESTED** | aucun appel réseau bloquant ajouté (Crashlytics envoie en différé, sans attente) ; mode avion : checklist 10 §2 |
| G0-13 | Build Android contrôlé | **PASS (debug)** | CI `android-debug` vert ; build Gradle AdMob test + Crashlytics : `check_build.sh debug` OK (permissions inchangées, alignement 16 Ko) ; release : secrets et signature requis, non fait |
| G0-14 | iOS : configuration et compatibilité | **PASS** | `ios.yml` vert sur PR #31 (Info.plist, PrivacyInfo, SDK signés, compilation non signée) ; Crashlytics iOS non intégré (option C non autorisée) |
| G0-15 | Compatibilité sauvegardes V1 | **PASS** | fixture V1 migrée ; appareil (mise à jour V1 → V2-0) : NOT TESTED (checklist 10 §3) |

## Synthèse
- **PASS** : G0-01 à 07, 09, 11, 13 (debug), 14, 15 ; G0-08 et G0-10 pour la partie vérifiable hors appareil.
- **NOT TESTED** : tout ce qui demande le Galaxy A23 (démarrage, mode avion, ANR, sauvegardes réelles,
  transmission Crashlytics). La checklist `10_GALAXY_A23_CHECKLIST.md` est prête.
- **BLOCKED** : aucun.

## Crashlytics (option A) — conditions du propriétaire
| Condition | Résultat |
|---|---|
| Compatibilité des dépendances natives | AAR godotx 3.1.0 = même release que Core / Analytics / Messaging (vérifiée par SHA-256) |
| Versions Firebase | `firebase-crashlytics` 20.1.0 sur `firebase-common` 22.1.0 (≥ 22.0.1 requis) ; plugin Gradle 3.0.8 sur AGP 8.6.1 |
| Configurations Android / iOS | 2 presets Android Firebase activés ; MockAds et iOS inchangés ; `check_config.py` et 8 tests GUT |
| Taille | +1,23 Mo sur l'APK debug (dex non compressé), ≈ +0,44 Mo compressé (estimation téléchargement) |
| Démarrage | initialisation après Core, asynchrone ; aucune mesure appareil (A23) |
| Sécurité | `privacy_safe_defaults` conservé ; collecte seulement avec consentement + réglage ; pas d'identifiant ; plantage de test réservé au debug |

## Avant V2-1 (décision du propriétaire)
1. Dérouler la checklist Galaxy A23 (10) et reporter les résultats.
2. Faire valider par un anglophone les 14 points de `09_ENGLISH_REVIEW.md`.
3. Mettre à jour la politique de confidentialité / Data safety (rapports de plantage) avant toute release.
4. Relire et fusionner la PR #32 (CI à vérifier).

La V2-1 n'est pas commencée : elle attend la validation explicite du propriétaire.
