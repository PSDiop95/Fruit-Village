#!/usr/bin/env bash
# Vidéo promo Fruit Village (store/video_promo_script.md), ré-exécutable :
#   tools/video/make_promo.sh
# 1. Passe son  : Movie Maker de Godot (30 i/s fixes) -> build/promo/audio/f.wav
# 2. Passe image : même séquence, pas de temps fixe 30 i/s, images 1080x1920
#    -> build/promo/frames/ (le Movie Maker reste à la taille de l'écran).
# 3. Montage (tools/video/edit.py) : zooms, textes FR/EN, carte finale, MP4
#    20 s et 15 s -> store/video/ (MP4 non versionnés).
# Linux sans écran : préfixer les commandes Godot par xvfb-run -a.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$( [ -x "/c/Program Files/Godot/Godot.exe" ] && echo "/c/Program Files/Godot/Godot.exe" || command -v godot )}"
OUT=build/promo
rm -rf "$OUT" && mkdir -p "$OUT/audio" "$OUT/frames"
ABS="$(cd "$OUT" && pwd -W 2>/dev/null || pwd)"

echo "Passe son…"
"$GODOT" --path . --resolution 1080x1920 --write-movie "$ABS/audio/f.png" --fixed-fps 30 \
	-s tools/video/promo.gd 2>&1 | grep "^MARK" > "$OUT/marks_audio.txt"
rm -f "$OUT"/audio/*.png
echo "Passe image…"
"$GODOT" --path . --resolution 1080x1920 --fixed-fps 30 \
	-s tools/video/promo.gd -- "$ABS/frames" 2>&1 | grep "^MARK" > "$OUT/marks_frames.txt"
echo "Montage…"
uv run --no-project --with pillow --with imageio-ffmpeg python tools/video/edit.py "$OUT"
