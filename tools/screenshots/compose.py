"""Captures des stores : bandeau texte en haut + capture du jeu, par format.

- play       : Google Play 1080x1920 (9:16)        -> store/screenshots/<langue>/
- iphone_6_9 : App Store iPhone 6,9" 1320x2868     -> store/ios/screenshots/iphone_6_9/<langue>/
- iphone_6_3 : App Store iPhone 6,3" 1206x2622     -> store/ios/screenshots/iphone_6_3/<langue>/
- ipad_13    : App Store iPad 13" 2064x2752         -> store/ios/screenshots/ipad_13/<langue>/

Entrée : captures brutes 1080x1920 de capture_store.gd (dossier en argument,
défaut build/store_raw). Textes : tools/screenshots/captions.json (FR, EN).
Police : Baloo 2 du jeu.
Usage : uv run --no-project --with pillow python tools/screenshots/compose.py [dossier_brut] [format ...]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TARGETS = {
    "play": (1080, 1920, "store/screenshots"),
    "iphone_6_9": (1320, 2868, "store/ios/screenshots/iphone_6_9"),
    "iphone_6_3": (1206, 2622, "store/ios/screenshots/iphone_6_3"),
    "ipad_13": (2064, 2752, "store/ios/screenshots/ipad_13"),
}
BAND = 300           # hauteur du bandeau texte (à 1920 de haut)
MARGIN = 40          # marge autour de la capture (idem)
SKY_TOP = (48, 135, 218)
SKY_BOTTOM = (255, 196, 92)
TEXT = (255, 255, 255)
OUTLINE = (92, 46, 14)
FONT = ROOT / "assets/fonts/Baloo2-VariableFont_wght.ttf"


def gradient(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM)))
    return img


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([800])  # graisse ExtraBold
    except (OSError, AttributeError):
        pass
    return f


def fit_text(d: ImageDraw.ImageDraw, text: str, max_w: int, k: float) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """Plus grande taille sur 1 ligne, sinon 2 lignes équilibrées (pas de mot
    orphelin). Les espaces insécables (avant « ! ») ne coupent jamais.
    `k` : échelle du format (1 = 1920 de haut)."""
    words = text.split(" ")
    for base in range(104, 50, -4):
        f = font(round(base * k))
        if d.textlength(text, font=f) <= max_w:
            return f, [text]
        if base > 92:
            continue
        cuts = [(" ".join(words[:c]), " ".join(words[c:])) for c in range(1, len(words))]
        cuts = [ab for ab in cuts if max(d.textlength(s, font=f) for s in ab) <= max_w]
        if cuts:
            a, b = min(cuts, key=lambda ab: abs(d.textlength(ab[0], font=f) - d.textlength(ab[1], font=f)))
            return f, [a, b]
    return font(round(52 * k)), [text]


def compose(raw: Image.Image, caption: str, w: int = 1080, h: int = 1920) -> Image.Image:
    k = h / 1920
    band, margin = round(BAND * k), round(MARGIN * k)
    canvas = gradient(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    f, lines = fit_text(d, caption, w - 2 * margin, k)
    line_h = f.size * 1.08
    y = (band - line_h * len(lines)) / 2 + 6 * k
    for line in lines:
        tw = d.textlength(line, font=f)
        d.text(((w - tw) / 2, y), line, font=f, fill=TEXT, stroke_width=max(4, f.size // 14), stroke_fill=OUTLINE)
        y += line_h

    # Capture : mise à l'échelle dans la zone sous le bandeau, coins arrondis + ombre.
    area_h = h - band - margin
    s = min((w - 2 * margin) / raw.width, area_h / raw.height)
    shot = raw.convert("RGBA").resize((round(raw.width * s), round(raw.height * s)), Image.LANCZOS)
    x, y = (w - shot.width) // 2, band
    r, b = round(44 * k), round(8 * k)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius=r, fill=255)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((40, 20, 0, 140), (x + b, y + round(14 * k)), mask)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(16 * k)))
    border = Image.new("L", (shot.width + 2 * b, shot.height + 2 * b), 0)
    ImageDraw.Draw(border).rounded_rectangle((0, 0, border.width - 1, border.height - 1), radius=r + b, fill=255)
    canvas.paste((255, 247, 230, 255), (x - b, y - b), border)
    canvas.paste(shot, (x, y), mask)
    return canvas.convert("RGB")


def main() -> None:
    args = sys.argv[1:]
    raw_dir = Path(args.pop(0)) if args and args[0] not in TARGETS else ROOT / "build/store_raw"
    targets = args or list(TARGETS)
    captions = json.loads((Path(__file__).parent / "captions.json").read_text(encoding="utf-8"))
    for target in targets:
        w, h, dest = TARGETS[target]
        for lang, items in captions.items():
            out = ROOT / dest / lang
            out.mkdir(parents=True, exist_ok=True)
            for name, caption in items.items():
                src = raw_dir / f"{name}.png"
                if not src.exists():
                    print(f"manque {src}")
                    continue
                img = compose(Image.open(src), caption, w, h)
                assert img.size == (w, h)
                img.save(out / f"{name}.png")
                print(f"{target}/{lang}/{name}.png  « {caption} »")


if __name__ == "__main__":
    main()
