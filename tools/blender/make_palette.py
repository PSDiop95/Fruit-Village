"""Génère assets/textures/palette.png (256x256 RGBA) + palette.json.

Pur Python : `python tools/blender/make_palette.py` (ou via Blender).
palette.json : nom -> UV (convention Godot, v vers le bas) pour le décor/UI.
"""
import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_def as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def write_png(path, img):
	raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in img)

	def chunk(tag, data):
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

	h, w = len(img), len(img[0])
	png = b"\x89PNG\r\n\x1a\n"
	png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
	png += chunk(b"IDAT", zlib.compress(raw, 9))
	png += chunk(b"IEND", b"")
	with open(path, "wb") as f:
		f.write(png)


def main():
	out_dir = os.path.join(ROOT, "assets", "textures")
	os.makedirs(out_dir, exist_ok=True)
	write_png(os.path.join(out_dir, "palette.png"), P.pixels())
	data = {"size": P.SIZE, "colors": {}, "ramps": {}}
	for name, h, gloss in P.COLORS:
		u, v = P.color_uv(name)
		data["colors"][name] = {"uv": [u, 1.0 - v], "hex": h, "gloss": gloss}
	for name, stops, gloss in P.RAMPS:
		u0, v = P.ramp_uv(name, 0.0)
		u1, _ = P.ramp_uv(name, 1.0)
		data["ramps"][name] = {"uv0": [u0, 1.0 - v], "uv1": [u1, 1.0 - v], "gloss": gloss}
	with open(os.path.join(out_dir, "palette.json"), "w", encoding="utf-8") as f:
		json.dump(data, f, indent=1)
	print("palette: %d couleurs, %d dégradés" % (len(P.COLORS), len(P.RAMPS)))


if __name__ == "__main__":
	main()
