"""Définition de la palette unique du jeu (assets/textures/palette.png, 256x256).

Pur Python (aucune dépendance) : importé par Blender (UV des modèles) ET par
make_palette.py (génération du PNG + palette.json lu par Godot).

Grille 16x16 cases de 16 px. Lignes 0..9 : couleurs unies (une case = une
couleur). Lignes 10..15 : dégradés horizontaux continus sur 256 px (UV.u = t).

Canal alpha = « matière » lue par toon.gdshader (pas de transparence) :
  gloss 0.0 = velours (rim large et doux, pas de reflet)
  gloss 0.5 = mat
  gloss 1.0 = brillant (reflet spéculaire dur)
  alpha = 0.25 + 0.75 * gloss  (jamais 0 : l'import ne touche pas au RGB)

RÈGLE : ajout en fin de liste uniquement (les index/UV existants ne bougent pas).
"""

SIZE = 256
GRID = 16
CELL = SIZE // GRID
RAMP_FIRST_ROW = 10

MATTE = 0.5
SATIN = 0.75
GLOSSY = 1.0
VELVET = 0.0

# (nom, couleur hex, gloss) — ordre = index de case (ligne par ligne).
COLORS = [
	# --- Fruits ------------------------------------------------------------
	("sidem", "a83a1c", GLOSSY),
	("sidem_light", "c8552c", GLOSSY),
	("stem_brown", "8b5a2b", MATTE),
	("stem_dark", "5a3a1e", MATTE),
	("bissap", "a8183a", SATIN),
	("bissap_dark", "7a0e28", SATIN),
	("bissap_light", "c8304e", SATIN),
	("tamarin", "9a6438", MATTE),
	("tamarin_dark", "6e4426", MATTE),
	("tamarin_light", "b88252", MATTE),
	("ditakh", "7fb23e", MATTE),
	("ditakh_dark", "5e8f2a", MATTE),
	("ditakh_light", "77854a", MATTE),
	("madd", "f28a1c", SATIN),
	("madd_dark", "c27f24", SATIN),
	("madd_light", "f5c25a", SATIN),
	("goyave", "a8d058", SATIN),
	("goyave_dark", "93ad48", SATIN),
	("goyave_blush", "e8907a", SATIN),
	("crown_dry", "6b4a2a", MATTE),
	("mangue", "f5b81c", SATIN),
	("leaf", "4e8a3a", SATIN),
	("leaf_dark", "35662a", SATIN),
	("papaye", "ff6a1a", SATIN),
	("papaye_dark", "d9500c", SATIN),
	("papaye_flesh", "ff9a4a", SATIN),
	("seed_black", "1c1410", GLOSSY),
	("papaye_green", "8fae3a", SATIN),
	("ananas", "e8a030", SATIN),
	("ananas_edge", "b0681c", MATTE),
	("crown", "5a8a3a", SATIN),
	("crown_dark", "3f6a2c", SATIN),
	("coco", "8a5432", MATTE),
	("coco_dark", "6b4026", MATTE),
	("coco_eye", "4a2c1a", MATTE),
	("coco_flesh", "f6f0e2", SATIN),
	("pds", "9a9a3c", VELVET),
	("pds_light", "c8c25a", VELVET),
	("pds_dark", "8a8530", VELVET),
	("white", "ffffff", MATTE),
	("black", "141010", MATTE),
	# --- Décor / UI (palette wax) -----------------------------------------
	("wax_orange", "f28c28", MATTE),
	("wax_yellow", "f9c22e", MATTE),
	("wax_green", "2e8b57", MATTE),
	("wax_blue", "1f2a5a", MATTE),
	("wax_red", "d6382f", MATTE),
	("calabash", "d9a35b", SATIN),
	("calabash_dark", "a8743a", SATIN),
	("calabash_inner", "9a6236", MATTE),
	("calabash_rim", "e8c07a", SATIN),
	("wood", "8b5a2b", MATTE),
	("wood_dark", "5e3a1a", MATTE),
	("wood_light", "b07c45", MATTE),
	("rope_red", "c8282a", MATTE),
	("cloth_cream", "f2e2bf", MATTE),
	("outline", "3a2414", MATTE),
	# --- Ajouts M3 (références Gemini) --------------------------------------
	("ditakh_flesh", "86c043", MATTE),
	("madd_speck", "a8661e", MATTE),
	("coco_light", "b07a4c", MATTE),
	("wood_stem", "b8875a", MATTE),
]

# Dégradés : (nom, [(t, hex), ...], gloss) — ligne RAMP_FIRST_ROW + index.
RAMPS = [
	("ramp_mangue", [(0.0, "f2c62a"), (0.45, "f5962a"), (1.0, "e04a2c")], SATIN),
	("ramp_ananas", [(0.0, "a8601a"), (0.5, "e09a2c"), (1.0, "f7cf50")], SATIN),
	("ramp_crown", [(0.0, "3a6a2a"), (1.0, "86b450")], SATIN),
	("ramp_goyave", [(0.0, "a8d058"), (0.55, "c8d870"), (1.0, "ec8a80")], SATIN),
	("ramp_papaye", [(0.0, "e8701c"), (0.7, "f59a2c"), (1.0, "9ab03a")], SATIN),
]

assert len(COLORS) <= RAMP_FIRST_ROW * GRID, "trop de couleurs unies"
assert len(RAMPS) <= GRID - RAMP_FIRST_ROW, "trop de dégradés"
_names = [c[0] for c in COLORS] + [r[0] for r in RAMPS]
assert len(_names) == len(set(_names)), "nom de couleur en double"


def hex_rgb(h):
	return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def gloss_alpha(gloss):
	return 0.25 + 0.75 * gloss


def color_index(name):
	for i, c in enumerate(COLORS):
		if c[0] == name:
			return i
	raise KeyError("couleur inconnue : %s" % name)


def color_uv(name):
	"""UV (convention Blender, v vers le haut) du centre de la case."""
	i = color_index(name)
	col, row = i % GRID, i // GRID
	u = (col + 0.5) / GRID
	v = 1.0 - (row + 0.5) / GRID
	return (u, v)


def ramp_uv(name, t):
	"""UV d'un point t∈[0,1] d'un dégradé (évite les bords de texel)."""
	idx = [r[0] for r in RAMPS].index(name)
	row = RAMP_FIRST_ROW + idx
	t = min(max(t, 0.0), 1.0)
	u = (0.5 + t * (SIZE - 1)) / SIZE
	v = 1.0 - (row + 0.5) / GRID
	return (u, v)


def ramp_rgb(stops, t):
	for k in range(len(stops) - 1):
		t0, c0 = stops[k]
		t1, c1 = stops[k + 1]
		if t <= t1:
			f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
			a, b = hex_rgb(c0), hex_rgb(c1)
			return tuple(a[j] + (b[j] - a[j]) * f for j in range(3))
	return hex_rgb(stops[-1][1])


def pixels():
	"""Image RGBA 256x256 (lignes de haut en bas), valeurs 0..255."""
	img = [[(0, 0, 0, 255)] * SIZE for _ in range(SIZE)]
	for i, (_name, h, gloss) in enumerate(COLORS):
		col, row = i % GRID, i // GRID
		r, g, b = hex_rgb(h)
		px = (round(r * 255), round(g * 255), round(b * 255), round(gloss_alpha(gloss) * 255))
		for y in range(row * CELL, (row + 1) * CELL):
			for x in range(col * CELL, (col + 1) * CELL):
				img[y][x] = px
	for k, (_name, stops, gloss) in enumerate(RAMPS):
		row = RAMP_FIRST_ROW + k
		a = round(gloss_alpha(gloss) * 255)
		for x in range(SIZE):
			r, g, b = ramp_rgb(stops, x / (SIZE - 1))
			px = (round(r * 255), round(g * 255), round(b * 255), a)
			for y in range(row * CELL, (row + 1) * CELL):
				img[y][x] = px
	return img
