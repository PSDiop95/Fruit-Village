"""Export batch de tous les assets -> assets/models/ (ou le dossier après `--`).

  blender -b --factory-startup -P tools/blender/export_all.py -- <dossier>

Régénère d'abord la palette, puis construit chaque fruit dans une scène vide.
Écrit <dossier>/export_report.json (triangles, rayon) pour la vérification.
En pratique, passer par tools/build_models.py (export + vérification Godot).
"""
import importlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import make_palette  # noqa: E402

FRUITS = ["sidem", "bissap", "tamarin", "ditakh", "madd", "goyave",
	"mangue", "papaye", "ananas", "coco", "pain_de_singe"]


PROPS = ["basket_calebasse", "stall_sandaga"]


class _Prop:
	"""Adaptateur : une fonction de build du décor vue comme un module de prop."""

	def __init__(self, name, fn, limit):
		self.ASSET_NAME = name
		self.MAX_TRIS = limit
		self.build = fn


def main():
	out_dir = common.out_dir_from_argv()
	make_palette.main()
	reports = []
	for fid in FRUITS:
		mod = importlib.import_module("fruit_%s" % fid)
		reports.append(common.build_asset(mod, out_dir))
	# Props : panier, étal, décor (un module peut fournir plusieurs assets).
	for name in PROPS:
		reports.append(common.build_prop(importlib.import_module(name), out_dir))
	decor = importlib.import_module("decor_sandaga")
	for asset, fn, limit in decor.DECOR_ASSETS:
		reports.append(common.build_prop(_Prop(asset, fn, limit), out_dir))
	with open(os.path.join(out_dir, "export_report.json"), "w", encoding="utf-8") as f:
		json.dump(reports, f, indent=1)
	print("EXPORT_OK %d assets -> %s" % (len(reports), out_dir))


main()
