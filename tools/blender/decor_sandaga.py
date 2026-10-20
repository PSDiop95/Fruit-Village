"""Décor « Marché Sandaga » : 3 plans + un passant (repère Blender : Z haut,
avant -Y). Chaque plan est construit autour de y = 0 ; Godot le place en
profondeur et l'estompe (assets/shaders/decor.gdshader, data/visual.tres).

Caméra orthographique : seule la zone x ∈ [-4,2 ; 4,2] et z ∈ [-1,5 ; 14+]
est visible (plus haut sur les écrans allongés). Le panier cache le centre
jusqu'à z = 8,6 : le décor vit surtout au-dessus et sur les bords.

Un module, plusieurs assets : DECOR_ASSETS liste (nom, fonction de build).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import hash01, sph  # noqa: E402

GROUND = 8.2  # sol des étals du plan moyen (juste sous le bord du panier)
STRIPES = [("wax_red", "cloth_cream"), ("wax_green", "wax_yellow"), ("wax_blue", "cloth_cream"),
	("wax_orange", "wax_yellow")]


# ---------------------------------------------------------------- Plan lointain

def build_far(mb):
	"""Façades de la place : blocs pâles à fenêtres, toits plats, minaret."""
	x = -9.0
	k = 0
	while x < 9.0:
		w = 2.2 + 1.6 * hash01(k, 1.0)
		h = 4.0 + 3.5 * hash01(k, 2.0)
		color = ["calabash_rim", "cloth_cream", "calabash"][k % 3]
		mb.box((x + w * 0.5, 0.0, GROUND + h * 0.5 - 1.0), (w - 0.1, 1.0, h), color)
		# Fenêtres
		for r in range(int(h // 1.6)):
			for c in range(max(1, int(w // 1.1))):
				wx = x + 0.55 + c * 1.1
				wz = GROUND + 0.6 + r * 1.6
				if wx + 0.3 < x + w:
					mb.quad((wx, -0.51, wz), (wx, -0.51, wz + 0.6), (wx + 0.42, -0.51, wz + 0.6),
						(wx + 0.42, -0.51, wz), "calabash_dark")
		x += w
		k += 1
	# Minaret (repère de Dakar, silhouette lointaine)
	mb.box((5.6, -0.2, GROUND + 6.0), (0.8, 0.8, 12.0), "cloth_cream")
	mb.cylinder((5.6, -0.2, GROUND + 12.0), (5.6, -0.2, GROUND + 13.4), 0.55, 0.0, 6, "calabash_rim")


# ---------------------------------------------------------------- Plan moyen

def _awning(mb, x0, x1, z, depth, colors, n=6):
	"""Bâche rayée inclinée + feston, vue de face."""
	step = (x1 - x0) / n
	for i in range(n):
		a, b = x0 + i * step, x0 + (i + 1) * step
		c = colors[i % 2]
		mb.quad((a, -depth, z), (a, 0.0, z + 0.7), (b, 0.0, z + 0.7), (b, -depth, z), c,
			facing=(0, -1, 0.6))
		# Feston (demi-lune) sous chaque bande
		mid = (a + b) * 0.5
		mb.tri((a, -depth - 0.01, z), (mid, -depth - 0.01, z - 0.35), (b, -depth - 0.01, z), c)


def _pile(mb, cx, cz, colors, seed):
	"""Tas de fruits : demi-sphères empilées en pyramide."""
	k = 0
	for row, count in enumerate((4, 3, 2)):
		for i in range(count):
			r = 0.32
			x = cx + (i - (count - 1) * 0.5) * r * 1.9
			z = cz + r + row * r * 1.55
			col = colors[int(hash01(seed, k) * len(colors)) % len(colors)]
			mb.lat_long(6, 4, lambda th, ph, x=x, z=z, r=r: Vector((x, -0.4, z)) + sph(th, ph) * r,
				lambda th, ph, j, ii, col=col: col)
			k += 1


def build_mid(mb):
	"""Rangée d'étals : tables, bâches rayées, tas de fruits, calebasses."""
	fruit_colors = ["madd", "mangue", "goyave", "papaye", "ditakh", "sidem"]
	for s, cx in enumerate((-6.6, -2.2, 2.2, 6.6)):
		w = 3.8
		# Table + pieds
		mb.box((cx, 0.0, GROUND + 0.9), (w, 1.2, 0.18), "wood", {"front": "wood_light"})
		for dx in (-w * 0.45, w * 0.45):
			mb.box((cx + dx, -0.4, GROUND + 0.4), (0.12, 0.12, 0.9), "wood_dark")
		# Poteaux + bâche
		for dx in (-w * 0.5, w * 0.5):
			mb.box((cx + dx, -0.9, GROUND + 1.9), (0.1, 0.1, 3.2), "wood_dark")
		_awning(mb, cx - w * 0.55, cx + w * 0.55, GROUND + 3.2, 1.2, STRIPES[s % len(STRIPES)])
		# Marchandise
		_pile(mb, cx - 0.8, GROUND + 1.0, fruit_colors, s)
		_pile(mb, cx + 0.9, GROUND + 1.0, fruit_colors[::-1], s + 7)
	# Piles de calebasses au sol entre les étals
	for cx in (-4.4, 0.0, 4.4):
		for i, (dx, dz, r) in enumerate(((-0.5, 0.0, 0.45), (0.45, 0.0, 0.4), (0.0, 0.62, 0.38))):
			mb.lat_long(8, 3, lambda th, ph, cx=cx, dx=dx, dz=dz, r=r: Vector(
				(cx + dx, -0.8, GROUND + dz + max(0.0, math.cos(th)) * r)) + Vector(
				(math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), 0.0)) * r,
				lambda th, ph, j, ii: "calabash")


# ---------------------------------------------------------------- Plan proche

def build_near(mb):
	"""Lambrequin festonné en haut de l'écran (cadre l'étal du joueur)."""
	z = 13.4
	n = 14
	x0, x1 = -7.0, 7.0
	step = (x1 - x0) / n
	for i in range(n):
		a, b = x0 + i * step, x0 + (i + 1) * step
		c = STRIPES[0][i % 2] if i % 4 < 2 else STRIPES[3][i % 2]
		mb.quad((a, 0.0, z), (a, 0.0, z + 2.5), (b, 0.0, z + 2.5), (b, 0.0, z), c)
		mid = (a + b) * 0.5
		for t in range(4):  # feston arrondi
			a0 = math.pi * t / 4
			a1 = math.pi * (t + 1) / 4
			mb.tri((mid, -0.01, z), (mid - math.cos(a0) * step * 0.5, -0.01, z - math.sin(a0) * 0.42),
				(mid - math.cos(a1) * step * 0.5, -0.01, z - math.sin(a1) * 0.42), c)
	# Galon bleu nuit
	mb.quad((x0, -0.02, z + 0.12), (x0, -0.02, z + 0.24), (x1, -0.02, z + 0.24), (x1, -0.02, z + 0.12),
		"wax_blue")


# ---------------------------------------------------------------- Passant

def build_passant(mb):
	"""Silhouette de passante (boubou + foulard), pieds en z = 0, de face."""
	# Boubou : cône évasé
	mb.lat_long(10, 6, lambda th, ph: Vector((
		math.sin(th) * math.cos(ph) * (0.55 - 0.3 * math.cos(th) * 0.5),
		math.sin(th) * math.sin(ph) * 0.35,
		1.0 - math.cos(th) * 1.0)), lambda th, ph, j, i: "wax_green" if j % 2 else "wax_yellow")
	# Tête + foulard (gele)
	mb.lat_long(8, 6, lambda th, ph: Vector((0, 0, 2.25)) + sph(th, ph) * 0.26,
		lambda th, ph, j, i: "stem_dark")
	mb.lat_long(8, 5, lambda th, ph: Vector((0.04, 0.02, 2.48)) + Vector((
		math.sin(th) * math.cos(ph) * 0.36, math.sin(th) * math.sin(ph) * 0.3, math.cos(th) * 0.22)),
		lambda th, ph, j, i: "wax_red")
	# Panier sur la tête (bassine)
	mb.cylinder((0.0, 0.0, 2.66), (0.0, 0.0, 2.86), 0.42, 0.5, 8, "calabash", cap_color="madd")


DECOR_ASSETS = [
	("decor_far", build_far, 3000),
	("decor_mid", build_mid, 6000),
	("decor_near", build_near, 600),
	("decor_passant", build_passant, 600),
]
