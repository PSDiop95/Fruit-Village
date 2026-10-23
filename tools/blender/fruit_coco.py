"""Noix de coco : brune à facettes, fibres claires en stries verticales, trois
« yeux » creusés au sommet, éclat de chair blanche en bas à gauche.
Référence : docs/refs/fruits/10_coco.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, hash01, run, FRONT_PHI  # noqa: E402

FRUIT_ID = "coco"
FACE = {"height": -0.08, "size": 0.92}
CHIP = Vector((0.66, -0.5, 0.56)).normalized()
FIBERS = 40


def _surface(d):
	return Vector((d.x * 0.95, d.y * 0.95, d.z))


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		facet = 0.0 if th in (0.0, math.pi) else (hash01(ph, th, 2.0) - 0.5) * 0.04
		return _surface(d) * (1.0 + facet)

	def col(th, ph, j, i):
		return "coco"

	mb.lat_long(20, 12, pos, col)
	# Fibres : traits clairs et sombres le long des méridiens, côté caméra.
	for k in range(FIBERS):
		th = 0.55 + 2.1 * hash01(k, 1.0)
		ph = FRONT_PHI + (hash01(k, 2.0) - 0.5) * 2.9
		d = sph(th, ph)
		if abs(d.x) < 0.42 and -0.42 < d.z < 0.3:
			continue  # zone du visage
		color = "coco_light" if k % 3 else "coco_dark"
		mb.streak(d, _surface, 0.24 + 0.22 * hash01(k, 3.0), 0.05, color,
			tilt=(hash01(k, 4.0) - 0.5) * 0.4)
	mb.patch(CHIP, _surface, 0.22, "coco_flesh", rim_color="coco_dark", rim=0.05,
		sides=9, jag=0.3, seed=4.0, lift=1.012)
	# Trois yeux creusés autour du sommet, côté caméra.
	for th, off in ((0.3, -0.9), (0.3, 0.2), (0.48, -0.35)):
		mb.patch(sph(th, FRONT_PHI + off), _surface, 0.1, "coco_eye", rim_color="coco_dark",
			rim=0.03, sides=7, lift=1.01)


if __name__ == "__main__":
	run(sys.modules[__name__])
