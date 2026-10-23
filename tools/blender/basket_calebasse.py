"""Panier : calebasse coupée en deux, vue de face (repère Blender : Z haut,
avant = -Y ; Godot : x = x, y = z, z = -y).

RÈGLE : le modèle s'adapte à la collision M1, jamais l'inverse. Dimensions lues
dans data/game_config.tres. Aucune géométrie dans la zone jouable :
|x| < largeur/2, 0 < z < hauteur, |y| < 1 (profondeur des boîtes M1).

- bord en U épais (coupe de la gourde) + frise wax peinte sur la tranche ;
- cavité concave sombre derrière les fruits, assez profonde pour que les gros
  fruits (rayon 1,68) ne la traversent pas ;
- coque extérieure bombée (ventre de gourde), sous et autour du panier.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import game_config, run_prop  # noqa: E402

ASSET_NAME = "basket_calebasse"
MAX_TRIS = 2500

W = game_config("basket_inner_width")
H = game_config("basket_height")
T = game_config("wall_thickness")
HALF = W * 0.5
FRONT = -1.04  # tranche du bord, juste devant les boîtes (profondeur ±1)
BACK = 1.0  # fond plat des murs = arrière des boîtes M1
CAVITY = 0.95  # creux supplémentaire au centre de la cavité
BELLY = 0.55  # épaisseur du fond sous le sol jouable
BULGE = 0.38  # renflement extérieur des flancs
RIM_LIP = 0.06  # bourrelet du haut du bord
CAM = (0, -1, 0)  # la caméra regarde depuis -Y
WAX = ["wax_orange", "wax_yellow", "wax_green", "wax_red", "wax_yellow", "wax_blue"]


def _profiles(n_side=14, n_bottom=10):
	"""Profils intérieur (contre les boîtes M1) et extérieur (gourde) du U,
	parcourus de haut-gauche à haut-droite, même nombre de points."""
	inner, outer = [], []
	# Flanc gauche (haut → bas)
	for k in range(n_side + 1):
		t = k / n_side
		z = H * (1.0 - t)
		inner.append(Vector((-HALF, 0.0, z)))
		bulge = BULGE * math.sin(math.pi * min(1.0, (z + BELLY) / (H + BELLY))) ** 0.8
		outer.append(Vector((-HALF - T - bulge, 0.0, z)))
	# Fond (gauche → droite) : intérieur plat, extérieur en ventre arrondi.
	for k in range(1, n_bottom):
		t = k / n_bottom
		x = -HALF + W * t
		inner.append(Vector((x, 0.0, 0.0)))
		a = math.pi * t
		ox = -(HALF + T) * math.cos(a)
		oz = -(T + BELLY * math.sin(a) ** 0.6)
		outer.append(Vector((ox, 0.0, oz)))
	# Flanc droit (bas → haut)
	for k in range(n_side + 1):
		t = k / n_side
		z = H * t
		inner.append(Vector((HALF, 0.0, z)))
		bulge = BULGE * math.sin(math.pi * min(1.0, (z + BELLY) / (H + BELLY))) ** 0.8
		outer.append(Vector((HALF + T + bulge, 0.0, z)))
	return inner, outer


def _cavity_depth(x):
	"""Profondeur (y Blender) de la cavité : BACK contre les murs, plus creux
	au centre (paroi de gourde vue de l'intérieur)."""
	u = min(1.0, abs(x) / HALF)
	return BACK + CAVITY * math.sqrt(max(0.0, 1.0 - u * u))


def build(mb):
	inner, outer = _profiles()
	n = len(inner)

	def at(p, y):
		return mb.v((p.x, y, p.z))

	# Tranche avant du bord (U plat) + frise wax de triangles.
	fi = [at(p, FRONT) for p in inner]
	fo = [at(p, FRONT) for p in outer]
	for k in range(n - 1):
		mb.face([fi[k], fo[k], fo[k + 1], fi[k + 1]], "calabash_rim", smooth=False, facing=CAM)
	for k in range(n - 1):
		a, b = inner[k], inner[k + 1]
		c, d = outer[k], outer[k + 1]
		mid0 = (a + c) * 0.5
		mid1 = (b + d) * 0.5
		width = (c - a).length
		tip = (mid0 + mid1) * 0.5 + ((c + d) * 0.5 - (a + b) * 0.5).normalized() * width * 0.28
		base0 = mid0 + (a - mid0) * 0.55
		base1 = mid1 + (b - mid1) * 0.55
		y = FRONT - 0.012
		mb.face([mb.v((base0.x, y, base0.z)), mb.v((tip.x, y, tip.z)), mb.v((base1.x, y, base1.z))],
			WAX[k % len(WAX)], smooth=False, facing=CAM)

	# Bourrelet du haut (deux bouts du U) : ferme le bord.
	for k, kk in ((0, 0), (n - 1, n - 1)):
		a, b = inner[k], outer[kk]
		lip = Vector((0, 0, RIM_LIP))
		q = [at(a + lip, FRONT), at(b + lip, FRONT), at(b + lip, BACK + 0.3), at(a + lip, BACK)]
		mb.face(q, "calabash_rim", smooth=False, facing=(0, 0, 1))

	# Murs intérieurs (contre les boîtes) : de la tranche jusqu'au fond.
	for k in range(n - 1):
		a, b = inner[k], inner[k + 1]
		if a.z == 0.0 and b.z == 0.0:
			# Sol : de la tranche jusqu'au pied de la cavité.
			q = [at(a, FRONT), at(b, FRONT), at(b, _cavity_depth(b.x)), at(a, _cavity_depth(a.x))]
			toward = (0, 0, 1)
		else:
			q = [at(a, FRONT), at(b, FRONT), at(b, BACK), at(a, BACK)]
			toward = (-a.x, 0, 0)
		mb.face(q, "calabash_inner", smooth=False, facing=toward)

	# Cavité : grille au-dessus du sol, creuse au centre.
	nx, nz = 20, 12
	grid = []
	for j in range(nz + 1):
		z = H * j / nz
		row = []
		for i in range(nx + 1):
			x = -HALF + W * i / nx
			row.append(mb.v((x, _cavity_depth(x), z)))
		grid.append(row)
	for j in range(nz):
		for i in range(nx):
			mb.face([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]], "calabash_inner",
				facing=CAM)

	# Coque extérieure : le profil extérieur fuit vers l'arrière en se resserrant.
	steps = [(FRONT, 1.0), (0.0, 0.985), (BACK + 0.4, 0.93), (BACK + CAVITY + 0.15, 0.82)]
	rings = []
	for y, s in steps:
		rings.append([mb.v((p.x * s, y, p.z * s + (1.0 - s) * H * 0.45)) for p in outer])
	for r in range(len(rings) - 1):
		for k in range(n - 1):
			p = outer[k]
			mb.face([rings[r][k], rings[r + 1][k], rings[r + 1][k + 1], rings[r][k + 1]], "calabash",
				facing=(p.x, 0, p.z - H * 0.45))
	# Raccord tranche avant ↔ coque (même contour).
	for k in range(n - 1):
		mb.face([fo[k], rings[0][k], rings[0][k + 1], fo[k + 1]], "calabash", smooth=False, facing=CAM)


if __name__ == "__main__":
	run_prop(sys.modules[__name__])
