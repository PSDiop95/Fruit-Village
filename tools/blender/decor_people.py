"""Passants du marché : femmes et hommes stylisés, articulés pour la marche.
Repère Blender : Z haut, le personnage regarde -Y (Godot : +Z) ; pieds en z = 0.
Pièces : body (fixe) + arm_l, arm_r, leg_l, leg_r (pivot épaule / hanche),
animées dans Godot (MarketScene). Échelle : ~2,3 m (proportions du décor).

PEOPLE : (nom, pièces) -> assets/models/<nom>.glb
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402

SKIN = "skin"


def _blob(mb, center, radii, color, seg=10, rings=6):
	c = Vector(center)
	mb.lat_long(seg, rings, lambda th, ph: c + Vector((
		math.sin(th) * math.cos(ph) * radii[0], math.sin(th) * math.sin(ph) * radii[1],
		math.cos(th) * radii[2])), lambda th, ph, j, i: color)


def _frustum(mb, z0, z1, r0, r1, color, sides=12, cx=0.0, cy=0.0, cap=True):
	"""Tronc de cône elliptique fermé : r0 = (rx, ry) en bas, r1 en haut."""
	bot, top = [], []
	for k in range(sides):
		a = 2 * math.pi * k / sides
		bot.append(mb.v((cx + math.cos(a) * r0[0], cy + math.sin(a) * r0[1], z0)))
		top.append(mb.v((cx + math.cos(a) * r1[0], cy + math.sin(a) * r1[1], z1)))
	for k in range(sides):
		k2 = (k + 1) % sides
		mb.face([bot[k], bot[k2], top[k2], top[k]], color)
	if cap:
		mb.face(list(reversed(top)), color, smooth=False)
		mb.face(list(bot), color, smooth=False)


def _head(mb, z, skin=SKIN):
	"""Cou + tête + traits du visage (yeux, nez, oreilles) : lisible de loin."""
	mb.cylinder((0, 0, z - 0.2), (0, 0, z - 0.06), 0.06, 0.055, 8, skin, smooth=True)
	_blob(mb, (0, 0, z + 0.06), (0.15, 0.155, 0.18), skin, 12, 8)
	for sx in (-1, 1):
		_blob(mb, (sx * 0.055, -0.135, z + 0.09), (0.022, 0.012, 0.026), "hair", 6, 4)  # yeux
		_blob(mb, (sx * 0.148, 0.0, z + 0.05), (0.025, 0.04, 0.05), skin, 6, 4)  # oreilles
	_blob(mb, (0, -0.155, z + 0.03), (0.03, 0.03, 0.035), "skin_dark", 6, 4)  # nez
	_blob(mb, (0, -0.135, z - 0.035), (0.045, 0.01, 0.012), "skin_dark", 6, 3)  # bouche


def _foot(mb, x, color="hair"):
	mb.box((x, -0.06, 0.035), (0.1, 0.24, 0.07), color)


# ---------------------------------------------------------------- Femme

def _woman(pagne, top, wrap, band, basin=False):
	def body(mb):
		_frustum(mb, 0.12, 1.12, (0.29, 0.22), (0.2, 0.15), pagne)  # pagne long
		for z, r in ((0.32, 0.268), (0.72, 0.24)):  # bandes du wax
			_frustum(mb, z, z + 0.07, (r, r * 0.76), (r - 0.006, r * 0.76 - 0.004), band, cap=False)
		_blob(mb, (0, 0, 1.42), (0.22, 0.15, 0.33), top)  # buste (blouse ample)
		_frustum(mb, 1.08, 1.18, (0.21, 0.155), (0.21, 0.155), band, cap=False)  # ceinture
		_head(mb, 1.92)
		# Moussor (foulard noué) : volume arrière + nœud au sommet
		_blob(mb, (0, 0.04, 2.08), (0.19, 0.19, 0.15), wrap, 12, 7)
		_blob(mb, (0.05, 0.02, 2.22), (0.1, 0.08, 0.09), wrap, 8, 5)
		if basin:
			mb.cylinder((0, 0, 2.27), (0, 0, 2.44), 0.3, 0.38, 12, "terracotta", smooth=True, cap_color="calabash_dark")
			for k, (dx, dy, col) in enumerate(((-0.12, -0.05, "madd"), (0.1, -0.03, "mangue"),
					(0.0, 0.1, "goyave"), (-0.02, -0.08, "madd"), (0.15, 0.1, "ditakh"))):
				_blob(mb, (dx, dy, 2.47 + 0.04 * (k % 2)), (0.1, 0.1, 0.1), col, 8, 5)

	def arm(side, raised):
		def build(mb):
			sx = 0.22 * side
			if raised:
				# Bras levé qui tient la bassine
				mb.cylinder((sx, 0, 1.6), (sx + 0.08 * side, 0, 1.9), 0.075, 0.06, 8, top, smooth=True)
				mb.cylinder((sx + 0.08 * side, 0, 1.9), (sx + 0.1 * side, 0, 2.22), 0.05, 0.045, 8, SKIN, smooth=True)
				_blob(mb, (sx + 0.1 * side, 0, 2.27), (0.055, 0.05, 0.06), SKIN, 8, 5)
			else:
				mb.cylinder((sx, 0, 1.6), (sx + 0.05 * side, 0, 1.25), 0.08, 0.1, 8, top, smooth=True)  # manche
				mb.cylinder((sx + 0.05 * side, 0, 1.25), (sx + 0.06 * side, 0, 0.98), 0.048, 0.042, 8, SKIN, smooth=True)
				_blob(mb, (sx + 0.06 * side, 0, 0.93), (0.05, 0.045, 0.065), SKIN, 8, 5)
		return build, (0.22 * side, 0.0, 1.6)

	def leg(side):
		def build(mb):
			x = 0.09 * side
			mb.cylinder((x, 0, 1.0), (x, 0, 0.08), 0.07, 0.045, 8, SKIN, smooth=True)
			_foot(mb, x, "wood_dark")
		return build, (0.09 * side, 0.0, 1.0)

	parts = {"body": (body, (0, 0, 0))}
	parts["arm_l"] = arm(-1, False)
	parts["arm_r"] = arm(1, basin)
	parts["leg_l"] = leg(-1)
	parts["leg_r"] = leg(1)
	return parts


# ---------------------------------------------------------------- Homme

def _man(robe, trim, trousers, cap):
	def body(mb):
		# Grand boubou : large robe trapézoïdale des épaules aux genoux
		_frustum(mb, 0.55, 1.66, (0.44, 0.2), (0.26, 0.15), robe, 14)
		_blob(mb, (0, 0, 1.6), (0.27, 0.16, 0.12), robe, 10, 5)  # épaules arrondies
		# Broderie : plastron + ourlet
		mb.quad((-0.1, -0.205, 1.08), (-0.1, -0.16, 1.62), (0.1, -0.16, 1.62), (0.1, -0.205, 1.08), trim,
			facing=(0, -1, 0))
		_frustum(mb, 0.55, 0.63, (0.445, 0.205), (0.43, 0.2), trim, 14, cap=False)
		_head(mb, 1.9)
		# Kufi (calotte)
		mb.cylinder((0, 0.01, 2.04), (0, 0.01, 2.17), 0.158, 0.15, 12, cap, smooth=True)
		_blob(mb, (0, -0.1, 1.85), (0.09, 0.05, 0.05), "hair", 8, 4)  # barbe courte

	def arm(side):
		def build(mb):
			sx = 0.27 * side
			# Manche large du boubou + main
			mb.cylinder((sx, 0, 1.58), (sx + 0.1 * side, 0, 1.0), 0.09, 0.17, 8, robe, smooth=True)
			_blob(mb, (sx + 0.1 * side, 0, 0.94), (0.055, 0.05, 0.07), SKIN, 8, 5)
		return build, (0.27 * side, 0.0, 1.58)

	def leg(side):
		def build(mb):
			x = 0.1 * side
			mb.cylinder((x, 0, 1.0), (x, 0, 0.1), 0.085, 0.07, 8, trousers, smooth=True)
			mb.cylinder((x, 0, 0.12), (x, 0, 0.06), 0.045, 0.045, 6, SKIN, smooth=True)
			_foot(mb, x)
		return build, (0.1 * side, 0.0, 1.0)

	return {"body": (body, (0, 0, 0)), "arm_l": arm(-1), "arm_r": arm(1), "leg_l": leg(-1), "leg_r": leg(1)}


PEOPLE = [
	("decor_femme_bassine", _woman("fuchsia", "fuchsia", "turquoise", "gold", basin=True)),
	("decor_femme", _woman("wax_orange", "wax_yellow", "wax_green", "wax_blue")),
	("decor_homme_blanc", _man("boubou_white", "gold", "boubou_white", "indigo")),
	("decor_homme_indigo", _man("indigo", "gold", "indigo_light", "boubou_white")),
]
