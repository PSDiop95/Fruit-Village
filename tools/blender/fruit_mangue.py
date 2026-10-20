"""Mangue : rein allongé (bec en bas à gauche), dégradé vert (bas) → jaune →
orange → rouge (haut), queue + feuille vers la droite.
Référence : docs/refs/fruits/07_mangue.jpg (affinée à 0,84 de large pour
rester proche de la sphère de collision)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector  # noqa: E402
from common import sph, run  # noqa: E402

FRUIT_ID = "mangue"
FACE = {"height": 0.0, "size": 0.85}


def _shape(d):
	low = max(-d.z, 0.0)
	x = d.x * 0.84 * (1.0 - 0.14 * low)  # plus étroite en bas
	x -= 0.12 * low * low  # bec vers la gauche
	x += 0.04 * max(d.z, 0.0)  # épaule droite
	return Vector((x, d.y * 0.72, d.z * 0.94))


def build(mb):
	def tone(th, ph):
		d = sph(th, ph)
		return 0.5 + 0.38 * d.z + 0.42 * d.x  # jaune bas-gauche → rouge haut-droite

	mb.lat_long(24, 14, lambda th, ph: _shape(sph(th, ph)), lambda th, ph, j, i: ("ramp_mangue", tone))
	top = _shape(Vector((0, 0, 1)))
	tip = top + Vector((-0.02, 0, 0.1))
	mb.cylinder(top - Vector((0, 0, 0.05)), tip, 0.05, 0.04, 6, "stem_brown")
	# Feuille face caméra, courbée vers la droite.
	leaf_tip = Vector((0.62, -0.1, 0.72))
	mb.blade(tip - Vector((0, 0, 0.03)), leaf_tip, 0.38, 0.05,
		(0.15, -1.0, 0.3), "ramp_crown", 0.15, 0.8)
	# Nervure centrale (trait sombre sur la face avant de la feuille).
	mb.cylinder(tip + Vector((0.03, -0.03, -0.02)), leaf_tip + Vector((-0.06, -0.03, 0.01)), 0.012, 0.006, 4, "leaf_dark")


if __name__ == "__main__":
	run(sys.modules[__name__])
