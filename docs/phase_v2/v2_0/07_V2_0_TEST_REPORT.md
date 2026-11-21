# V2-0 — Rapport de tests (21/11/2026)

Environnement : Windows 11, Godot 4.7.2 headless, GUT. Référence V1 = worktree propre de `origin/main`
(commit 20f4afa) avec le même `ads_ids.cfg` local, exécuté sur la même machine.

## Synthèse
| | V1 (référence) | V2-0 |
|---|---|---|
| Tests | 193 | **236** (193 V1 + 43 nouveaux) |
| Réussis | 193 | **236** |
| Échoués / en attente | 0 / 0 | 0 / 0 |
| Assertions | 4004 | 5571 |
| Erreurs GDScript (journaux) | — | 0 (`tools/ci/gut_summary.py`) |

## Tests V1 (G0-01, G0-03)
- 192 tests V1 : mêmes noms, mêmes résultats, **même nombre d'assertions**, sauf
  `test_game_physics::test_random_play_session_stable` : 115 / 123 / 79 selon les runs (V1 comme V2-0).
  Ce test attend en temps réel (`wait_seconds`) et vérifie 4 assertions **par fruit restant** : le nombre de
  fruits dépend du rythme des images. Variation connue, non liée à V2-0 (aucun fichier de physique modifié).
- 1 test V1 **modifié volontairement** (TD-10) : `test_tampered_save_resets_progress_keeps_settings` figeait le
  défaut corrigé (progression remise à zéro). Remplacé par `test_tampered_save_recovers_progress_keeps_settings`
  (même scénario : réglages conservés, solde frauduleux ignoré, progression légitime rechargée, copie gardée).
- Nettoyage des fichiers de test : `SaveManager.erase_files` (efface aussi `.bak` et quarantaines) dans
  6 fichiers de tests — sans effet sur les assertions.

## Nouveaux tests (G0-02)
### `tests/unit/test_locale.gd` — 20 tests, 1414 assertions
Détection de la langue système, langue inconnue → FR, FR par défaut (y compris `project.godot`), choix manuel
prioritaire, choix non pris en charge → auto, persistance + rechargement (relance simulée), signal `changed`,
pluriels FR/EN, CSV sans traduction manquante, formats identiques FR/EN, chaque clé chargée dans le
TranslationServer (FR et EN), **toute clé littérale du code présente dans le CSV**, clés de données (fruits,
lore, power-ups, ambiances, missions, fonctionnalités, qualité, langues), FR = textes des `.tres`, noms EN =
`name_en` du lore, notifications en anglais, re-traduction à chaud d'un nœud lié (texte + pluriel), titre et
réglages basculés en anglais via le sélecteur, **aucun texte français visible** en anglais (titre, réglages,
missions, cadeau, album, HUD, pause, fin de partie), carte Réglages ≤ 1899 px (hauteur V1) en FR et EN.

### `tests/unit/test_save_recovery.gd` — 23 tests, 187 assertions
Fixtures `tests/fixtures/saves/` : v1 valide (migration + copie `.v1`), v2 valide (tout rechargé), incomplète,
sections manquantes (recréées), grosse progression (aller-retour exact), sections / réglages / champs inconnus
conservés après plusieurs écritures, tous les systèmes écrits, enregistrement tardif (section remise après une
écriture), système optionnel absent, corrompue sans secours (copie identique, original non écrasé), corrompue
avec secours, fichier principal manquant avec secours, modifiée avec secours (quarantaine, secours jamais
remplacé), modifiée sans secours (progression gardée, solde borné, relu OK ensuite), **aucune récompense en
double** (cadeau du jour), version future (en-tête FV3 et `version: 3`), écritures suspendues si la copie
est impossible (fichier jamais écrasé, même après relance), signal + statistique sans données, chargement
normal silencieux, règles pures `SaveCodec.header_version`, `SaveRecovery.fence`, `SaveRecovery.salvage`.

## Contrôles hors GUT
| Contrôle | Résultat |
|---|---|
| `tools/ci/check_config.py` | OK (12 contrôles) |
| `tools/ci/gut_summary.py` sur le run complet | OK |
| Export APK debug « Android MockAds » (V1 et V2-0) + `tools/check_build.sh … debug` | OK (après correction du contrôle App ID absent) |
| Captures FR / EN (`tools/capture_m4.gd`) : 13 écrans | aucun texte coupé, carte Réglages entière |
| Démarrage PC (`tools/startup_probe.gd`, 6 lancements alternés) | V1 3030 ms, V2-0 3083 ms (médianes) |

## Non exécuté
| Test | Raison |
|---|---|
| Workflows GitHub (`tests.yml`, `ios.yml`) | nécessite un push / une PR (à autoriser) |
| Démarrage, ANR, hors-ligne sur Galaxy A23 | pas d'appareil connecté |
| AAB release Android, build iOS | secrets et signature (hors périmètre), macOS |
| Crashlytics | BLOCKED (voir 05) |
