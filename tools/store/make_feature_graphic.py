"""Image de présentation Google Play 1024x500 (PNG 24 bits, sans transparence).

Fond : illustration du marché (art_src/background_marche_baie.png) ; logo
centré avec ombre douce. Pas de texte ajouté (Google déconseille le texte
dans l'image de présentation ; le logo suffit).
Usage : uv run --no-project --with pillow python tools/store/make_feature_graphic.py
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
W, H = 1024, 500


def main() -> None:
    bg = Image.open(ROOT / "art_src/background_marche_baie.png").convert("RGB")
    s = W / bg.width
    bg = bg.resize((W, round(bg.height * s)), Image.LANCZOS)
    top = (bg.height - H) // 3  # garde le ciel
    bg = bg.crop((0, top, W, top + H))
    bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(1.2))).enhance(0.92)
    canvas = bg.convert("RGBA")

    logo = Image.open(ROOT / "assets/branding/fruit-village-logo.png").convert("RGBA")
    lh = 400
    logo = logo.resize((round(logo.width * lh / logo.height), lh), Image.LANCZOS)
    x, y = (W - logo.width) // 2, (H - lh) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = logo.getchannel("A").point(lambda a: a * 0.45)
    shadow.paste((20, 10, 0, 255), (x + 6, y + 12), alpha)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(logo, (x, y))
    out = ROOT / "store/graphics/feature_graphic_1024x500.png"
    canvas.convert("RGB").save(out)
    print(out.name, canvas.size)


if __name__ == "__main__":
    main()
