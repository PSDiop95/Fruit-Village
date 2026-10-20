"""Madd (saba) : boule orange vif un peu bosselée, petit pédoncule brun. Référence : docs/refs/fruits/05_madd.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, hash01, smoothstep, run, FRONT_PHI  # noqa: E402

FRUIT_ID = "madd"
FACE = {"height": -0.02, "size": 1.0}
SPECKS = 14


def _surface(d):
	dimple = 1.0 - 0.05 * smoothstep(0.88, 1.0, d.z)
	lump = 0.03 * math.sin(3.0 * d.x + 1.3) * math.sin(4.0 * d.z + 0.4) * math.cos(2.0 * d.y)
	return Vector((d.x, d.y, d.z * 0.97)) * (dimple + lump)


def build(mb):
	def col(th, ph, j, i):
		return "madd"

	mb.lat_long(24, 14, lambda th, ph: _surface(sph(th, ph)), col)
	mb.cylinder((0, 0, 0.88), (0.02, 0, 1.02), 0.06, 0.045, 6, "stem_brown")


if __name__ == "__main__":
	run(sys.modules[__name__])
