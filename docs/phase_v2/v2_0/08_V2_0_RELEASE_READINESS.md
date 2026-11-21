# V2-0 — Prêt pour validation

## Critères d'acceptation
| ID | Critère | Statut | Preuve |
|---|---|---|---|
| G0-01 | 193 tests V1 conservés et verts | **PASS** | 193/193 ; 1 test réécrit volontairement (TD-10), voir 07 |
| G0-02 | Nouveaux tests verts | **PASS** | 43/43 (20 localisation, 23 sauvegardes) ; total 236/236 |
| G0-03 | Aucune régression d'assertions inexpliquée | **PASS** | 192 tests V1 identiques ; seul écart : test de session à durée réelle, variable en V1 aussi |
| G0-04 | FR et EN complets | **PASS** | 202 clés, 0 vide, formats identiques ; 0 texte FR visible en EN (8 écrans testés) ; captures |
| G0-05 | Langue conservée après redémarrage | **PASS** | `test_choice_persists_and_reloads` |
| G0-06 | TAMPERED : aucune perte silencieuse | **PASS** | quarantaine, secours, récupération nettoyée, écritures suspendues, signal (23 tests) |
| G0-07 | Sections inconnues préservées | **PASS** | `test_unknown_sections_survive_writes`, `test_late_registration_…` |
| G0-08 | Crashlytics : transmission vérifiée ou blocage documenté | **BLOCKED** | blocage documenté (05) : dépendance native + Gradle à autoriser |
| G0-09 | Tests GUT automatiques sur PR | **NOT TESTED** | workflow écrit et étapes rejouées localement ; jamais exécuté sur GitHub (push non autorisé) |
| G0-10 | Démarrage ≤ 110 % de V1 | **PASS** (PC) | +1,7 % sur PC ; appareil Android **NOT TESTED** |
| G0-11 | Build < 60 Mo | **PASS** | APK debug arm64 45,6 Mo mesuré (+0,06 Mo vs V1) ; AAB release non reconstruit (estimé 52,2 Mo téléchargé) |
| G0-12 | Jeu V1 opérationnel hors ligne | **NOT TESTED** | aucun appel réseau ajouté (revue du diff), suite complète sans réseau requis ; pas d'essai en mode avion sur appareil |
| G0-13 | Build Android contrôlé | **PASS** (debug) | export MockAds + `check_build.sh debug` OK ; release : secrets requis |
| G0-14 | iOS : configuration et compatibilité | **NOT TESTED** | tests de preset iOS (GUT) verts ; build Xcode = `ios.yml` sur macOS, à lancer via une PR |
| G0-15 | Compatibilité sauvegardes V1 | **PASS** | fixture V1 migrée (copie `.v1`), fixture V2, aller-retour grosse progression |

## Conditions avant V2-1
1. Autoriser le commit et le push de la branche, ouvrir une PR → exécuter `tests.yml` et `ios.yml`
   (G0-09, G0-14). Corriger si le premier run Linux révèle un écart d'environnement.
2. Sur Galaxy A23 : démarrage à froid (≤ 4,95 s jusqu'au titre), mode avion, pas d'ANR (G0-10, G0-12).
3. Décision Crashlytics (option A recommandée) ou report assumé (G0-08).
4. Relecture des textes anglais par le propriétaire (traduction faite sans relecteur natif).

## Rien de publié
Aucun envoi Google Play / App Store, aucun identifiant, certificat, preset d'export ou paramètre de physique
modifié.
