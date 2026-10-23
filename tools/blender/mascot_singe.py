"""Mascotte : petit singe assis en gilet wax, articulé pour réagir au jeu.
Repère Blender : Z haut, le singe regarde -Y (Godot : +Z) ; assise en z = 0
(posé sur le bord haut du cadre du panier, jambes pendantes devant).
Pièces : body (fixe) + head (pivot cou), arm_l / arm_r (épaules),
leg_l / leg_r (hanches), tail (base) — animées dans Godot (scripts/visual/mascot.gd).
Yeux et bouche : visages du jeu (FxMeshes), posés sur la tête par Godot.

  blender -b --factory-startup -P tools/blender/mascot_singe.py -- <dossier>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from decor_people import _blob  # noqa: E402

FUR = "coco"
FUR_DARK = "coco_dark"
SKIN = "calabash_inner"
VEST = "wax_red"
TRIM = "wax_yellow"

NECK = (0.0, 0.0, 0.62)
HEAD_C = (0.0, 0.0, 0.88)
HEAD_R = 0.27
SHOULDER_X = 0.235
HIP = (0.12, -0.06, 0.08)


def body(mb):
	_blob(mb, (0, 0, 0.3), (0.25, 0.2, 0.31), FUR, 14, 8)  # tronc en poire
	_blob(mb, (0, -0.135, 0.27), (0.16, 0.08, 0.2), SKIN, 12, 6)  # ventre clair
	# Gilet wax ouvert devant : panneaux latéraux + dos, bordure dorée
	sides = 16
	z0, z1 = 0.2, 0.56
	r0, r1 = (0.265, 0.215), (0.225, 0.19)
	ring = []
	for z, r in ((z0, r0), (z1, r1)):
		row = []
		for k in range(sides + 1):
			a = 2 * math.pi * k / sides
			row.append(mb.v((math.cos(a) * r[0], math.sin(a) * r[1], z)))
		ring.append(row)
	for k in range(sides):
		a = 2 * math.pi * (k + 0.5) / sides
		if abs(a - 1.5 * math.pi) < 0.75:  # ouverture devant (-Y)
			continue
		mb.face([ring[0][k], ring[0][k + 1], ring[1][k + 1], ring[1][k]], VEST)
		# Motif wax : losange jaune ou vert au milieu de chaque panneau
		if k % 2 == 0:
			c = (math.cos(a) * 0.255, math.sin(a) * 0.212, 0.38)
			n = (math.cos(a), math.sin(a), 0.0)
			col = TRIM if k % 4 == 0 else "wax_green"
			mb.box((c[0] + n[0] * 0.01, c[1] + n[1] * 0.01, c[2]), (0.05, 0.05, 0.07), col)
	for z, r in ((z0, (0.27, 0.22)), (z1 - 0.02, (0.232, 0.197))):  # bordures
		for k in range(sides):
			a = 2 * math.pi * (k + 0.5) / sides
			if abs(a - 1.5 * math.pi) < 0.75:
				continue
			mb.box((math.cos(a) * r[0], math.sin(a) * r[1], z + 0.012), (0.09, 0.04, 0.03), TRIM)


def head(mb):
	cx, cy, cz = HEAD_C
	_blob(mb, HEAD_C, (HEAD_R * 1.04, HEAD_R * 0.95, HEAD_R), FUR, 16, 10)
	_blob(mb, (cx, cy + 0.05, cz + 0.2), (0.11, 0.1, 0.08), FUR_DARK, 8, 5)  # mèche
	# Masque clair en cœur (yeux) + museau
	for sx in (-1, 1):
		_blob(mb, (sx * 0.085, -0.175, cz + 0.035), (0.115, 0.085, 0.12), SKIN, 10, 6)
	_blob(mb, (cx, -0.2, cz - 0.09), (0.155, 0.1, 0.1), SKIN, 12, 6)
	_blob(mb, (cx, -0.3, cz - 0.06), (0.032, 0.016, 0.022), "coco_eye", 6, 4)  # nez
	for sx in (-1, 1):  # joues rosées
		_blob(mb, (sx * 0.15, -0.21, cz - 0.07), (0.04, 0.012, 0.03), "goyave_blush", 6, 3)
	# Oreilles
	for sx in (-1, 1):
		_blob(mb, (sx * 0.29, 0.0, cz + 0.01), (0.1, 0.045, 0.1), FUR, 10, 5)
		_blob(mb, (sx * 0.3, -0.035, cz + 0.01), (0.065, 0.02, 0.065), SKIN, 8, 4)


def arm(side):
	def build(mb):
		sx = SHOULDER_X * side
		_blob(mb, (sx, 0, 0.5), (0.08, 0.08, 0.08), FUR, 8, 5)  # épaule
		mb.cylinder((sx, 0, 0.5), (sx + 0.1 * side, -0.06, 0.26), 0.068, 0.058, 8, FUR, smooth=True)
		mb.cylinder((sx + 0.1 * side, -0.06, 0.26), (sx + 0.11 * side, -0.2, 0.12), 0.058, 0.05, 8, FUR, smooth=True)
		_blob(mb, (sx + 0.11 * side, -0.22, 0.1), (0.07, 0.06, 0.06), SKIN, 8, 5)  # main
	return build, (SHOULDER_X * side, 0.0, 0.5)


def leg(side):
	def build(mb):
		x = HIP[0] * side
		mb.cylinder((x, HIP[1], HIP[2]), (x * 1.15, -0.32, 0.06), 0.09, 0.075, 8, FUR, smooth=True)  # cuisse
		mb.cylinder((x * 1.15, -0.32, 0.06), (x * 1.2, -0.34, -0.26), 0.072, 0.062, 8, FUR, smooth=True)
		_blob(mb, (x * 1.2, -0.39, -0.3), (0.075, 0.11, 0.05), SKIN, 8, 5)  # pied
	return build, (HIP[0] * side, HIP[1], HIP[2])


def tail(mb):
	# Queue en crosse : sort du dos, part sur la droite de l'écran puis s'enroule.
	pts = [(0.0, 0.17, 0.1), (0.22, 0.26, 0.0), (0.42, 0.26, 0.08), (0.52, 0.2, 0.26),
		(0.48, 0.16, 0.42), (0.38, 0.15, 0.46), (0.32, 0.16, 0.38)]
	r = 0.05
	for a, b in zip(pts, pts[1:]):
		mb.cylinder(a, b, r, r * 0.9, 8, FUR, smooth=True)
		_blob(mb, b, (r * 0.92, r * 0.92, r * 0.92), FUR, 8, 4)
		r *= 0.9


PARTS = {
	"body": (body, (0, 0, 0)),
	"head": (head, NECK),
	"arm_l": arm(-1),
	"arm_r": arm(1),
	"leg_l": leg(-1),
	"leg_r": leg(1),
	"tail": (tail, (0.0, 0.17, 0.1)),
}

MASCOTS = [("mascot_singe", PARTS)]


if __name__ == "__main__":
	common.build_character("mascot_singe", PARTS, common.out_dir_from_argv())
