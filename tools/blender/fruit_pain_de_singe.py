"""Pain de singe (fruit du baobab) : ovale vertical olive velouté, tige de bois
en T au sommet, rare et précieux (halo rendu dans Godot).
Référence : docs/refs/fruits/11_pain_de_singe.jpg (affiné à 0,8 de large pour
rester proche de la sphère de collision)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, hash01, run  # noqa: E402

FRUIT_ID = "pain_de_singe"
FACE = {"height": -0.1, "size": 0.8}


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		w = 1.0 - 0.06 * d.z  # œuf : un peu plus large en bas
		lump = 0.0 if th in (0.0, math.pi) else (hash01(th, ph, 9.0) - 0.5) * 0.02
		return Vector((d.x * 0.8 * w, d.y * 0.76 * w, d.z * 0.88)) * (1.0 + lump)

	def col(th, ph, j, i):
		return "pds"  # velours uni : le shader fait le duvet et l'ombre

	mb.lat_long(24, 14, pos, col)

	# Tige en T : pied court + traverse de bois.
	mb.cylinder((0, 0, 0.8), (0.0, 0, 0.95), 0.055, 0.045, 6, "wood_stem")
	mb.cylinder((-0.17, 0.0, 0.97), (0.2, 0.0, 0.9), 0.05, 0.045, 6, "wood_stem")


if __name__ == "__main__":
	run(sys.modules[__name__])
