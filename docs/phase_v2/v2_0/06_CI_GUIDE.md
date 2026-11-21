# V2-0 — Intégration continue

## Workflows
| Fichier | Déclencheur | Runner | Contenu |
|---|---|---|---|
| `.github/workflows/tests.yml` (nouveau) | PR, push sur `main`, manuel | ubuntu-24.04 | voir ci-dessous |
| `.github/workflows/ios.yml` (inchangé) | PR (contrôle), manuel (TestFlight) | macos-26 | export iOS debug, compilation non signée, `check_plist.py`, tests GUT en mode upload |

### Job `tests`
1. `tools/ci/check_config.py` : IDs d'application inchangés, aucun secret suivi par git, Godot 4.7 / Mobile,
   CSV de traductions complet et cohérent, FR en repli, état Crashlytics (info).
2. Godot 4.7.2 Linux téléchargé depuis `godot-builds`, **somme SHA-512 vérifiée** (`SHA512-SUMS.txt`), en cache.
3. Import (deux passages : le premier génère les `.translation`).
4. GUT headless, JUnit `build/ci/junit.xml`.
5. `tools/ci/gut_summary.py` : tableau dans le résumé du job, échec si un test échoue, si aucun test n'a
   tourné ou si « SCRIPT ERROR / Parse Error / Compile Error » apparaît dans les journaux.
6. Journaux en artefact `tests-logs`.

### Job `android-debug` (après `tests`)
Export **APK debug « Android MockAds »** (pubs simulées, sans Gradle, sans Firebase ni AdMob réels) avec une
clé debug jetable générée sur le runner, puis : manifeste (`aapt2`), `zipalign -P 16`,
`tools/inspect_build.py … debug` (règles du projet), taille < 60 Mo. Résumé + artefact.

## Ce qui n'est PAS fait en CI (et pourquoi)
| Contrôle | Raison |
|---|---|
| AAB release Android, AdMob test | exigent `google-services.json` / `ads_ids.cfg` / clé d'upload (secrets) — interdit ici |
| `tools/check_build.sh` tel quel | script Windows (cygpath, PowerShell) ; la CI appelle directement `inspect_build.py`, qu'il utilise |
| Tests sur appareil (ANR, démarrage) | pas d'appareil sur les runners |
| Publication | jamais (aucun secret, aucun envoi) |

## Secrets
Aucun dans `tests.yml`. `permissions: contents: read`.

## Exécution locale équivalente
```bash
python tools/ci/check_config.py
"$GODOT" --headless --path . --import; "$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit -gjunit_xml_file=build/ci/junit.xml > build/ci/tests.log 2>&1
python tools/ci/gut_summary.py build/ci/junit.xml build/ci/tests.log
```

## Statut
Workflow écrit, étapes exécutées localement (Windows) ; **jamais exécuté sur GitHub** : il faut pousser la
branche / ouvrir une PR (action à autoriser par le propriétaire). Les versions d'actions (`checkout@v7`,
`cache@v6`, `upload-artifact@v7`) sont celles de `ios.yml` ; `setup-java@v5` est nouveau.
