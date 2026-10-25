#!/usr/bin/env bash
# Contrôle d'un AAB/APK : identifiants pub (réels en release, test en debug),
# alignement 16 Ko, permissions, versions, taille, plus gros fichiers.
#   tools/check_build.sh build/release/fruit_village-1.0.0-1.aab release
#   tools/check_build.sh build/fruit_village_admob_test.apk debug
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/android_common.sh
FILE="$1"
MODE="${2:-release}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

case "$FILE" in
	*.aab)
		[ -n "$BUNDLETOOL" ] || { echo "bundletool introuvable ($ANDROID_TOOLS/bundletool)"; exit 1; }
		"$JAVA" -jar "$BUNDLETOOL" dump manifest --bundle="$FILE" > "$TMP/manifest.txt"
		if "$JAVA" -jar "$BUNDLETOOL" dump config --bundle="$FILE" | grep -q "PAGE_ALIGNMENT_16K"; then
			echo "bundletool : PAGE_ALIGNMENT_16K déclaré dans la config du bundle"
		else
			echo "bundletool : PAGE_ALIGNMENT_16K absent de la config du bundle"
		fi ;;
	*.apk)
		"$BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$FILE" > "$TMP/manifest.txt"
		"$BUILD_TOOLS/zipalign" -c -P 16 4 "$FILE" > /dev/null \
			&& echo "zipalign -P 16 : OK" || echo "zipalign -P 16 : ÉCHEC" ;;
	*) echo "fichier .aab ou .apk attendu"; exit 1 ;;
esac
uv run --no-project python tools/inspect_build.py "$FILE" "$MODE" "$TMP/manifest.txt"
