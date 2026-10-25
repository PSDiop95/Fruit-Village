#!/usr/bin/env bash
# Crée la CLÉ D'UPLOAD Google Play de Fruit Village. À exécuter par toi, une
# seule fois. Avec Play App Signing, Google garde la clé de signature de
# l'app ; cette clé-ci sert seulement à téléverser. Lire docs/KEYSTORE.md.
#
#   tools/make_upload_keystore.sh [dossier]   (défaut : ~/fruit-village-keys)
#
# - Le keystore est créé HORS du projet (jamais dans git).
# - keytool demande lui-même le mot de passe (rien dans l'historique du shell).
# - Écrit export_credentials.cfg (ignoré par git) SANS le mot de passe : à
#   compléter toi-même, ou à fournir par FV_UPLOAD_PASSWORD.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/android_common.sh
DIR="${1:-$HOME/fruit-village-keys}"
ALIAS="fruitvillage-upload"
KS="$DIR/fruitvillage-upload.jks"
KEYTOOL="$(cygpath -u "$JAVA_HOME")/bin/keytool"

[ -e "$KS" ] && { echo "Existe déjà : $KS (rien n'est écrasé)"; exit 1; }
mkdir -p "$DIR"
echo "Création de $KS (alias $ALIAS, RSA 4096, 30 ans)."
echo "Choisis un mot de passe fort (≥ 12 caractères) et note-le dans ton gestionnaire de mots de passe."
"$KEYTOOL" -genkeypair -v \
	-keystore "$(cygpath -w "$KS")" -storetype PKCS12 \
	-alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10950 \
	-dname "CN=Smart IA Services, O=Smart IA Services, L=Dakar, C=SN"

# Certificat public (à garder avec les sauvegardes ; utile si la clé est perdue).
"$KEYTOOL" -export -rfc -keystore "$(cygpath -w "$KS")" -alias "$ALIAS" \
	-file "$(cygpath -w "$DIR/upload_certificate.pem")"
# Empreintes lues dans le certificat public (sans mot de passe). keytool est
# localisé : « SHA 1: » en français, « SHA1: » en anglais.
"$KEYTOOL" -printcert -file "$(cygpath -w "$DIR/upload_certificate.pem")" | grep -E "SHA ?(1|256):" \
	| sed 's/^[[:space:]]*//' | tee "$DIR/upload_certificate_fingerprints.txt" || true

if [ ! -f export_credentials.cfg ]; then
	cat > export_credentials.cfg <<CFG
# Signature release (ignoré par git). Lu par tools/build_release.sh.
FV_UPLOAD_KEYSTORE='$KS'
FV_UPLOAD_ALIAS='$ALIAS'
# Mot de passe : décommente et remplis, OU exporte FV_UPLOAD_PASSWORD avant le build.
# FV_UPLOAD_PASSWORD='...'
CFG
	echo "export_credentials.cfg écrit (sans mot de passe)."
fi
echo
echo "FAIT. Maintenant (docs/KEYSTORE.md) : 2 copies HORS de cet ordinateur de"
echo "  $DIR (keystore + certificat) et du mot de passe, rangées séparément."
