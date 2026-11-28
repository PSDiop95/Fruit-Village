# V2-0 — Rapport de clôture (actualisé le 28/11/2026)

Branche `feature/fruit-village-v2-0` : PR #31 (fondations) et PR #32 (Crashlytics, relecture, checklist)
fusionnées ; résultats des tests sur Galaxy A23 en commits locaux (non poussés). Aucune publication store,
aucun développement V2-1.

## Critères d'acceptation
| ID | Critère | Statut | Preuve |
|---|---|---|---|
| G0-01 | 193 tests V1 conservés et verts | **PASS** | 193/193 local et CI ; 1 test réécrit volontairement (TD-10), voir 07 |
| G0-02 | Nouveaux tests verts | **PASS** | 51/51 (20 localisation, 23 sauvegardes, 8 Crashlytics) ; 244/244 local, CI PR #32 : 243 + 1 en attente (secret local absent), 0 échec |
| G0-03 | Aucune régression d'assertions inexpliquée | **PASS** | tests V1 identiques ; seul écart : test de session à durée réelle, variable en V1 aussi |
| G0-04 | FR et EN complets | **PASS** | 202 clés, 0 vide, formats identiques ; relecture anglaise (09) : 5 corrections, 14 points à faire valider par un natif ; bascule FR / EN à chaud vérifiée sur A23 |
| G0-05 | Langue conservée après redémarrage | **PASS** | test GUT + A23 (FR conservé après relance, modification et suppression de la sauvegarde) ; une bascule fr → en inexpliquée observée une fois, non reproduite (10) |
| G0-06 | TAMPERED : aucune perte silencieuse | **PASS** | 23 tests + A23 : pièces forcées à 999999 → solde légitime rétabli, record / XP intacts, copie `.tampered` ; fichier supprimé → rechargé depuis `.bak` |
| G0-07 | Sections inconnues préservées | **PASS** | `test_unknown_sections_survive_writes`, `test_late_registration_…` |
| G0-08 | Crashlytics : transmission vérifiée ou blocage documenté | **BLOCKED (transmission)** | intégration OK (SDK initialisé sur A23, collecte activée avec consentement + réglage) ; le plantage de test du plugin godotx 3.1.0 est intercepté par Godot (aucun plantage, aucun rapport) ; pas de correctif amont (3.1.0 = dernière version) ; **décision du propriétaire**, voir plus bas |
| G0-09 | Tests GUT automatiques sur PR | **PASS** | `tests.yml` vert sur PR #31 et #32 ; régression Linux corrigée (51a9b72) |
| G0-10 | Démarrage ≤ 110 % de V1 | **PASS (PC) / NOT TESTED (A23)** | PC +1,7 % ; A23 en build debug seulement (TotalTime 3,9–4,7 s), non comparable au repère V1 release ; AAB release local à mesurer |
| G0-11 | Build < 60 Mo | **PASS** | APK MockAds 45,6 Mo (CI) ; Crashlytics ≈ +0,44 Mo compressé ; AAB release non reconstruit (secrets) |
| G0-12 | Jeu V1 opérationnel hors ligne | **PASS** | A23 en mode avion : démarrage, partie complète, missions, aucune pub proposée, aucun gel ; session de 20 min hors ligne |
| G0-13 | Build Android contrôlé | **PASS (debug)** | CI `android-debug` ; build Gradle AdMob test + Crashlytics : `check_build.sh` OK, installé et joué sur A23 ; release non fait (signature) |
| G0-14 | iOS : configuration et compatibilité | **PASS** | `ios.yml` vert sur PR #31 et #32 ; Crashlytics iOS non intégré (option C non autorisée) |
| G0-15 | Compatibilité sauvegardes V1 | **PASS** | fixtures + A23 : V1 installée puis mise à jour par V2-0, 0 champ perdu, réglages conservés, `.bak` créé |

## Stabilité (A23)
Session de 20 min hors ligne : même processus du début à la fin, **0 plantage, 0 ANR**, mémoire stable
(635–713 Mo), 49–60 FPS. Un 1er essai a été écarté (pub de test au premier plan, appuis automatiques sortis du jeu).

## Synthèse
- **PASS** : G0-01 à 07, 09, 11 à 15.
- **BLOCKED** : G0-08 (transmission Crashlytics), en attente de la décision du propriétaire.
- **NOT TESTED** : G0-10 sur appareil (mesure release), allers-retours arrière-plan / premier plan, cadeau du
  jour non réclamable deux fois sur appareil.

## Crashlytics — décision du propriétaire
Constat : `crash()` du plugin lève l'exception sur le thread de rendu de Godot, que le pont Java intercepte.
Plus largement, sans NDK, Crashlytics ne voit pas les plantages natifs du moteur Godot (seulement Java /
Kotlin et ANR). Options, toutes avec dépendance native à autoriser :
| Option | Effet | Coût |
|---|---|---|
| 1. Petit plugin de test Fruit Village | plantage réel sur le thread principal → vérifie l'envoi des rapports | quelques lignes Kotlin, godotx inchangé |
| 2. NDK (option B) | capte aussi les plantages du moteur | bibliothèque native en plus : taille et alignement 16 Ko à revérifier |
| 3. Reporter | intégration gardée, transmission non vérifiée | aucun |

## Avant V2-1
1. Décision Crashlytics (ci-dessus).
2. Mesure de démarrage sur A23 avec l'AAB release local, face à V1.
3. Validation anglaise des 14 points de `09_ENGLISH_REVIEW.md`.
4. Politique de confidentialité / Data safety (rapports de plantage) avant toute release.
5. Pousser les commits de résultats A23 (PR à ouvrir).

La V2-1 n'est pas commencée : elle attend la validation explicite du propriétaire.
