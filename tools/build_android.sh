#!/usr/bin/env bash
# Build des APK debug (Windows, Git Bash). Release : tools/build_release.sh.
#   tools/build_android.sh          -> les deux APK
#   tools/build_android.sh mock     -> APK MockAds seul (sans Gradle)
#   tools/build_android.sh admob    -> APK AdMob test seul (Gradle + Firebase)
set -u
ONLY="${1:-all}"
cd "$(dirname "$0")/.."
source tools/android_common.sh
LOG="build/export_admob.log"
mkdir -p build

if [ "$ONLY" = all ] || [ "$ONLY" = mock ]; then
	"$GODOT" --headless --path . --export-debug "Android MockAds" build/fruit_village_mockads.apk 2>&1 | grep -E "Signed|ERROR: Cannot"
fi
if [ "$ONLY" = all ] || [ "$ONLY" = admob ]; then
	prepare_gradle_project
	"$GODOT" --headless --path . --export-debug "Android AdMob test" \
		build/fruit_village_admob_test.apk > "$LOG" 2>&1
	grep -E "BUILD SUCCESSFUL|BUILD FAILED|What went wrong" "$LOG" | head -3
	stop_gradle
fi
ls -la build/*.apk
