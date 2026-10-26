#!/usr/bin/env bash
# Build iOS de Fruit Village — macOS + Xcode 26 (GitHub Actions « macos-26 »
# ou un Mac). Voir docs/IOS_RELEASE.md.
#
#   tools/ios/build_ios.sh check    projet Xcode exporté en DEBUG (identifiants
#                                   de test) + compilation sans signature.
#                                   Aucun secret requis.
#   tools/ios/build_ios.sh upload   tests GUT -> export RELEASE -> archive signée
#                                   (signature automatique via la clé API App
#                                   Store Connect) -> envoi sur TestFlight.
#
# Variables (mode upload) :
#   APPLE_TEAM_ID        identifiant d'équipe Apple (10 caractères)
#   ASC_KEY_ID           ID de la clé API App Store Connect
#   ASC_ISSUER_ID        Issuer ID de la clé
#   ASC_KEY_PATH         chemin du fichier AuthKey_<ID>.p8
#   BUILD_NUMBER         numéro de build (CFBundleVersion), croissant
#   ads_ids.cfg et GoogleService-Info.plist présents à la racine du projet.
set -euo pipefail
cd "$(dirname "$0")/../.."
MODE="${1:-check}"
GODOT_VERSION="4.7.2"
WORK="${RUNNER_TEMP:-/tmp}/fv-ios"
PRESET="iOS Release"
OUT_DIR="build/ios"
PROJECT="$OUT_DIR/FruitVillage.xcodeproj"

# Binaires tiers épinglés (sources officielles, empreintes vérifiées).
GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
GODOT_ZIP_SHA512="38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca"
TEMPLATES_TPZ="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
TEMPLATES_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
ADMOB_URL="https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/ios-template-v${GODOT_VERSION}.zip"
ADMOB_SHA256="6e7f1c807761f9c0ad45d335ac4c74acd4bba7a31f9e1c7cd16a5220010cce71"
FIREBASE_URL="https://github.com/godot-x/firebase/releases/download/3.1.0/godotx_firebase.zip"
FIREBASE_SHA256="da7273def2ff744efacaab70e2ad863d65a4225ec401f5335de40a19df8170c1"

die() { echo "ERREUR : $*" >&2; exit 1; }
fetch() {  # fetch <url> <fichier> <algo> <empreinte>
	[ -f "$2" ] || curl -fsSL --retry 3 -o "$2" "$1"
	echo "$4  $2" | shasum -a "$3" -c - > /dev/null || die "empreinte invalide : $2"
}
preset_set() {  # preset_set <option> <valeur brute> : section options du preset iOS
	local sec
	sec="$(awk -v name="name=\"$PRESET\"" '/^\[preset\.[0-9]+\]$/ { s=$0 } $0 == name { sub(/\]$/, ".options]", s); print s; exit }' export_presets.cfg)"
	awk -v sec="$sec" -v key="$1" -v val="$2" '
		/^\[/ { cur=$0 }
		cur == sec && index($0, key "=") == 1 { $0 = key "=" val }
		{ print }' export_presets.cfg > export_presets.cfg.tmp && mv export_presets.cfg.tmp export_presets.cfg
}

[ "$(uname -s)" = "Darwin" ] || die "macOS requis (Xcode)"
xcodebuild -version | sed -n 1p  # sed lit tout : pas de « broken pipe » (pipefail)
mkdir -p "$WORK" "$OUT_DIR"

# ---- Godot + modèles d'export iOS
GODOT="$WORK/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
	fetch "$GODOT_URL/$GODOT_ZIP" "$WORK/$GODOT_ZIP" 512 "$GODOT_ZIP_SHA512"
	unzip -q -o "$WORK/$GODOT_ZIP" -d "$WORK"
fi
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"
if [ ! -f "$TPL_DIR/ios.zip" ]; then
	fetch "$GODOT_URL/$TEMPLATES_TPZ" "$WORK/$TEMPLATES_TPZ" 512 "$TEMPLATES_SHA512"
	mkdir -p "$TPL_DIR"
	unzip -q -o -j "$WORK/$TEMPLATES_TPZ" "templates/ios.zip" "templates/version.txt" -d "$TPL_DIR"
fi

# ---- Bibliothèques iOS des plugins (non versionnées : trop lourdes)
if [ ! -d addons/admob/ios/bin/ads/libs ]; then
	fetch "$ADMOB_URL" "$WORK/admob-ios.zip" 256 "$ADMOB_SHA256"
	mkdir -p addons/admob/ios/bin
	unzip -q -o "$WORK/admob-ios.zip" -d addons/admob/ios/bin
fi
if [ ! -f ios/plugins/firebase_core/firebase_core.gdip ]; then
	fetch "$FIREBASE_URL" "$WORK/godotx_firebase.zip" 256 "$FIREBASE_SHA256"
	unzip -q -o "$WORK/godotx_firebase.zip" "godotx_firebase/ios/plugins/firebase_core/*" \
		"godotx_firebase/ios/plugins/firebase_analytics/*" -d "$WORK/fb"
	mkdir -p ios/plugins
	cp -R "$WORK/fb/godotx_firebase/ios/plugins/." ios/plugins/
fi

# ---- Import (cache .godot) puis tests
"$GODOT" --headless --path . --import > "$OUT_DIR/import.log" 2>&1 || true
if [ "$MODE" = "upload" ]; then
	set +e
	"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit > "$OUT_DIR/tests.log" 2>&1
	code=$?
	set -e
	# perl : le sed de macOS ne comprend pas \x1b (couleurs ANSI de GUT).
	perl -pe 's/\e\[[0-9;]*m//g' "$OUT_DIR/tests.log" > "$OUT_DIR/tests.txt"
	grep -E "^(Tests|Passing Tests|Failing Tests)" "$OUT_DIR/tests.txt" || true
	# Code de sortie GUT + aucun test en échec (un test « en attente » n'est pas un échec).
	if [ $code -ne 0 ] || grep -qE "^Failing Tests +[1-9]" "$OUT_DIR/tests.txt"; then
		die "tests en échec : pas d'export"
	fi
fi

# ---- Export du projet Xcode
rm -rf "$OUT_DIR/FruitVillage" "$PROJECT"
if [ "$MODE" = "upload" ]; then
	: "${APPLE_TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}" "${BUILD_NUMBER:?}"
	[ -f ads_ids.cfg ] || die "ads_ids.cfg absent"
	grep -q "^\[ios\]" ads_ids.cfg || die "ads_ids.cfg : section [ios] absente"
	[ -f GoogleService-Info.plist ] || die "GoogleService-Info.plist absent"
	preset_set application/app_store_team_id "\"$APPLE_TEAM_ID\""
	preset_set application/version "\"$BUILD_NUMBER\""
	"$GODOT" --headless --path . --export-release "$PRESET" "$OUT_DIR/FruitVillage.ipa" > "$OUT_DIR/export.log" 2>&1 || true
	grep -q "FV_RELEASE" "$OUT_DIR/export.log" && die "identifiants AdMob iOS de release invalides (export.log)"
else
	preset_set application/app_store_team_id '"0000000000"'
	"$GODOT" --headless --path . --export-debug "$PRESET" "$OUT_DIR/FruitVillage.ipa" > "$OUT_DIR/export.log" 2>&1 || true
fi
[ -d "$PROJECT" ] || { tail -40 "$OUT_DIR/export.log"; die "projet Xcode non produit"; }
SCHEME="$(xcodebuild -list -json -project "$PROJECT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["project"]["schemes"][0])')"
PLIST="$(find "$OUT_DIR/FruitVillage" -maxdepth 1 -name "*-Info.plist" | sed -n 1p)"
echo "Schéma Xcode : $SCHEME — Info.plist : $PLIST"

# ---- Contrôles de l'Info.plist (identifiants pub, ATT, chiffrement)
python3 tools/ios/check_plist.py "$PLIST" "$MODE"
find "$OUT_DIR" -maxdepth 2 -name "*.pck" -exec ls -la {} ;  # emplacement du .pck (journal)

if [ "$MODE" != "upload" ]; then
	xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
		-destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build \
		> "$OUT_DIR/xcodebuild.log" 2>&1 || { tail -60 "$OUT_DIR/xcodebuild.log"; die "compilation Xcode en échec"; }
	echo "Compilation iOS (sans signature) : OK"
	exit 0
fi

# ---- Archive signée (signature automatique, clé API) puis envoi TestFlight
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH"
	-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
	-destination "generic/platform=iOS" -archivePath "$OUT_DIR/FruitVillage.xcarchive" archive \
	"${AUTH[@]}" DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
	CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER="" \
	> "$OUT_DIR/archive.log" 2>&1 || { tail -60 "$OUT_DIR/archive.log"; die "archive en échec"; }
cat > "$OUT_DIR/ExportOptions.plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>$APPLE_TEAM_ID</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLISTEOF
xcodebuild -exportArchive -archivePath "$OUT_DIR/FruitVillage.xcarchive" \
	-exportOptionsPlist "$OUT_DIR/ExportOptions.plist" -exportPath "$OUT_DIR/export" "${AUTH[@]}" \
	> "$OUT_DIR/upload.log" 2>&1 || { tail -60 "$OUT_DIR/upload.log"; die "envoi App Store Connect en échec"; }
echo "Envoyé sur App Store Connect : build $BUILD_NUMBER (version 1.0.0). Traitement Apple ≈ 15-30 min, puis TestFlight."
