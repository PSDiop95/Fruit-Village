"""Contrôle du projet Xcode exporté par Godot (appelé par tools/ios/build_ios.sh).

Usage : python3 tools/ios/check_plist.py <FruitVillage-Info.plist> <check|upload>

- App ID AdMob (GADApplicationIdentifier) : test Google en check, réel en upload ;
- ads_ids.cfg dans le .pck : absent en check (debug), présent en upload ;
- ATT (NSUserTrackingUsageDescription), chiffrement exempté, SKAdNetwork Google,
  orientation portrait seule, plein écran iPad.
Code de sortie 1 si une règle est violée. Bibliothèque standard seulement.
"""
import plistlib
import re
import sys
from pathlib import Path

TEST_PUBLISHER = "ca-app-pub-3940256099942544"
REAL_ID = re.compile(r"^ca-app-pub-\d{16}~\d{10}$")
GOOGLE_SKAN = "cstr6suwn9.skadnetwork"


def main() -> int:
    plist_path, mode = Path(sys.argv[1]), sys.argv[2]
    p = plistlib.loads(plist_path.read_bytes())
    errors = []

    app_id = p.get("GADApplicationIdentifier", "")
    shown = re.sub(r"(ca-app-pub-)\d{12}", r"\1############", app_id)
    print(f"  GADApplicationIdentifier : {shown or '(absent)'}")
    if mode == "upload" and not (REAL_ID.match(app_id) and not app_id.startswith(TEST_PUBLISHER)):
        errors.append("upload : App ID AdMob absent, modèle ou de test")
    if mode != "upload" and not app_id.startswith(TEST_PUBLISHER):
        errors.append("check (debug) : App ID AdMob réel dans l'Info.plist")

    if not p.get("NSUserTrackingUsageDescription"):
        errors.append("NSUserTrackingUsageDescription manquant (ATT)")
    if p.get("ITSAppUsesNonExemptEncryption") is not False:
        errors.append("ITSAppUsesNonExemptEncryption doit valoir false")
    skan = {d.get("SKAdNetworkIdentifier") for d in p.get("SKAdNetworkItems", [])}
    print(f"  SKAdNetworkItems : {len(skan)}")
    if GOOGLE_SKAN not in skan:
        errors.append(f"SKAdNetworkItems sans {GOOGLE_SKAN}")
    orient = set(p.get("UISupportedInterfaceOrientations", []))
    print(f"  orientations : {sorted(orient)}")
    if orient != {"UIInterfaceOrientationPortrait"}:
        errors.append("orientation : portrait seul attendu")
    if p.get("UIRequiresFullScreen") is not True:
        errors.append("UIRequiresFullScreen doit valoir true (iPad, portrait seul)")

    # Godot range le .pck à côté du projet Xcode (build/ios/), pas toujours dans
    # le dossier de l'Info.plist : on cherche aux deux endroits.
    pcks = list(plist_path.parent.glob("*.pck")) + list(plist_path.parent.parent.glob("*.pck"))
    print(f"  pck : {', '.join(f.name for f in pcks) or 'aucun'}")
    if not pcks:
        errors.append("aucun .pck trouvé à côté de l'Info.plist ni du projet Xcode")
    embedded = any(b"ads_ids.cfg" in f.read_bytes() for f in pcks)
    print(f"  ads_ids.cfg dans le .pck : {'oui' if embedded else 'non'}")
    if mode == "upload" and not embedded:
        errors.append("upload : ads_ids.cfg absent du .pck (aucune pub)")
    if mode != "upload" and embedded:
        errors.append("check (debug) : ads_ids.cfg embarqué")

    for e in errors:
        print(f"  ECHEC : {e}")
    print("== OK" if not errors else f"== ÉCHEC ({len(errors)})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
