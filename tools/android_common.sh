#!/usr/bin/env bash
# Fonctions communes aux builds Android (sourcé par build_android.sh et
# build_release.sh). Windows / Git Bash.
# Prérequis : C:/Users/hp/android-tools (JDK 17, SDK, bundletool), modèles
# d'export Godot 4.7.2, google-services.json à la racine pour Firebase.

GODOT="${GODOT:-/c/Program Files/Godot/Godot.exe}"
ANDROID_TOOLS="${ANDROID_TOOLS:-/c/Users/hp/android-tools}"
export JAVA_HOME="${JAVA_HOME:-$(cygpath -w "$(ls -d "$ANDROID_TOOLS"/jdk-17* | head -1)")}"
JAVA="$(cygpath -u "$JAVA_HOME")/bin/java"
BUILD_TOOLS="$(ls -d "$ANDROID_TOOLS"/sdk/build-tools/* | sort -V | tail -1)"
BUNDLETOOL="${BUNDLETOOL:-$(ls "$ANDROID_TOOLS"/bundletool/bundletool-all-*.jar 2>/dev/null | sort -V | tail -1)}"

# Seuls les daemons Gradle : ils verrouillent android/build/build entre deux builds.
stop_gradle() {
	powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='java.exe'\" | Where-Object { \$_.CommandLine -match 'GradleDaemon|GradleWrapperMain' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" 2>/dev/null
}

# Plugin google-services (Firebase) dans le Gradle du modèle (README godotx_firebase).
patch_firebase_gradle() {
	local f=android/build/build.gradle
	[ -f google-services.json ] || return 0
	grep -q "com.google.gms:google-services" "$f" && return 0
	{ printf "// Added for Firebase (godotx_firebase): must stay first in the file.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.google.gms:google-services:4.4.4'
    }
}

"; cat "$f"; printf "
// Added for Firebase (godotx_firebase): reads google-services.json.
apply plugin: 'com.google.gms.google-services'
"; } > "$f.new" && mv "$f.new" "$f"
}

# Fond de fenêtre au lancement : Godot impose #000000 (attribut réservé) ;
# une tâche Gradle le remplace par l'image du splash avant la compilation.
# Écran système gardé jusqu'au démarrage du jeu (sinon : surface noire).
_patch_activity() {
	sed -i 's|if (godot != null \&\& godot.getDisableGodotSplash()) {|if (godot != null) { // Fruit Village : pas de noir avant le chargement|' \
		android/build/src/main/java/com/godot/game/GodotApp.java
}

patch_launch_gradle() {
	local f=android/build/build.gradle
	grep -q "fv_launch" "$f" && { _patch_activity; return 0; }
	_patch_activity
	cat >> "$f" <<'GRADLE'

// Added for Fruit Village: launch window shows the splash image, not black
// (Godot's generated GodotAppMainTheme forces android:windowBackground=#000000).
tasks.named("preBuild") {
    doFirst {
        def themes = file("res/values/themes.xml")
        if (themes.exists()) {
            themes.text = themes.text.replace(
                '<item name="android:windowBackground">#000000</item>',
                '<item name="android:windowBackground">@drawable/fv_launch</item>')
        }
    }
}
GRADLE
}

# Modèle Gradle prêt : installé si absent, patchs, ressources de lancement.
prepare_gradle_project() {
	stop_gradle
	rm -rf android/build/build
	[ -f android/build/build.gradle ] || "$GODOT" --headless --path . --install-android-build-template --quit
	patch_firebase_gradle
	patch_launch_gradle
	# Lancement sans écran noir : ressources Android (tools/android_res) et
	# image du splash en drawable-nodpi (thème : export_presets.cfg).
	cp -r tools/android_res/. android/build/res/
	# Fichiers du jeu d'un export précédent (APK : base ; AAB : asset pack) :
	# Godot ne vide pas l'autre emplacement, Gradle refuse alors les doublons.
	rm -rf android/build/src/main/assets android/build/assetPackInstallTime/src/main/assets
	mkdir -p android/build/res/drawable-nodpi
	cp assets/ui/splash.png android/build/res/drawable-nodpi/fv_splash.png
}

# Valeur d'une option d'un preset : preset_option "Android Release" version/code
preset_option() {
	awk -v name="name=\"$1\"" -v key="$2" '
		/^\[preset\.[0-9]+\]$/ { sec=$0; inpreset=0 }
		$0 == name { want=sec }
		/^\[preset\.[0-9]+\.options\]$/ { opts=$0; sub(/\.options\]$/, "]", opts) }
		index($0, key "=") == 1 && opts == want && want != "" { v=substr($0, length(key) + 2); gsub(/"/, "", v); print v; exit }
	' export_presets.cfg
}
