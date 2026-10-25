"""Montage de la vidéo promo (store/video_promo_script.md).

Entrée : dossier de make_promo.sh (frames/ 1080x1920, audio/f.wav, marks_*.txt).
Sortie : store/video/fruit_village_promo_{20s,15s}_{fr,en}.mp4 (H.264 + AAC, 30 i/s).
Usage : uv run --no-project --with pillow --with imageio-ffmpeg python tools/video/edit.py build/promo
"""
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FPS = 30
W, H = 1080, 1920
FONT = ROOT / "assets/fonts/Baloo2-VariableFont_wght.ttf"
TEXT = (255, 255, 255)
OUTLINE = (92, 46, 14)

# Plans (ordre de la séquence promo.gd) et durées dans la version 20 s.
SHOTS = ["hook", "mango", "combo", "tension", "decisive", "baobab", "fact", "cta"]
CUT_20 = {"hook": 18, "mango": 42, "combo": 120, "tension": 60, "decisive": 30,
          "baobab": 150, "fact": 75, "cta": 105}
# 15 s : sans la tension, carte 1 s, Baobab et appel à l'action raccourcis.
CUT_15 = {"hook": 18, "mango": 42, "combo": 120, "tension": 0, "decisive": 30,
          "baobab": 120, "fact": 30, "cta": 90}

CAPTIONS = {
    "fr": {"mango": "Deux pareils ? Ça fusionne !", "tension": "Garde ton calme…",
           "baobab": "Fais pousser le Baobab !", "fact": "11 fruits d'Afrique à découvrir",
           "cta": "Joue gratuitement\nsur Google Play"},
    "en": {"mango": "Match two, watch them merge!", "tension": "Keep your cool…",
           "baobab": "Grow the mighty Baobab!", "fact": "11 African fruits to discover",
           "cta": "Play free\non Google Play"},
}
# Zoom (début, fin) et centre (x, y en fraction de l'image) par plan.
ZOOM = {"hook": ((1.6, 1.45), (0.42, 0.30)), "mango": ((1.3, 1.0), (0.5, 0.45)),
        "combo": ((1.0, 1.12), (0.5, 0.42))}


def marks(path: Path) -> dict[str, int]:
    out = {}
    for line in path.read_text().splitlines():
        _, name, frame = line.split()
        out[name] = int(frame)
    return out


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([800])
    except (OSError, AttributeError):
        pass
    return f


def zoomed(img: Image.Image, z: float, cx: float, cy: float) -> Image.Image:
    if z <= 1.001:
        return img
    cw, ch = W / z, H / z
    x0 = min(max(cx * W - cw / 2, 0), W - cw)
    y0 = min(max(cy * H - ch / 2, 0), H - ch)
    return img.resize((W, H), Image.LANCZOS, box=(x0, y0, x0 + cw, y0 + ch))


def caption(img: Image.Image, text: str, t: float, y: float, base: int = 92) -> None:
    """Texte centré (1 ou 2 lignes, séparées par « \\n ») qui « pop » à
    l'apparition (t = secondes depuis le début du plan)."""
    d = ImageDraw.Draw(img)
    lines = text.split("\n")
    size = base
    while max(d.textlength(s, font=font(size)) for s in lines) > W - 80 and size > 48:
        size -= 4
    pop = min(1.0, t / 0.2)
    scale = 0.6 + 0.4 * (1 - (1 - pop) ** 3) + 0.08 * math.sin(min(t, 0.35) / 0.35 * math.pi)
    f = font(max(10, int(size * scale)))
    line_h = f.size * 1.1
    y0 = y * H - line_h * len(lines) / 2
    for i, s in enumerate(lines):
        tw = d.textlength(s, font=f)
        d.text(((W - tw) / 2, y0 + i * line_h), s, font=f, fill=TEXT,
               stroke_width=max(4, f.size // 12), stroke_fill=OUTLINE)


def cta_card(splash: Image.Image, logo_t: float) -> Image.Image:
    z = 1.0 + 0.05 * logo_t / 3.5
    # Copie : le texte est dessiné sur l'image rendue, jamais sur la source.
    return zoomed(splash, z, 0.5, 0.35) if z > 1.001 else splash.copy()


def render(raw: Path, m: dict[str, int], cut: dict[str, int], lang: str, out_dir: Path) -> int:
    splash = Image.open(ROOT / "assets/ui/splash.png").convert("RGB")
    top = (splash.height - H) // 2 - 120
    splash = splash.crop((0, top, W, top + H))
    n = 0
    for shot in SHOTS:
        length = cut[shot]
        for k in range(length):
            t = k / FPS
            if shot == "cta":
                img = cta_card(splash, t)
            else:
                img = Image.open(raw / f"f{m[shot] + k:08d}.png").convert("RGB")
                if shot in ZOOM:
                    (z0, z1), (cx, cy) = ZOOM[shot]
                    u = k / max(length - 1, 1)
                    img = zoomed(img, z0 + (z1 - z0) * (u * u * (3 - 2 * u)), cx, cy)
            text = CAPTIONS[lang].get(shot)
            if text:
                caption(img, text, t, 0.78 if shot == "cta" else 0.47, 124 if shot == "cta" else 92)
            img.save(out_dir / f"{n:05d}.jpg", quality=93)
            n += 1
    return n


def audio(wav_in: Path, m: dict[str, int], cut: dict[str, int], wav_out: Path) -> None:
    """Concatène les mêmes plans dans la piste du Movie Maker (fondus de 15 ms aux coupes)."""
    import array
    with wave.open(str(wav_in)) as w:
        rate, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        data = array.array("h" if sw == 2 else "i", w.readframes(w.getnframes()))
    out = array.array(data.typecode)
    fade = int(rate * 0.015)
    for shot in SHOTS:
        if cut[shot] == 0:
            continue
        a = int(m[shot] / FPS * rate) * ch
        b = a + int(cut[shot] / FPS * rate) * ch
        seg = data[a:b]
        for i in range(min(fade, len(seg) // ch)):
            g = i / fade
            for c in range(ch):
                seg[i * ch + c] = int(seg[i * ch + c] * g)
                j = len(seg) - (i + 1) * ch + c
                seg[j] = int(seg[j] * g)
        out.extend(seg)
    with wave.open(str(wav_out), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(sw)
        w.setframerate(rate)
        w.writeframes(out.tobytes())


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build/promo")
    mf, ma = marks(src / "marks_frames.txt"), marks(src / "marks_audio.txt")
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    dest = ROOT / "store/video"
    dest.mkdir(parents=True, exist_ok=True)
    for label, cut in (("20s", CUT_20), ("15s", CUT_15)):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            audio(src / "audio/f.wav", ma, cut, tmp / "a.wav")
            for lang in ("fr", "en"):
                frames = tmp / lang
                frames.mkdir()
                n = render(src / "frames", mf, cut, lang, frames)
                out = dest / f"fruit_village_promo_{label}_{lang}.mp4"
                subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(FPS),
                                "-i", str(frames / "%05d.jpg"), "-i", str(tmp / "a.wav"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
                                "-preset", "slow", "-c:a", "aac", "-b:a", "160k",
                                "-movflags", "+faststart", "-shortest", str(out)], check=True)
                print(f"{out.relative_to(ROOT)}  {n / FPS:.1f} s  {out.stat().st_size / 1e6:.1f} Mo")


if __name__ == "__main__":
    main()
