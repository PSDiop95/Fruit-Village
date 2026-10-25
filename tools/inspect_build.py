"""Contrôle d'un AAB/APK Fruit Village (appelé par tools/check_build.sh).

Usage : python tools/inspect_build.py <fichier.aab|apk> <release|debug> <manifeste.txt>

Vérifie et affiche :
- App ID AdMob du manifeste : réel en release, test Google en debug ;
- ads_ids.cfg embarqué en release (vrais identifiants), absent en debug ;
- alignement 16 Ko (segments LOAD des .so 64 bits, Android 15+) ;
- versionCode, versionName, minSdk, targetSdk, permissions, ABI, taille ;
- les 10 plus gros fichiers du paquet.
Code de sortie 1 si une règle est violée. Bibliothèque standard seulement.
"""

import os
import re
import struct
import sys
import zipfile

TEST_PUBLISHER = "ca-app-pub-3940256099942544"
REAL_ID = re.compile(r"^ca-app-pub-\d{16}[~/]\d{10}$")
ADS_IDS = "ads_ids.cfg"
PAGE_16K = 16384

## Seules permissions acceptées dans le paquet final (manifeste fusionné).
## Toute autre (ajoutée par un SDK) fait échouer le contrôle.
ALLOWED_PERMISSIONS = {
    "android.permission.INTERNET": "pubs, statistiques",
    "android.permission.ACCESS_NETWORK_STATE": "pub chargée seulement si réseau",
    "com.google.android.gms.permission.AD_ID": "identifiant publicitaire, AdMob",
    "android.permission.VIBRATE": "vibrations de jeu (désactivables)",
    "android.permission.POST_NOTIFICATIONS": "rappels quotidiens (Android 13+)",
    "android.permission.WAKE_LOCK": "WorkManager/Firebase : envoi différé des événements",
    "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE":
        "Firebase : source d'installation (campagnes)",
    "<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION": "AndroidX : interne, signature",
}

errors: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)
    print(f"  ECHEC : {msg}")


def load_alignments(data: bytes) -> tuple[int, list[int]]:
    """Classe ELF (32/64) et alignement de chaque segment PT_LOAD."""
    if data[:4] != b"\x7fELF":
        return 0, []
    is64 = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    if is64:
        phoff, = struct.unpack_from(endian + "Q", data, 0x20)
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 0x36)
    else:
        phoff, = struct.unpack_from(endian + "I", data, 0x1C)
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 0x2A)
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type, = struct.unpack_from(endian + "I", data, off)
        if p_type != 1:  # PT_LOAD
            continue
        if is64:
            p_align, = struct.unpack_from(endian + "Q", data, off + 0x30)
        else:
            p_align, = struct.unpack_from(endian + "I", data, off + 0x1C)
        aligns.append(p_align)
    return (64 if is64 else 32), aligns


def manifest_value(text: str, pattern: str) -> str:
    m = re.search(pattern, text)
    return m.group(1) if m else ""


def main() -> int:
    path, mode, manifest_path = sys.argv[1], sys.argv[2], sys.argv[3]
    manifest = open(manifest_path, encoding="utf-8", errors="replace").read()
    release = mode == "release"
    z = zipfile.ZipFile(path)
    names = z.namelist()

    print(f"== {path} ({mode})")
    # bundletool dump manifest (XML) ou aapt2 dump xmltree (A: attr=valeur).
    def attr(name: str) -> str:
        return manifest_value(manifest, rf'{name}(?:\(0x[0-9a-f]+\))?="?([^"\s)]+)') or \
            manifest_value(manifest, rf'{name}(?:\(0x[0-9a-f]+\))?=\(type 0x10\)0x([0-9a-f]+)')

    package = manifest_value(manifest, r'package="([^"]+)"')
    print(f"  package       : {package}")
    print(f"  versionCode   : {attr('android:versionCode')}")
    print(f"  versionName   : {attr('android:versionName')}")
    print(f"  minSdk        : {attr('android:minSdkVersion')}")
    print(f"  targetSdk     : {attr('android:targetSdkVersion')}")
    perms = sorted(set(re.findall(r'uses-permission[^>]*?android:name(?:\(0x[0-9a-f]+\))?="([^"]+)"', manifest)
                       + re.findall(r'uses-permission\b[\s\S]*?A: android:name\(0x01010003\)="([^"]+)"', manifest)))
    print("  permissions   :")
    for p in perms:
        why = ALLOWED_PERMISSIONS.get(p.replace(package, "<package>"))
        print(f"    - {p}" + (f"  ({why})" if why else "  ← NON AUTORISÉE"))
        if why is None:
            fail(f"permission non justifiée : {p}")

    # ---- AdMob App ID (manifeste)
    m = re.search(r'com\.google\.android\.gms\.ads\.APPLICATION_ID"[\s\S]{0,200}?android:value(?:\(0x[0-9a-f]+\))?="([^"]+)"', manifest)
    app_id = m.group(1) if m else ""
    shown = re.sub(r"(ca-app-pub-)\d{12}", r"\1############", app_id)
    print(f"  AdMob App ID  : {shown or '(absent)'}")
    if release:
        if not REAL_ID.match(app_id):
            fail("release : App ID AdMob absent, modèle ou de test dans le manifeste")
    elif not app_id.startswith(TEST_PUBLISHER):
        fail("debug : le manifeste contient un App ID AdMob réel (attendu : test Google)")

    # ---- ads_ids.cfg embarqué ?
    cfg_entries = [n for n in names if n.endswith("/" + ADS_IDS) or n == ADS_IDS]
    cfg_text = ""
    for n in cfg_entries:
        cfg_text += z.read(n).decode("utf-8", "replace")
    for n in names:  # .pck éventuel (export sans Gradle)
        if n.endswith(".pck"):
            blob = z.read(n)
            if ADS_IDS.encode() in blob:
                cfg_entries.append(n + ":" + ADS_IDS)
                cfg_text += blob.decode("latin-1")
    ids = re.findall(r'(?:app_id|rewarded_id|interstitial_id)="([^"]*)"', cfg_text)
    print(f"  ads_ids.cfg   : {'embarqué' if cfg_entries else 'absent'}")
    if release:
        if not cfg_entries:
            fail("release : ads_ids.cfg absent du paquet (aucune pub)")
        elif len(ids) < 3 or not all(REAL_ID.match(v) for v in ids):
            fail("release : ads_ids.cfg contient un identifiant de test, vide ou modèle")
    elif cfg_entries and any(REAL_ID.match(v) for v in ids):
        fail("debug : ads_ids.cfg (vrais identifiants) embarqué")

    # ---- fichiers de dev ou secrets qui ne doivent jamais partir
    forbidden = re.compile(r"(^|/)(\.mcp\.json|\.gutconfig\.json|google-services\.json|"
                           r"export_credentials\.cfg|[^/]+\.(jks|keystore|p12))$|(^|/)assets/(build|tests|tools|docs)/")
    leaked = [n for n in names if forbidden.search(n)]
    for n in leaked:
        fail(f"fichier interdit dans le paquet : {n}")

    # ---- bibliothèques natives, alignement 16 Ko
    libs = [n for n in names if n.endswith(".so")]
    abis = sorted({n.split("/")[-2] for n in libs})
    print(f"  ABI           : {', '.join(abis)}")
    print("  alignement 16 Ko (segments LOAD) :")
    for n in sorted(libs):
        bits, aligns = load_alignments(z.read(n))
        ok = bool(aligns) and min(aligns) >= PAGE_16K
        size = z.getinfo(n).file_size / 1e6
        verdict = "OK 16 Ko" if ok else ("non requis (32 bits)" if bits == 32 else "NON ALIGNÉ")
        print(f"    {n:<60} {size:6.1f} Mo  align min {min(aligns) if aligns else 0:>6}  {verdict}")
        if bits == 64 and not ok:
            fail(f"{n} : non aligné 16 Ko")

    # ---- taille et plus gros fichiers
    total = sum(i.file_size for i in z.infolist())
    packed = sum(i.compress_size for i in z.infolist())
    print(f"  taille fichier: {os.path.getsize(path) / 1e6:.1f} Mo "
          f"(contenu {total / 1e6:.1f} Mo décompressé, {packed / 1e6:.1f} Mo compressé)")
    print("  10 plus gros fichiers (compressé / décompressé) :")
    for i in sorted(z.infolist(), key=lambda i: i.compress_size, reverse=True)[:10]:
        print(f"    {i.compress_size / 1e6:6.2f} / {i.file_size / 1e6:6.2f} Mo  {i.filename}")

    print(f"== {'OK' if not errors else 'ÉCHEC (' + str(len(errors)) + ')'}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
