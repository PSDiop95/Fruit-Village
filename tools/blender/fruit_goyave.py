"""Goyave : jaune-vert, ronde un peu en poire, joue rosée à droite, couronne
sèche brune pointée vers le bas. Référence : docs/refs/fruits/06_goyave.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, smoothstep, run  # noqa: E402

FRUIT_ID = "goyave"
FACE = {"height": 0.02, "size": 0.95}
# Joue rosée : côté droit du fruit, à mi-hauteur.
BLUSH = Vector((0.85, -0.45, 0.05)).normalized()


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		w = 1.0 - 0.1 * d.z  # plus large en bas (poire douce)
		return Vector((d.x * w * 0.95, d.y * w * 0.95, d.z * 0.88))

	def blush(th, ph):
		return smoothstep(0.45, 0.95, sph(th, ph).dot(BLUSH))

	def col(th, ph, j, i):
		if th > math.pi * 0.93:  # calotte basse (indépendant de la finesse)
			return "crown_dry"
		return ("ramp_goyave", blush)

	mb.lat_long(24, 14, pos, col)
	# Couronne sèche : 6 sépales pointés vers le bas, visibles en silhouette.
	for k in range(6):
		a = 2 * math.pi * k / 6 + 0.25
		ca, sa = math.cos(a), math.sin(a)
		base = Vector((0.1 * ca, 0.1 * sa, -0.84))
		tip = Vector((0.22 * ca, 0.22 * sa, -0.99))
		mb.blade(base, tip, 0.1, 0.04, (ca, sa, 0.4), None, color="crown_dry")
	mb.cylinder((0, 0, 0.82), (0, 0, 0.9), 0.05, 0.04, 5, "crown_dry")


if __name__ == "__main__":
	run(sys.modules[__name__])
