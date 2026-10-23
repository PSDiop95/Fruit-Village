"""Ananas : corps ovale à écailles en losanges (centre jaune, bord orangé),
couronne de feuilles pointues en éventail, tenue dans le rayon de collision.
Référence : docs/refs/fruits/09_ananas.jpg"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import run  # noqa: E402

FRUIT_ID = "ananas"
FACE = {"height": -0.34, "size": 0.72}
S = 16  # losanges par tour
R = 13  # anneaux
Z0, RX, RZ = -0.31, 0.8, 0.69  # corps : bas à -1, haut à 0,38
BUMP = 1.06
# Couronne : (nombre, élévation en degrés, largeur, décalage azimut)
LAYERS = [(9, 30, 0.22, 0.0), (7, 52, 0.2, 0.3), (5, 74, 0.16, 0.7)]


def _body(th, ph):
	return Vector((RX * math.sin(th) * math.cos(ph), RX * math.sin(th) * math.sin(ph), Z0 + RZ * math.cos(th)))


def build(mb):
	center = Vector((0, 0, Z0))
	top = mb.v(_body(0, 0))
	bot = mb.v(_body(math.pi, 0))
	ring = {}
	for j in range(1, R):
		th = math.pi * j / R
		ring[j] = [mb.v(_body(th, 2 * math.pi * (i + 0.5 * (j % 2)) / S)) for i in range(S)]
	# Losanges centrés sur l'anneau j : gauche/droite sur j, haut/bas sur j∓1.
	for j in range(1, R):
		for i in range(S):
			ii = i if j % 2 == 0 else (i + 1) % S
			left, right = ring[j][i], ring[j][(i + 1) % S]
			up = top if j == 1 else ring[j - 1][ii]
			down = bot if j == R - 1 else ring[j + 1][ii]
			quad = [left, down, right, up]
			c = sum((mb.verts[k] for k in quad), Vector()) / 4.0
			ci = mb.v(center + (c - center) * BUMP)  # écaille bombée (poke)
			for a in range(4):
				p, q = quad[a], quad[(a + 1) % 4]
				mb.ramp_face([p, q, ci], "ramp_ananas", [0.05, 0.05, 1.0], smooth=False)
	# Couronne en éventail : pointes ramenées à 0,97 du centre (dans la sphère).
	base_c = Vector((0, 0, Z0 + RZ - 0.04))
	for count, elev, width, off in LAYERS:
		e = math.radians(elev)
		for k in range(count):
			a = 2 * math.pi * (k + off) / count
			dirv = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
			base = base_c + Vector((math.cos(a), math.sin(a), 0)) * 0.1
			length = 1.0
			while (base + dirv * length).length > 0.97:
				length -= 0.01
			tip = base + dirv * length
			mb.blade(base, tip, width, 0.05, (math.cos(a), math.sin(a), -0.6), "ramp_crown", 0.0, 0.85)


if __name__ == "__main__":
	run(sys.modules[__name__])
