"""Ditakh : boule vert lime, peau mouchetée (grain du shader), petit pédoncule.
Références : docs/refs/fruits/04_ditakh.jpg, docs/refs/fruits/00_planche_qualite.webp"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, hash01, smoothstep, run  # noqa: E402

FRUIT_ID = "ditakh"
FACE = {"height": -0.02, "size": 0.95}


def _surface(d):
	dimple = 1.0 - 0.05 * smoothstep(0.85, 1.0, d.z)
	return Vector((d.x, d.y, d.z * 0.97)) * dimple


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		g = 0.0 if th in (0.0, math.pi) else (hash01(th, ph) - 0.5) * 0.02
		return _surface(d) * (1.0 + g)

	def col(th, ph, j, i):
		return "ditakh"

	mb.lat_long(24, 14, pos, col)
	mb.cylinder((0, 0, 0.9), (0.02, 0, 1.04), 0.07, 0.055, 6, "stem_brown")


if __name__ == "__main__":
	run(sys.modules[__name__])
