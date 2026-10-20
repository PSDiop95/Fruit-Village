"""Tamarin (dakhar) : gousse brune mate, renflements à chaque graine, enroulée
en C serré (tient dans la sphère de collision), queue recourbée.
Référence : docs/refs/fruits/03_tamarin.jpg

Les renflements sont des ellipsoïdes qui se chevauchent : le contour du jeu
suit les normales (VisualConfig.outline_normal_ids) et non l'extrusion radiale.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, run  # noqa: E402

FRUIT_ID = "tamarin"
FACE = {"height": -0.5, "size": 0.62}
ARC_R = 0.5
CENTER = Vector((0.0, 0.0, -0.02))
# (angle sur l'arc en degrés dans le plan de face, rayon, profondeur y)
SEEDS = [(105, 0.33, 0.06), (160, 0.39, -0.04), (215, 0.42, 0.05),
	(270, 0.42, -0.05), (325, 0.38, 0.05), (372, 0.32, -0.02)]


def _seed(mb, ang, r, dy, index):
	a = math.radians(ang)
	c = CENTER + Vector((ARC_R * math.cos(a), dy, ARC_R * math.sin(a)))
	tangent = Vector((-math.sin(a), 0.0, math.cos(a)))
	radial = Vector((math.cos(a), 0.0, math.sin(a)))
	depth = Vector((0.0, 1.0, 0.0))
	rt, rr = r * 1.18, r  # allongé le long de la gousse

	def pos(th, ph):
		d = sph(th, ph)
		return c + tangent * (d.z * rt) + radial * (d.x * rr) + depth * (d.y * rr * 0.92)

	mb.lat_long(10, 7, pos, lambda th, ph, j, i: "tamarin")
	return c, tangent, rt


def build(mb):
	ends = [_seed(mb, a, r, dy, k) for k, (a, r, dy) in enumerate(SEEDS)]
	# Queue recourbée au bout supérieur gauche.
	c, t, rt = ends[0]
	base = c - t * (rt * 0.8)
	mid = base + Vector((0.02, 0.0, 0.14))
	mb.cylinder(base, mid, 0.07, 0.055, 6, "tamarin_dark")
	mb.cylinder(mid, mid + Vector((0.09, 0.0, 0.08)), 0.055, 0.04, 6, "tamarin_dark")


if __name__ == "__main__":
	run(sys.modules[__name__])
