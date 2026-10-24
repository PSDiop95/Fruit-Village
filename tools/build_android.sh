#!/usr/bin/env bash
# Build des APK debug M4 (Windows, Git Bash).
#   tools/build_android.sh          -> les deux APK
#   tools/build_android.sh mock     -> APK MockAds seul (sans Gradle)
#   tools/build_android.sh admob    -> APK AdMob test seul (Gradle + Firebase)
# Prérequis : C:/Users/hp/android-tools (JDK 17, SDK), modèles Godot 4.7.2,
# google-services.json à la racine du projet pour Firebase.
set -u
ONLY="${1:-all}"
cd "$(dirname "$0")/.."
GODOT="/c/Program Files/Godot/Godot.exe"
export JAVA_HOME="$(cygpath -w "$(ls -d /c/Users/hp/android-tools/jdk-17* | head -1)")"
LOG="build/export_admob.log"

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

if [ "$ONLY" = all ] || [ "$ONLY" = mock ]; then
	"$GODOT" --headless --path . --export-debug "Android MockAds" build/fruit_village_m4_mockads.apk 2>&1 | grep -E "Signed|ERROR: Cannot"
fi
if [ "$ONLY" = all ] || [ "$ONLY" = admob ]; then
	stop_gradle
	rm -rf android/build/build
	[ -f android/build/build.gradle ] || "$GODOT" --headless --path . --install-android-build-template --quit
	patch_firebase_gradle
	patch_launch_gradle
	# Lancement sans écran noir : ressources Android (tools/android_res) et
	# image du splash en drawable-nodpi (thème : export_presets.cfg).
	cp -r tools/android_res/. android/build/res/
	mkdir -p android/build/res/drawable-nodpi
	cp assets/ui/splash.png android/build/res/drawable-nodpi/fv_splash.png
	"$GODOT" --headless --path . --export-debug "Android AdMob test" \
		build/fruit_village_m4_admob_test.apk > "$LOG" 2>&1
	grep -E "BUILD SUCCESSFUL|BUILD FAILED|What went wrong" "$LOG" | head -3
	stop_gradle
fi
ls -la build/*.apk
