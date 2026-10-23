"""Étal en bois sous le panier + nappe wax (repère Blender : Z haut, avant -Y).
Le panier (ventre à z = -(épaisseur + 0,55)) repose sur le plateau.
Seul le haut de l'étal est visible en jeu (bas de l'écran)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import game_config, run_prop  # noqa: E402

ASSET_NAME = "stall_sandaga"
MAX_TRIS = 1500

TOP = -(game_config("wall_thickness") + 0.55)  # dessous du ventre de la calebasse
HALF_W = 7.5
FRONT = -1.7
DEPTH_BACK = 2.6
PLANK = 0.32
CLOTH_FRONT = FRONT - 0.03
DIAMONDS = 22
WAX_ROW = ["wax_yellow", "wax_green", "wax_yellow", "wax_red"]


def build(mb):
	# Plateau : deux planches (rainure sombre entre les deux).
	mb.box((0, (FRONT + DEPTH_BACK) * 0.5, TOP - PLANK * 0.5),
		(HALF_W * 2, DEPTH_BACK - FRONT, PLANK), "wood", {"front": "wood_light", "bottom": None})
	mb.quad((-HALF_W, FRONT - 0.005, TOP - PLANK * 0.55), (-HALF_W, FRONT - 0.005, TOP - PLANK * 0.45),
		(HALF_W, FRONT - 0.005, TOP - PLANK * 0.45), (HALF_W, FRONT - 0.005, TOP - PLANK * 0.55), "wood_dark")
	# Nappe wax qui tombe devant l'étal : fond orange, frise de losanges.
	top = TOP - PLANK
	bottom = top - 2.4
	mb.quad((-HALF_W, CLOTH_FRONT, bottom), (-HALF_W, CLOTH_FRONT, top),
		(HALF_W, CLOTH_FRONT, top), (HALF_W, CLOTH_FRONT, bottom), "wax_orange")
	y = CLOTH_FRONT - 0.01
	step = HALF_W * 2 / DIAMONDS
	for k in range(DIAMONDS):
		cx = -HALF_W + step * (k + 0.5)
		cz = top - 0.38
		h, w = 0.26, step * 0.42
		mb.quad((cx, y, cz - h), (cx - w, y, cz), (cx, y, cz + h), (cx + w, y, cz), WAX_ROW[k % len(WAX_ROW)])
		# Petit point central (motif wax « œil »)
		d = 0.06
		mb.quad((cx, y - 0.005, cz - d), (cx - d, y - 0.005, cz), (cx, y - 0.005, cz + d), (cx + d, y - 0.005, cz),
			"wax_blue")
	# Liseré bleu nuit sous la frise
	mb.quad((-HALF_W, y, top - 0.74), (-HALF_W, y, top - 0.68), (HALF_W, y, top - 0.68), (HALF_W, y, top - 0.74),
		"wax_blue")


if __name__ == "__main__":
	run_prop(sys.modules[__name__])
