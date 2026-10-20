"""Papaye : ovale en poire (large en bas), 5 côtes, dégradé orange (bas) → vert
(haut), sillons verdâtres, pédoncule vert étoilé. Référence : docs/refs/fruits/08_papaye.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, smoothstep, run, FRONT_PHI  # noqa: E402

FRUIT_ID = "papaye"
FACE = {"height": -0.12, "size": 0.85}
RIBS = 5


def _rib(ph):
	return math.cos(RIBS * (ph - FRONT_PHI))  # une côte pleine face caméra


def build(mb):
	def pos(th, ph):
		d = sph(th, ph)
		w = 0.84 * (1.0 - 0.14 * d.z) * (1.0 + 0.09 * _rib(ph) * math.sin(th) ** 0.7)
		return Vector((d.x * w, d.y * w, d.z * 0.97))

	def tone(th, ph):
		d = sph(th, ph)
		t = smoothstep(0.1, 1.0, d.z) * 0.9
		if _rib(ph) < -0.5:
			t += 0.12  # sillons plus sombres
		return t

	mb.lat_long(RIBS * 5, 14, pos, lambda th, ph, j, i: ("ramp_papaye", tone))
	mb.cylinder((0, 0, 0.88), (0.0, 0, 1.0), 0.13, 0.1, 5, "leaf_dark")


if __name__ == "__main__":
	run(sys.modules[__name__])
