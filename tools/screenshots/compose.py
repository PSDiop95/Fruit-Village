"""Captures Google Play 1080x1920 (9:16) : bandeau texte en haut + capture du jeu.

Entrée : captures brutes de capture_store.gd (dossier en argument, défaut
build/store_raw). Sortie : store/screenshots/<langue>/NN_nom.png.
Textes : tools/screenshots/captions.json (FR, EN). Police : Baloo 2 du jeu.
Usage : uv run --no-project --with pillow python tools/screenshots/compose.py [dossier_brut]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
W, H = 1080, 1920
BAND = 300           # hauteur du bandeau texte
MARGIN = 40          # marge autour de la capture
SKY_TOP = (48, 135, 218)
SKY_BOTTOM = (255, 196, 92)
TEXT = (255, 255, 255)
OUTLINE = (92, 46, 14)
FONT = ROOT / "assets/fonts/Baloo2-VariableFont_wght.ttf"


def gradient() -> Image.Image:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM)))
    return img


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([800])  # graisse ExtraBold
    except (OSError, AttributeError):
        pass
    return f


def fit_text(d: ImageDraw.ImageDraw, text: str, max_w: int) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """Plus grande taille sur 1 ligne, sinon 2 lignes équilibrées (pas de mot
    orphelin). Les espaces insécables (avant « ! ») ne coupent jamais."""
    words = text.split(" ")
    for size in range(104, 50, -4):
        f = font(size)
        if d.textlength(text, font=f) <= max_w:
            return f, [text]
        if size > 92:
            continue
        cuts = [(" ".join(words[:c]), " ".join(words[c:])) for c in range(1, len(words))]
        cuts = [ab for ab in cuts if max(d.textlength(s, font=f) for s in ab) <= max_w]
        if cuts:
            a, b = min(cuts, key=lambda ab: abs(d.textlength(ab[0], font=f) - d.textlength(ab[1], font=f)))
            return f, [a, b]
    return font(52), [text]


def compose(raw: Image.Image, caption: str) -> Image.Image:
    canvas = gradient().convert("RGBA")
    d = ImageDraw.Draw(canvas)
    f, lines = fit_text(d, caption, W - 2 * MARGIN)
    line_h = f.size * 1.08
    y = (BAND - line_h * len(lines)) / 2 + 6
    for line in lines:
        tw = d.textlength(line, font=f)
        d.text(((W - tw) / 2, y), line, font=f, fill=TEXT, stroke_width=max(4, f.size // 14), stroke_fill=OUTLINE)
        y += line_h

    # Capture : mise à l'échelle dans la zone sous le bandeau, coins arrondis + ombre.
    area_h = H - BAND - MARGIN
    s = min((W - 2 * MARGIN) / raw.width, area_h / raw.height)
    shot = raw.convert("RGBA").resize((round(raw.width * s), round(raw.height * s)), Image.LANCZOS)
    x, y = (W - shot.width) // 2, BAND
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius=44, fill=255)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((40, 20, 0, 140), (x + 8, y + 14), mask)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(16)))
    border = Image.new("L", (shot.width + 16, shot.height + 16), 0)
    ImageDraw.Draw(border).rounded_rectangle((0, 0, border.width - 1, border.height - 1), radius=52, fill=255)
    canvas.paste((255, 247, 230, 255), (x - 8, y - 8), border)
    canvas.paste(shot, (x, y), mask)
    return canvas.convert("RGB")


def main() -> None:
    raw_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build/store_raw"
    captions = json.loads((Path(__file__).parent / "captions.json").read_text(encoding="utf-8"))
    for lang, items in captions.items():
        out = ROOT / "store/screenshots" / lang
        out.mkdir(parents=True, exist_ok=True)
        for name, caption in items.items():
            src = raw_dir / f"{name}.png"
            if not src.exists():
                print(f"manque {src}")
                continue
            img = compose(Image.open(src), caption)
            assert img.size == (W, H)
            img.save(out / f"{name}.png")
            print(f"{lang}/{name}.png  « {caption} »")


if __name__ == "__main__":
    main()
