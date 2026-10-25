#!/usr/bin/env bash
# Incrémente le version code du preset « Android Release » (obligatoire à
# chaque envoi dans la Play Console : un code déjà utilisé est refusé).
#   tools/bump_version.sh            -> code +1, nom inchangé
#   tools/bump_version.sh 1.0.1      -> code +1 et nouveau nom de version
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/android_common.sh
PRESET="Android Release"
OLD="$(preset_option "$PRESET" version/code)"
[[ "$OLD" =~ ^[0-9]+$ ]] || { echo "version/code introuvable pour $PRESET"; exit 1; }
NEW=$((OLD + 1))
NAME="${1:-$(preset_option "$PRESET" version/name)}"
# Section options du preset Release uniquement.
SEC="$(awk -v name="name=\"$PRESET\"" '/^\[preset\.[0-9]+\]$/ { s=$0 } $0 == name { sub(/\]$/, ".options]", s); print s; exit }' export_presets.cfg)"
awk -v sec="$SEC" -v code="$NEW" -v vname="$NAME" '
	/^\[/ { cur=$0 }
	cur == sec && /^version\/code=/ { $0 = "version/code=" code }
	cur == sec && /^version\/name=/ { $0 = "version/name=\"" vname "\"" }
	{ print }
' export_presets.cfg > export_presets.cfg.tmp && mv export_presets.cfg.tmp export_presets.cfg
echo "$PRESET : version code $OLD -> $NEW, version name $NAME"
