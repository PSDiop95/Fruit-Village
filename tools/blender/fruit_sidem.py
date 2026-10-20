"""Sidem (jujube) : petite baie ovale brun-rouge brillante, queue droite claire.
Référence : docs/refs/fruits/01_sidem.jpg"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, smoothstep, run  # noqa: E402

FRUIT_ID = "sidem"
FACE = {"height": -0.08, "size": 0.9}


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		# Œuf vertical (largeur/hauteur ≈ 0,86), fossette d'attache au sommet.
		dimple = 1.0 - 0.06 * smoothstep(0.3, 0.0, th)
		return Vector((d.x * 0.8, d.y * 0.8, d.z * 0.93)) * dimple

	def col(th, ph, j, i):
		return "stem_dark" if j == 0 else "sidem"

	mb.lat_long(20, 12, pos, col)
	mb.cylinder((0, 0, 0.84), (0.05, 0.0, 1.06), 0.06, 0.045, 6, "stem_brown")


if __name__ == "__main__":
	run(sys.modules[__name__])
