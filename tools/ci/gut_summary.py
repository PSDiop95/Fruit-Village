"""Résumé des tests GUT pour la CI (V2-0).

Usage : python tools/ci/gut_summary.py <junit.xml> <log> [<log> ...]

- compte tests réussis / échoués / en attente (JUnit GUT) ;
- cherche les erreurs GDScript dans les journaux (import et tests) :
  « SCRIPT ERROR », « Parse Error », « Compile Error » ;
- écrit un tableau Markdown dans le résumé du job (GITHUB_STEP_SUMMARY).
Code de sortie 1 si un test échoue, si aucun test n'a tourné ou si une
erreur GDScript est trouvée. Bibliothèque standard seulement.
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

GD_ERRORS = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    junit, logs = argv[0], argv[1:]
    total = failed = pending = asserts = 0
    failures = []
    if os.path.exists(junit):
        for tc in ET.parse(junit).iter("testcase"):
            total += 1
            asserts += int(tc.get("assertions") or 0)
            status = tc.get("status", "")
            if tc.find("failure") is not None or status == "fail":
                failed += 1
                failures.append("%s::%s" % (tc.get("classname"), tc.get("name")))
            elif status == "pending" or tc.find("skipped") is not None:
                pending += 1
    gd_errors = []
    for log in logs:
        if not os.path.exists(log):
            continue
        with open(log, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = ANSI.sub("", line).rstrip()
                if GD_ERRORS.search(line):
                    gd_errors.append("%s: %s" % (os.path.basename(log), line[:200]))
    passed = total - failed - pending
    rows = [
        "| Mesure | Valeur |", "|---|---|",
        "| Tests | %d |" % total,
        "| Réussis | %d |" % passed,
        "| Échoués | %d |" % failed,
        "| En attente (secret local absent, etc.) | %d |" % pending,
        "| Assertions | %d |" % asserts,
        "| Erreurs GDScript (journaux) | %d |" % len(gd_errors),
    ]
    out = "### Tests GUT\n\n" + "\n".join(rows) + "\n"
    if failures:
        out += "\n**Échecs**\n\n" + "\n".join("- `%s`" % f for f in failures) + "\n"
    if gd_errors:
        out += "\n**Erreurs GDScript**\n\n```\n" + "\n".join(gd_errors[:30]) + "\n```\n"
    if total == 0:
        out += "\n**Aucun test exécuté** (JUnit absent ou vide).\n"
    print(out)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(out + "\n")
    return 0 if total > 0 and failed == 0 and not gd_errors else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
