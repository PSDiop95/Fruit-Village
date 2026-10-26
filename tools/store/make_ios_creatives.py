"""Visuels App Store (page produit, oct. 2026) : en-tête et résultats de recherche.

Spécifications Apple (Creative assets specifications) :
- en-tête            21:9  3840x1646  JPEG/PNG
- résultats recherche 3:2   2880x1920  (min 1920x1280, max 3840x2560)
- universel           16:9  5244x2950  PNG (sert aux deux emplacements)
Sans transparence. Fond : illustration du marché ; logo du jeu centré, sans
texte ajouté (Apple superpose icône, nom et bouton Obtenir).
Usage : uv run --no-project --with pillow python tools/store/make_ios_creatives.py
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "store/ios/creatives"
FORMATS = {
    "header_3840x1646.jpg": (3840, 1646),
    "search_2880x1920.jpg": (2880, 1920),
    "universal_5244x2950.png": (5244, 2950),
}


def background(w: int, h: int) -> Image.Image:
    art = Image.open(ROOT / "art_src/background_marche_baie.png").convert("RGB")
    s = max(w / art.width, h / art.height)
    art = art.resize((round(art.width * s), round(art.height * s)), Image.LANCZOS)
    left = (art.width - w) // 2
    top = max(0, (art.height - h) // 3)  # garde le ciel
    art = art.crop((left, top, left + w, top + h))
    # Fond agrandi : léger flou (masque l'agrandissement), un peu assombri
    # pour détacher le logo.
    art = art.filter(ImageFilter.GaussianBlur(w / 900))
    return ImageEnhance.Brightness(art).enhance(0.9)


def logo() -> Image.Image:
    img = Image.open(ROOT / "art_src/logo_2048.png").convert("RGBA")
    return img.crop(img.getchannel("A").getbbox())


def compose(w: int, h: int) -> Image.Image:
    canvas = background(w, h).convert("RGBA")
    lg = logo()
    lh = round(h * 0.62)
    lg = lg.resize((round(lg.width * lh / lg.height), lh), Image.LANCZOS)
    x, y = (w - lg.width) // 2, round((h - lh) * 0.42)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = lg.getchannel("A").point(lambda a: a * 0.45)
    shadow.paste((20, 10, 0, 255), (x + round(h * 0.008), y + round(h * 0.018)), alpha)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(h * 0.02)))
    canvas.alpha_composite(lg, (x, y))
    return canvas.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (w, h) in FORMATS.items():
        img = compose(w, h)
        if name.endswith(".jpg"):
            img.save(OUT / name, quality=92)
        else:
            img.save(OUT / name, optimize=True)
        print(f"{name}  {img.size}  {(OUT / name).stat().st_size / 1e6:.1f} Mo")


if __name__ == "__main__":
    main()
