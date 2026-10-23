"""Pipeline des modèles : Blender -> staging -> vérification Godot -> assets/models/.

  python tools/build_models.py

1. Blender (headless) exécute tools/blender/export_all.py vers
   assets/models/_staging/ (palette régénérée au passage).
2. Godot importe les .glb puis tools/verify_models.gd les contrôle
   (triangles, rayon ±3 %, matériau palette, face_anchor).
3. Conforme -> les .glb remplacent ceux de assets/models/. Sinon l'export
   est refusé : staging supprimé, modèles en place inchangés, code 1.

Chemins surchargeables : variables d'environnement BLENDER et GODOT.
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODELS = os.path.join(ROOT, "assets", "models")
STAGING = os.path.join(MODELS, "_staging")
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot.exe")


def run(cmd):
	print(">", " ".join(cmd))
	p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
	for line in (p.stdout + p.stderr).splitlines():
		if line.startswith(("ASSET", "EXPORT_", "VERIFY", "palette", "ERROR", "SCRIPT ERROR")) or "Error" in line:
			print("   ", line)
	return p.returncode


def godot_import():
	return run([GODOT, "--headless", "--path", ROOT, "--import"])


def clean_staging():
	shutil.rmtree(STAGING, ignore_errors=True)


def main():
	clean_staging()
	os.makedirs(STAGING)
	if run([BLENDER, "-b", "--factory-startup", "-P",
			os.path.join(ROOT, "tools", "blender", "export_all.py"), "--", STAGING]) != 0:
		clean_staging()
		sys.exit("Export Blender en échec.")
	godot_import()
	ok = run([GODOT, "--headless", "--path", ROOT, "-s", "tools/verify_models.gd",
		"--", "res://assets/models/_staging"]) == 0
	if not ok:
		clean_staging()
		godot_import()
		sys.exit("EXPORT REFUSÉ : vérification Godot en échec (modèles en place inchangés).")
	for src in glob.glob(os.path.join(STAGING, "*.glb")):
		shutil.copy2(src, os.path.join(MODELS, os.path.basename(src)))
	shutil.copy2(os.path.join(STAGING, "export_report.json"), os.path.join(MODELS, "export_report.json"))
	clean_staging()
	godot_import()
	print("MODÈLES ACCEPTÉS -> assets/models/")


if __name__ == "__main__":
	main()
