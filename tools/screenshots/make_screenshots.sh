#!/usr/bin/env bash
# Régénère les 6 captures de la fiche Play (FR + EN), ré-exécutable.
#   tools/screenshots/make_screenshots.sh
# 1. capture_store.gd rend le jeu à 1080x1920 (vrai rendu GPU : Godot
#    --headless ne dessine rien). Linux sans écran : xvfb-run + OpenGL ;
#    Windows/macOS : fenêtre ouverte quelques secondes.
# 2. compose.py ajoute les bandeaux (captions.json) -> store/screenshots/{fr,en}/.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$( [ -x "/c/Program Files/Godot/Godot.exe" ] && echo "/c/Program Files/Godot/Godot.exe" || command -v godot )}"
RAW="build/store_raw"
mkdir -p "$RAW"
RAW_ABS="$(cd "$RAW" && pwd -W 2>/dev/null || pwd)"

ARGS=(--path . --resolution 1080x1920 -s tools/screenshots/capture_store.gd -- "$RAW_ABS")
if [ "$(uname -s)" = "Linux" ] && [ -z "${DISPLAY:-}" ]; then
	xvfb-run -a -s "-screen 0 1080x1920x24" "$GODOT" --rendering-driver opengl3 "${ARGS[@]}"
else
	"$GODOT" "${ARGS[@]}"
fi
uv run --no-project --with pillow python tools/screenshots/compose.py "$RAW"
