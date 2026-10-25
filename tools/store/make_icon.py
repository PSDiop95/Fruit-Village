"""Icône Google Play 512x512 (PNG 32 bits, carré plein) depuis art_src/icon_2048.png.

L'icône source est un carré arrondi sur fond transparent ; Google Play applique
lui-même l'arrondi (20 %) : on rend un carré plein, coins comblés par le décor
(même image agrandie, légèrement floutée). Produit aussi les aperçus 48/96 px.
Usage : uv run --no-project --with pillow python tools/store/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art_src/icon_2048.png"
OUT = ROOT / "store/graphics"


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    l, t, r, b = src.getchannel("A").getbbox()
    w = min(r - l, b - t)
    card = src.crop((l, t, l + w, t + w))  # carré arrondi
    # Fond : la même image agrandie de 35 % (coins = ciel en haut, feuillage en bas).
    big = card.resize((int(w * 1.35),) * 2, Image.LANCZOS)
    o = (big.width - w) // 2
    bg = big.crop((o, o, o + w, o + w)).filter(ImageFilter.GaussianBlur(6))
    full = Image.alpha_composite(bg, card)
    # Rogne 2 % pour retirer le liseré du bord arrondi.
    m = int(w * 0.02)
    full = full.crop((m, m, w - m, w - m)).resize((512, 512), Image.LANCZOS)
    full.putalpha(255)
    OUT.mkdir(parents=True, exist_ok=True)
    full.save(OUT / "icon_512.png")

    # Aperçus : masque Play (rayon 20 %) à 48 et 96 px + planche de contrôle.
    sheet = Image.new("RGBA", (420, 150), (245, 245, 245, 255))
    x = 10
    for size in (48, 96, 128):
        ic = full.resize((size, size), Image.LANCZOS)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.2), fill=255)
        ic.putalpha(mask)
        sheet.alpha_composite(ic, (x, 140 - size))
        x += size + 30
        if size == 48:
            ic.save(OUT / "icon_preview_48.png")
    sheet.save(OUT / "icon_preview_sheet.png")
    print("icon_512.png", full.size, full.mode)


if __name__ == "__main__":
    main()
