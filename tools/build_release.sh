#!/usr/bin/env bash
# Build de release Google Play (Windows, Git Bash) :
#   1. vérifie les prérequis (clé d'upload, ads_ids.cfg, google-services.json) ;
#   2. lance les tests GUT en headless, s'arrête au premier échec ;
#   3. exporte l'AAB signé (preset « Android Release ») ;
#   4. contrôle l'AAB (tools/check_build.sh) : identifiants pub réels, 16 Ko,
#      permissions, versionCode, targetSdk, taille ; estime le téléchargement.
# Ne téléverse RIEN : l'envoi dans la Play Console reste manuel.
#
# Signature : variables d'environnement, sinon export_credentials.cfg (racine,
# ignoré par git, voir export_credentials.example.cfg) :
#   FV_UPLOAD_KEYSTORE   chemin du keystore d'upload (.jks)
#   FV_UPLOAD_ALIAS      alias de la clé
#   FV_UPLOAD_PASSWORD   mot de passe (keystore et clé)
#   tools/build_release.sh [--skip-tests]
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/android_common.sh
PRESET="Android Release"
SKIP_TESTS="${1:-}"

die() { echo "ERREUR : $*" >&2; exit 1; }

# ---- 1. Prérequis
if [ -z "${FV_UPLOAD_KEYSTORE:-}" ] && [ -f export_credentials.cfg ]; then
	# shellcheck disable=SC1091
	source export_credentials.cfg
fi
[ -n "${FV_UPLOAD_KEYSTORE:-}" ] || die "clé d'upload non configurée (export_credentials.cfg ou FV_UPLOAD_KEYSTORE) : voir docs/KEYSTORE.md"
[ -f "$FV_UPLOAD_KEYSTORE" ] || die "keystore introuvable : $FV_UPLOAD_KEYSTORE"
[ -n "${FV_UPLOAD_ALIAS:-}" ] && [ -n "${FV_UPLOAD_PASSWORD:-}" ] || die "FV_UPLOAD_ALIAS / FV_UPLOAD_PASSWORD manquants"
[ -f ads_ids.cfg ] || die "ads_ids.cfg absent (vrais identifiants AdMob, modèle : ads_ids.example.cfg)"
PACKAGE="$(preset_option "$PRESET" package/unique_name)"
VERSION_CODE="$(preset_option "$PRESET" version/code)"
VERSION_NAME="$(preset_option "$PRESET" version/name)"
[ -f google-services.json ] || die "google-services.json absent (Firebase)"
grep -q "\"package_name\": *\"$PACKAGE\"" google-services.json \
	|| die "google-services.json ne déclare pas $PACKAGE : ajoute l'app Android dans la console Firebase et retélécharge le fichier"
[ -n "$BUNDLETOOL" ] || die "bundletool absent de $ANDROID_TOOLS/bundletool"
echo "Fruit Village $VERSION_NAME (code $VERSION_CODE) — $PACKAGE"

# ---- 2. Tests
if [ "$SKIP_TESTS" != "--skip-tests" ]; then
	echo "Tests GUT (headless)…"
	mkdir -p build/release
	set +e
	"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit > build/release/tests.log 2>&1
	code=$?
	set -e
	grep -E "^(Tests|Passing Tests|Failing Tests|Pending|Risky)" build/release/tests.log | sed 's/\x1b\[[0-9;]*m//g' || true
	if [ $code -ne 0 ] || ! grep -q "All tests passed" build/release/tests.log; then
		die "tests en échec (build/release/tests.log) : pas d'export"
	fi
fi

# ---- 3. Export AAB signé
prepare_gradle_project
mkdir -p build/release
OUT="build/release/fruit_village-$VERSION_NAME-$VERSION_CODE.aab"
rm -f "$OUT"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cygpath -w "$FV_UPLOAD_KEYSTORE")"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$FV_UPLOAD_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$FV_UPLOAD_PASSWORD"
echo "Export $PRESET…"
"$GODOT" --headless --path . --export-release "$PRESET" "$OUT" > build/release/export.log 2>&1 || true
stop_gradle
grep -E "BUILD SUCCESSFUL|BUILD FAILED|What went wrong|FV_RELEASE" build/release/export.log | head -5 || true
grep -q "FV_RELEASE" build/release/export.log && die "identifiants AdMob de release invalides (voir ci-dessus)"
[ -f "$OUT" ] || die "AAB non produit (build/release/export.log)"

# Signature : certificat de la clé d'upload (empreinte à comparer dans la Play Console)
"$(cygpath -u "$JAVA_HOME")/bin/jarsigner" -verify -certs "$OUT" > build/release/jarsigner.log 2>&1 \
	&& echo "Signature : OK (jarsigner -verify)" || die "AAB non signé (build/release/jarsigner.log)"

# ---- 4. Contrôles + rapport
tools/check_build.sh "$OUT" release | tee build/release/report.txt
echo "Taille de téléchargement estimée (bundletool get-size, par appareil) :" | tee -a build/release/report.txt
TMP="$(mktemp -d)"
"$JAVA" -jar "$BUNDLETOOL" build-apks --bundle="$OUT" --output="$TMP/fv.apks" \
	--ks="$(cygpath -w "$FV_UPLOAD_KEYSTORE")" --ks-key-alias="$FV_UPLOAD_ALIAS" \
	--ks-pass="pass:$FV_UPLOAD_PASSWORD" --key-pass="pass:$FV_UPLOAD_PASSWORD" > /dev/null
"$JAVA" -jar "$BUNDLETOOL" get-size total --apks="$TMP/fv.apks" --dimensions=ABI | tee -a build/release/report.txt
rm -rf "$TMP"
echo "AAB : $OUT ($(du -h "$OUT" | cut -f1))"
echo "Rien n'a été téléversé. Étape suivante : Play Console > Test interne (docs/LAUNCH_PLAN.md)."
