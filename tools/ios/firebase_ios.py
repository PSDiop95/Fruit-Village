#!/usr/bin/env python3
"""Prépare les plugins iOS Firebase (godotx 3.1.0) pour l'App Store.

Le plugin godotx livre le SDK Firebase 12.16.0 en xcframeworks STATIQUES,
NON SIGNÉS, déclarés « embedded » : Xcode les copiait dans l'app et Apple
refusait le binaire (ITMS-91065, signature manquante). Ici :

1. chaque xcframework du SDK est remplacé par celui du Firebase.zip officiel
   de la même version (signé par Google, mêmes noms, mêmes bibliothèques) ;
2. les dépendances passent de « embedded » à « linked » : liaison statique,
   rien dans Frameworks/ ;
3. les manifestes de confidentialité (*_Privacy.bundle) des frameworks
   statiques sont ajoutés aux ressources de l'app (« files » du .gdip) ;
4. doublons supprimés : firebase_core déclare déjà tout le socle commun à
   Analytics (lié deux fois avec -ObjC : symboles en double).

Usage : firebase_ios.py <ios/plugins> <dossier Firebase/ du zip officiel>
"""
import os
import re
import shutil
import sys

WRAPPER_PREFIX = "Godotx"
SDK_GROUPS = ("FirebaseAnalytics", "FirebaseMessaging")


def gdip_list(text, key):
    m = re.search(r"^%s=\[(.*?)\]" % key, text, re.M | re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def gdip_set(text, key, values):
    line = "%s=[%s]" % (key, ", ".join('"%s"' % v for v in values))
    if re.search(r"^%s=\[" % key, text, re.M):
        return re.sub(r"^%s=\[.*?\]" % key, lambda _: line, text, count=1, flags=re.M | re.S)
    return text.replace("[dependencies]\n", "[dependencies]\n\n%s\n" % line, 1)


def official(sdk_dir, name):
    for group in SDK_GROUPS:
        path = os.path.join(sdk_dir, group, name)
        if os.path.isdir(path):
            return path
    sys.exit("ERREUR : %s absent du Firebase.zip officiel" % name)


def privacy_bundles(xcf_path):
    found = []
    slice_dir = os.path.join(xcf_path, "ios-arm64")
    for fw in sorted(os.listdir(slice_dir)) if os.path.isdir(slice_dir) else []:
        fw_dir = os.path.join(slice_dir, fw)
        for entry in sorted(os.listdir(fw_dir)):
            if entry.endswith("_Privacy.bundle"):
                # Chemin relatif au .gdip, séparateurs « / » (lu par Godot).
                found.append("/".join([os.path.basename(xcf_path), "ios-arm64", fw, entry]))
    return found


def prepare(plugins_dir, sdk_dir):
    core_deps = set()
    for module in ("firebase_core", "firebase_analytics", "firebase_messaging"):
        mod_dir = os.path.join(plugins_dir, module)
        gdip_path = os.path.join(mod_dir, module + ".gdip")
        if not os.path.isfile(gdip_path):
            continue
        with open(gdip_path, encoding="utf-8") as f:
            text = f.read()
        deps = gdip_list(text, "embedded") + gdip_list(text, "linked")
        if module == "firebase_core":
            core_deps = set(deps)
        elif module == "firebase_analytics":
            deps = [d for d in deps if d not in core_deps]
        files = [p for p in gdip_list(text, "files")]
        for name in deps:
            dest = os.path.join(mod_dir, name)
            shutil.rmtree(dest, ignore_errors=True)
            shutil.copytree(official(sdk_dir, name), dest, symlinks=True)
            files += [p for p in privacy_bundles(dest) if p not in files]
        # Copies devenues inutiles (déjà déclarées par firebase_core).
        for entry in os.listdir(mod_dir):
            if entry.endswith(".xcframework") and not entry.startswith(WRAPPER_PREFIX) \
                    and entry not in deps:
                shutil.rmtree(os.path.join(mod_dir, entry))
        text = gdip_set(text, "embedded", [])
        text = gdip_set(text, "linked", deps)
        text = gdip_set(text, "files", files)
        with open(gdip_path, "w", encoding="utf-8") as f:
            f.write(text)
        print("%s : %d SDK signés liés, %d manifestes de confidentialité" % (module, len(deps), len(files)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    prepare(sys.argv[1], sys.argv[2])
