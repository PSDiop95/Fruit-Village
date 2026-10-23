"""Bissap : calice rouge profond, pétales charnus refermés en pointes, collerette
de sépales à la base, petit pédoncule vert. Référence : docs/refs/fruits/02_bissap.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, run, FRONT_PHI  # noqa: E402

FRUIT_ID = "bissap"
FACE = {"height": -0.12, "size": 0.78}
PETALS = 5
SEPALS = 10


def _lobe(ph):
	# 1 au milieu d'un pétale, 0 dans le creux ; un pétale plein face caméra.
	return 0.5 + 0.5 * math.cos(PETALS * (ph - FRONT_PHI))


def build(mb):
	def pos(th, ph):
		c, s = math.cos(th), math.sin(th)
		lb = _lobe(ph)
		w = (0.62 + 0.16 * lb) * s * (1.0 - 0.3 * max(c, 0.0))
		if c > 0.0:
			# Bouton : pointes des pétales plus hautes que les creux.
			z = c * 0.74 + 0.26 * c * c * lb ** 2 - 0.08 * c * c * (1.0 - lb)
		else:
			z = c * 0.6  # base arrondie, posée sur la collerette
		return Vector((w * math.cos(ph), w * math.sin(ph), z))

	def col(th, ph, j, i):
		lb = _lobe(ph)
		if lb < 0.18:
			return "bissap_dark"
		if lb > 0.85 and 0.35 < th < 2.0:
			return "bissap_light"
		return "bissap"

	mb.lat_long(PETALS * 4, 14, pos, col)
	# Collerette : sépales effilés, légèrement relevés, décalés des pétales.
	for k in range(SEPALS):
		a = FRONT_PHI + 2 * math.pi * (k + 0.5) / SEPALS
		ca, sa = math.cos(a), math.sin(a)
		base = Vector((0.32 * ca, 0.32 * sa, -0.47))
		tip = Vector((0.93 * ca, 0.93 * sa, -0.33))
		mb.blade(base, tip, 0.15, 0.05, (-0.35 * ca, -0.35 * sa, 1.0), None, color="bissap_dark")
	mb.cylinder((0, 0, -0.5), (0, 0, -0.86), 0.12, 0.09, 6, "leaf_dark")


if __name__ == "__main__":
	run(sys.modules[__name__])
