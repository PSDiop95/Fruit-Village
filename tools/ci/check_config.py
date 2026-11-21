"""Contrôles de configuration Fruit Village (CI V2-0, sans secret).

Usage : python tools/ci/check_config.py   (depuis la racine du projet)

Vérifie :
- identifiants d'application inchangés (Android, iOS) ;
- aucun secret suivi par git (ads_ids.cfg, google-services.json,
  GoogleService-Info.plist, export_credentials.cfg, keystores, clés .p8) ;
- moteur : Godot 4.7, renderer Mobile ;
- traductions : CSV keys,fr,en complet (aucune case vide, clés uniques,
  mêmes formats %s/%d en FR et EN), déclarées dans project.godot, FR par défaut ;
- Crashlytics : état du drapeau d'export (signalé, pas imposé).
Affiche un tableau Markdown (résumé de job). Code de sortie 1 si une règle
est violée. Bibliothèque standard seulement.
"""
import csv
import os
import re
import subprocess
import sys

APP_ID = "com.smartiaservices.fruitvillage"
SECRET_PATTERNS = [
    r"(^|/)ads_ids\.cfg$",
    r"(^|/)google-services\.json$",
    r"(^|/)GoogleService-Info\.plist$",
    r"(^|/)export_credentials\.cfg$",
    r"\.(keystore|jks|p8|p12|mobileprovision)$",
]
CSV_PATH = "localization/translations.csv"

results = []  # (règle, ok, détail)


def check(rule, ok, detail=""):
    results.append((rule, bool(ok), detail))


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def main():
    presets = read("export_presets.cfg")
    project = read("project.godot")

    ids = re.findall(r'^package/unique_name="([^"]*)"', presets, re.M)
    check("ID Android inchangé", ids and all(i == APP_ID for i in ids), ", ".join(sorted(set(ids))))
    bundle = re.findall(r'^application/bundle_identifier="([^"]*)"', presets, re.M)
    check("Bundle ID iOS inchangé", bundle and all(b == APP_ID for b in bundle), ", ".join(bundle))

    try:
        tracked = subprocess.run(["git", "ls-files"], capture_output=True, text=True,
                                 check=True).stdout.splitlines()
        leaks = [p for p in tracked if any(re.search(s, p) for s in SECRET_PATTERNS)]
        check("Aucun secret suivi par git", not leaks, ", ".join(leaks) or "aucun")
    except (OSError, subprocess.CalledProcessError) as e:
        check("Aucun secret suivi par git", False, "git indisponible : %s" % e)

    check("Godot 4.7 / Mobile", '"4.7"' in project and 'rendering_method="mobile"' in project)

    check("Traductions déclarées", "translations.en.translation" in project
          and "translations.fr.translation" in project)
    check("Langue de repli : français", re.search(r'^locale/fallback="fr"', project, re.M))
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    header, body = rows[0], rows[1:]
    check("CSV : colonnes keys,fr,en", header == ["keys", "fr", "en"], ",".join(header))
    keys = [r[0] for r in body if r]
    dup = sorted({k for k in keys if keys.count(k) > 1})
    check("CSV : clés uniques", not dup, ", ".join(dup))
    empty = [r[0] for r in body if r and (len(r) != 3 or not r[1].strip() or not r[2].strip())]
    check("CSV : aucune traduction manquante", not empty, ", ".join(empty[:10]))
    fmt = re.compile(r"%[-0-9.]*[sdif%]")
    bad = [r[0] for r in body if len(r) == 3 and fmt.findall(r[1]) != fmt.findall(r[2])]
    check("CSV : formats FR = EN", not bad, ", ".join(bad[:10]))
    check("CSV : %d clés" % len(keys), len(keys) > 0)

    # Crashlytics (V2-0, option A) : si un preset l'active, le plugin Gradle
    # et les AAR doivent suivre, et la collecte rester coupée par défaut.
    crash = re.findall(r"^firebase/enable_crashlytics=(\w+)", presets, re.M)
    if "true" in crash:
        gradle = read("android/build/build.gradle")
        check("Crashlytics : plugin Gradle", "firebase-crashlytics-gradle" in gradle
              and "apply plugin: 'com.google.firebase.crashlytics'" in gradle)
        aars = ["android/firebase_crashlytics/firebase_crashlytics.%s.aar" % v for v in ("debug", "release")]
        check("Crashlytics : AAR godotx", all(os.path.exists(a) for a in aars))
        check("Crashlytics : collecte coupée par défaut",
              "firebase/privacy_safe_defaults=false" not in presets)
    results.append(("Crashlytics (info)", True, "enable_crashlytics=%s" % ",".join(crash)))

    lines = ["| Contrôle | Résultat | Détail |", "|---|---|---|"]
    for rule, ok, detail in results:
        lines.append("| %s | %s | %s |" % (rule, "OK" if ok else "ÉCHEC", detail))
    out = "\n".join(lines)
    print(out)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("### Configuration\n\n" + out + "\n\n")
    return 0 if all(ok for _, ok, _ in results) else 1


if __name__ == "__main__":
    sys.exit(main())
