"""Décor 3D « village au bord de la baie » (repère Blender : Z haut, avant -Y).
Chaque plan est construit autour de y = 0 ; Godot le place en profondeur et
l'estompe légèrement (assets/shaders/decor.gdshader, data/visual.tres).

Caméra orthographique : zone visible x ∈ [-4,2 ; 4,2], z ∈ [-1,5 ; 14+]. Le
panier cache le centre jusqu'à z ≈ 8,7 : le décor vit au-dessus et sur les
bords. Style : lumineux, saturé, propre (référence art_src/background_marche_baie.png).

DECOR_ASSETS liste (nom, fonction de build, budget de triangles).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import hash01, sph  # noqa: E402

GROUND = 8.3  # sol du village (juste sous le bord du panier)
HORIZON = 9.5


# ---------------------------------------------------------------- Outils

def _blob(mb, center, radii, color, seg=10, rings=6):
	"""Ellipsoïde fermé (nuages, feuillages, fruits, têtes)."""
	c = Vector(center)
	mb.lat_long(seg, rings, lambda th, ph: c + Vector((
		math.sin(th) * math.cos(ph) * radii[0], math.sin(th) * math.sin(ph) * radii[1],
		math.cos(th) * radii[2])), lambda th, ph, j, i: color)


def _palm(mb, base, height, lean, fronds=7, seed=0.0):
	"""Palmier : tronc courbe en anneaux + couronne de palmes tombantes."""
	b = Vector(base)
	pts = []
	n = 6
	for k in range(n + 1):
		t = k / n
		pts.append(b + Vector((lean * t * t, 0.0, height * t)))
	for k in range(n):
		r0 = 0.16 - 0.06 * k / n
		mb.cylinder(pts[k], pts[k + 1], r0, r0 * 0.88, 6, "palm_trunk" if k % 2 else "straw_dark", smooth=True)
	top = pts[-1]
	_blob(mb, top + Vector((0, 0, 0.05)), (0.22, 0.22, 0.18), "palm_trunk", 8, 5)
	for f in range(fronds):
		a = 2 * math.pi * f / fronds + seed
		ca, sa = math.cos(a), math.sin(a)
		length = 1.7 + 0.4 * hash01(f, seed)
		mid = top + Vector((ca * length * 0.55, sa * length * 0.35, 0.45))
		tip = top + Vector((ca * length, sa * length * 0.6, -0.35 - 0.3 * hash01(f, seed + 1)))
		normal = Vector((-sa * 0.3, ca * 0.3, 1.0))
		mb.blade(top, mid, 0.55, 0.06, normal, "ramp_crown", 0.25, 0.75)
		mb.blade(mid - (mid - top) * 0.1, tip, 0.5, 0.05, normal, "ramp_crown", 0.6, 1.0)


def _hut(mb, cx, width, depth, wall_h, flip=1.0):
	"""Paillote : murs ocre, porte et fenêtre bleues, grand toit de paille."""
	z0 = GROUND
	mb.box((cx, 0.0, z0 + wall_h * 0.5), (width, depth, wall_h), "wall_ochre", {"front": "wall_ochre"})
	# Porte + fenêtre (face caméra)
	dx = -flip * width * 0.18
	mb.quad((cx + dx - 0.32, -depth * 0.5 - 0.01, z0), (cx + dx - 0.32, -depth * 0.5 - 0.01, z0 + 1.35),
		(cx + dx + 0.32, -depth * 0.5 - 0.01, z0 + 1.35), (cx + dx + 0.32, -depth * 0.5 - 0.01, z0), "door_blue")
	wx = cx + flip * width * 0.22
	mb.quad((wx - 0.3, -depth * 0.5 - 0.01, z0 + 0.9), (wx - 0.3, -depth * 0.5 - 0.01, z0 + 1.45),
		(wx + 0.3, -depth * 0.5 - 0.01, z0 + 1.45), (wx + 0.3, -depth * 0.5 - 0.01, z0 + 0.9), "door_blue")
	mb.quad((wx - 0.36, -depth * 0.5 - 0.015, z0 + 0.84), (wx - 0.36, -depth * 0.5 - 0.015, z0 + 0.9),
		(wx + 0.36, -depth * 0.5 - 0.015, z0 + 0.9), (wx + 0.36, -depth * 0.5 - 0.015, z0 + 0.84), "wood_dark")
	# Toit de paille à deux pans, débord épais, frange dentelée
	over = 0.45
	zr = z0 + wall_h
	peak = zr + width * 0.42
	hw = width * 0.5 + over
	hd = depth * 0.5 + over
	front, back = -hd, hd
	mb.quad((cx - hw, front, zr - 0.15), (cx, front, peak), (cx, back, peak), (cx - hw, back, zr - 0.15), "straw",
		facing=(-1, 0, 1))
	mb.quad((cx + hw, front, zr - 0.15), (cx + hw, back, zr - 0.15), (cx, back, peak), (cx, front, peak), "straw",
		facing=(1, 0, 1))
	mb.tri((cx - hw, front, zr - 0.15), (cx + hw, front, zr - 0.15), (cx, front, peak), "straw_dark")
	n = 9
	for k in range(n):
		a = cx - hw + 2 * hw * k / n
		b = cx - hw + 2 * hw * (k + 1) / n
		mb.tri((a, front - 0.02, zr - 0.15), ((a + b) * 0.5, front - 0.02, zr - 0.42), (b, front - 0.02, zr - 0.15),
			"straw_dark")


def _fruit_pile(mb, cx, cz, y, colors, seed, rows=(4, 3, 2), r=0.26):
	k = 0
	for row, count in enumerate(rows):
		for i in range(count):
			x = cx + (i - (count - 1) * 0.5) * r * 1.9
			z = cz + r + row * r * 1.5
			col = colors[int(hash01(seed, k) * len(colors)) % len(colors)]
			_blob(mb, (x, y, z), (r, r, r * 0.95), col, 8, 5)
			k += 1


# ---------------------------------------------------------------- Plan lointain

def build_far(mb):
	"""Ciel en dégradé, nuages, collines, lagune et voilier."""
	# Ciel (dégradé vertical ramp_sky : haut bleu profond → horizon clair)
	top, bottom = 26.0, HORIZON - 1.0
	t_of = lambda z: min(1.0, max(0.0, (top - z) / (top - HORIZON)))
	mb.face([mb.v((-12, 0.6, bottom)), mb.v((12, 0.6, bottom)), mb.v((12, 0.6, top)), mb.v((-12, 0.6, top))],
		uvs=[__import__("palette_def").ramp_uv("ramp_sky", t_of(z)) for z in (bottom, bottom, top, top)],
		smooth=False, facing=(0, -1, 0))
	# Collines lointaines + proches
	for k, (cx, w, h, col) in enumerate(((-6.5, 5.0, 1.5, "hill_far"), (-1.0, 4.0, 1.0, "hill_far"),
			(4.5, 6.0, 1.7, "hill_far"), (-4.0, 3.4, 0.9, "hill"), (5.8, 3.0, 1.0, "hill"))):
		_blob(mb, (cx, 0.2 - k * 0.02, HORIZON), (w * 0.5, 0.3, h), col, 12, 6)
	# Lagune : bande de mer + reflets
	mb.quad((-12, -0.3, GROUND - 1.0), (-12, -0.3, HORIZON + 0.05), (12, -0.3, HORIZON + 0.05),
		(12, -0.3, GROUND - 1.0), "sea")
	for k in range(9):
		x = -6.0 + 1.5 * k + hash01(k, 3.0)
		z = HORIZON - 0.25 - 0.35 * hash01(k, 4.0)
		mb.quad((x, -0.32, z), (x, -0.32, z + 0.05), (x + 0.6, -0.32, z + 0.05), (x + 0.6, -0.32, z), "sea_light")
	# Voilier
	mb.box((1.6, -0.35, HORIZON - 0.05), (0.55, 0.1, 0.12), "wood_dark")
	mb.tri((1.45, -0.36, HORIZON + 0.02), (1.62, -0.36, HORIZON + 0.75), (1.75, -0.36, HORIZON + 0.02), "cloud")
	# Nuages (grappes de boules aplaties)
	for c, (cx, cz, s) in enumerate(((-3.2, 12.3, 1.0), (2.6, 13.4, 1.25), (5.5, 11.6, 0.8), (-6.0, 14.2, 1.1))):
		for b in range(5):
			ox = (b - 2) * 0.55 * s
			oz = (0.25 if b in (1, 2, 3) else 0.0) * s + 0.1 * hash01(c, b)
			_blob(mb, (cx + ox, -0.5, cz + oz), (0.6 * s, 0.25, 0.42 * s), "cloud", 10, 5)


# ---------------------------------------------------------------- Plan moyen

def build_mid(mb):
	"""Paillotes, étal de fruits sous paille, palmiers, sol sableux."""
	# Sol sableux + herbe
	mb.quad((-12, -2.5, -6.0), (-12, -2.5, GROUND), (12, -2.5, GROUND), (12, -2.5, -6.0), "sand")
	mb.quad((-12, -2.4, GROUND), (-12, 1.5, GROUND), (12, 1.5, GROUND), (12, -2.4, GROUND), "sand", facing=(0, 0, 1))
	for k in range(14):
		x = -7 + k + 0.6 * hash01(k, 8.0)
		_blob(mb, (x, -2.0, GROUND + 0.05), (0.45, 0.3, 0.28), "palm_leaf" if k % 2 else "hill", 8, 4)
	# Paillotes à gauche et à droite (bords visibles autour du panier)
	_hut(mb, -5.6, 3.2, 2.2, 2.0, 1.0)
	_hut(mb, 5.7, 3.4, 2.2, 2.1, -1.0)
	# Étal sous paille à gauche, chargé de fruits
	sx = -3.4
	mb.box((sx, -1.2, GROUND + 0.75), (2.4, 0.9, 0.16), "wood", {"front": "wood_light"})
	mb.box((sx, -1.65, GROUND + 0.4), (2.4, 0.06, 0.7), "wood_light")
	for dx in (-1.15, 1.15):
		mb.box((sx + dx, -1.55, GROUND + 1.4), (0.12, 0.12, 2.8), "wood_dark")
	mb.quad((sx - 1.5, -2.0, GROUND + 2.55), (sx - 1.5, -0.5, GROUND + 3.2), (sx + 1.5, -0.5, GROUND + 3.2),
		(sx + 1.5, -2.0, GROUND + 2.55), "straw", facing=(0, -1, 0.7))
	for k in range(8):
		a = sx - 1.5 + 3.0 * k / 8
		b = sx - 1.5 + 3.0 * (k + 1) / 8
		mb.tri((a, -2.02, GROUND + 2.55), ((a + b) * 0.5, -2.02, GROUND + 2.3), (b, -2.02, GROUND + 2.55), "straw_dark")
	fruit = ["madd", "mangue", "goyave", "papaye", "ditakh", "sidem", "ananas"]
	_fruit_pile(mb, sx - 0.55, GROUND + 0.83, -1.25, fruit, 1)
	_fruit_pile(mb, sx + 0.6, GROUND + 0.83, -1.25, fruit[::-1], 2)
	# Paniers de fruits au sol, côté droit
	for k, cx in enumerate((3.3, 4.2)):
		mb.cylinder((cx, -1.6, GROUND), (cx, -1.6, GROUND + 0.5), 0.42, 0.48, 10, "wood", cap_color="wood_dark")
		_fruit_pile(mb, cx, GROUND + 0.4, -1.6, ["madd", "goyave", "sidem"], 5 + k, rows=(2, 1), r=0.2)
	# Palmiers
	_palm(mb, (-4.6, 0.6, GROUND), 5.2, 0.9, 8, 0.3)
	_palm(mb, (4.3, 0.4, GROUND), 4.6, -0.8, 7, 1.1)
	_palm(mb, (1.2, 1.2, GROUND), 3.8, 0.5, 7, 2.2)


# ---------------------------------------------------------------- Plan proche

def build_near(mb):
	"""Palmes qui encadrent le haut de l'écran (coins gauche et droit)."""
	for side in (-1.0, 1.0):
		root = Vector((side * 5.2, 0.0, 15.2))
		for k in range(5):
			a = math.radians(200 + 18 * k) if side < 0 else math.radians(-20 - 18 * k)
			d = Vector((math.cos(a) * side * -1.0 if side < 0 else math.cos(a), 0.0, math.sin(a)))
			length = 2.6 + 0.5 * hash01(k, side)
			tip = root + Vector((-side * abs(d.x) * length, -0.05 * k, -abs(d.z) * length * 0.9 - 0.3))
			mid = root + (tip - root) * 0.5 + Vector((0, 0, 0.35))
			mb.blade(root, mid, 0.7, 0.06, (0, -1, 0.2), "ramp_crown", 0.2, 0.7)
			mb.blade(mid, tip, 0.6, 0.05, (0, -1, 0.2), "ramp_crown", 0.6, 1.0)


DECOR_ASSETS = [
	("decor_far", build_far, 4000),
	("decor_mid", build_mid, 12000),
	("decor_near", build_near, 600),
]
