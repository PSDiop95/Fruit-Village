"""Outils partagés des scripts d'assets Blender (bpy).

Convention : chaque script d'asset définit `ASSET_ID` et `build(mb)` qui remplit
un MeshBuilder en unités normalisées (rayon ≈ 1). `common.run(module)` :
  1. construit le mesh, le met à l'échelle (rayon = data/fruits.tres),
  2. applique le matériau unique « palette » (UV dans palette.png),
  3. pose l'ancre de visage `face_anchor` (raycast de face),
  4. exporte assets/models/<asset>.glb (ou le dossier passé après `--`).

Axes Blender : Z = haut, la caméra du jeu regarde depuis -Y (export +Y up :
Godot +Z = Blender -Y = avant du fruit).

Lancer un asset seul :
  blender -b --factory-startup -P tools/blender/fruit_sidem.py -- <dossier>
"""
import math
import os
import re
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import palette_def as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PALETTE_PNG = os.path.join(ROOT, "assets", "textures", "palette.png")
FRUITS_TRES = os.path.join(ROOT, "data", "fruits.tres")
MAX_TRIS = 800


# ---------------------------------------------------------------- Données jeu

def fruit_radius(fruit_id):
	"""Rayon de collision lu dans data/fruits.tres (source de vérité M1)."""
	with open(FRUITS_TRES, encoding="utf-8") as f:
		text = f.read()
	for block in text.split("[sub_resource")[1:]:
		m_id = re.search(r'id = &"([^"]+)"', block)
		m_r = re.search(r"\nradius = ([0-9.]+)", block)
		if m_id and m_r and m_id.group(1) == fruit_id:
			return float(m_r.group(1))
	raise KeyError("fruit absent de fruits.tres : %s" % fruit_id)


GAME_CONFIG_TRES = os.path.join(ROOT, "data", "game_config.tres")


def game_config(key):
	"""Valeur numérique de data/game_config.tres (dimensions du panier M1)."""
	with open(GAME_CONFIG_TRES, encoding="utf-8") as f:
		m = re.search(r"\n%s = ([-0-9.]+)" % re.escape(key), f.read())
	if not m:
		raise KeyError("clé absente de game_config.tres : %s" % key)
	return float(m.group(1))


# ---------------------------------------------------------------- Géométrie

def hash01(*k):
	"""Bruit déterministe 0..1 (aucun random : modèles reproductibles)."""
	h = 0
	for v in k:
		h = (h * 1000003) ^ int(round(v * 9973))
		h &= 0xFFFFFFFF
	h ^= h >> 13
	h = (h * 0x5BD1E995) & 0xFFFFFFFF
	h ^= h >> 15
	return (h & 0xFFFF) / 65535.0


def sph(th, ph):
	"""Direction unitaire (theta 0 = haut, phi -90° = face caméra)."""
	return Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))


FRONT_PHI = -math.pi * 0.5


def smoothstep(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3 - 2 * t)


class MeshBuilder:
	"""Collecte sommets + faces avec UV par coin (couleur de palette)."""

	def __init__(self):
		self.verts = []
		self.faces = []  # (indices, uvs, smooth)
		# Faces de pièces ouvertes (éclats, patchs) à orienter vers l'extérieur.
		self.outward = set()
		# Props ouverts : direction vers laquelle la face doit pointer.
		self.facing = {}

	def v(self, p):
		self.verts.append(Vector(p))
		return len(self.verts) - 1

	def face(self, idx, color=None, uvs=None, smooth=True, outward=False, facing=None):
		if uvs is None:
			uv = P.color_uv(color)
			uvs = [uv] * len(idx)
		if outward:
			self.outward.add(len(self.faces))
		if facing is not None:
			self.facing[len(self.faces)] = Vector(facing)
		self.faces.append((list(idx), list(uvs), smooth))

	def ramp_face(self, idx, ramp, ts, smooth=True):
		self.face(idx, uvs=[P.ramp_uv(ramp, t) for t in ts], smooth=smooth)

	# --- primitives ---------------------------------------------------------

	def lat_long(self, seg, rings, pos_fn, color_fn, smooth=True, twist=0.0):
		"""Sphère paramétrique. pos_fn(theta, phi) -> Vector (theta 0 = pôle haut).
		color_fn(theta_c, phi_c, ring, i) -> nom | (rampe, [t par coin])."""
		top = self.v(pos_fn(0.0, 0.0))
		grid = []
		for j in range(1, rings):
			th = math.pi * j / rings
			row = []
			for i in range(seg):
				ph = 2 * math.pi * i / seg + twist * j
				row.append(self.v(pos_fn(th, ph)))
			grid.append(row)
		bot = self.v(pos_fn(math.pi, 0.0))

		def emit(idx, th, ph, j, i, corners):
			c = color_fn(th, ph, j, i)
			if isinstance(c, tuple):
				ramp, tfn = c
				self.ramp_face(idx, ramp, [tfn(a, b) for a, b in corners], smooth)
			else:
				self.face(idx, c, smooth=smooth)

		dth = math.pi / rings
		dph = 2 * math.pi / seg
		for i in range(seg):
			i2 = (i + 1) % seg
			ph = dph * (i + 0.5)
			emit([top, grid[0][i2], grid[0][i]], dth * 0.5, ph, 0, i,
				[(0, ph), (dth, ph + dph * 0.5), (dth, ph - dph * 0.5)])
			for j in range(rings - 2):
				th0, th1 = dth * (j + 1), dth * (j + 2)
				emit([grid[j][i], grid[j][i2], grid[j + 1][i2], grid[j + 1][i]],
					(th0 + th1) * 0.5, ph, j + 1, i,
					[(th0, ph - dph * 0.5), (th0, ph + dph * 0.5), (th1, ph + dph * 0.5), (th1, ph - dph * 0.5)])
			last = grid[-1]
			emit([bot, last[i], last[i2]], math.pi - dth * 0.5, ph, rings - 1, i,
				[(math.pi, ph), (math.pi - dth, ph - dph * 0.5), (math.pi - dth, ph + dph * 0.5)])
		return top, grid, bot

	def cylinder(self, base, tip, r0, r1, sides, color, smooth=False, cap_color=None):
		"""Tronc de cône fermé de `base` à `tip` (queues, pédoncules)."""
		base, tip = Vector(base), Vector(tip)
		axis = (tip - base).normalized()
		ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
		u = axis.cross(ref).normalized()
		w = axis.cross(u)
		ring0, ring1 = [], []
		for k in range(sides):
			a = 2 * math.pi * k / sides
			d = u * math.cos(a) + w * math.sin(a)
			ring0.append(self.v(base + d * r0))
			ring1.append(self.v(tip + d * r1) if r1 > 0 else None)
		if r1 <= 0:
			apex = self.v(tip)
			for k in range(sides):
				self.face([ring0[k], ring0[(k + 1) % sides], apex], color, smooth=smooth)
		else:
			for k in range(sides):
				k2 = (k + 1) % sides
				self.face([ring0[k], ring0[k2], ring1[k2], ring1[k]], color, smooth=smooth)
			self.face(list(reversed(ring1)), cap_color or color, smooth=False)
		self.face(list(ring0), cap_color or color, smooth=False)

	def blade(self, base, tip, width, thick, normal, ramp, color_base=0.0, color_tip=1.0, color=None):
		"""Feuille fine fermée (4 triangles) : couronnes, feuilles, sépales.
		`ramp` + t base/pointe, ou `color` unie (ramp ignoré)."""
		base, tip = Vector(base), Vector(tip)
		axis = (tip - base)
		side = axis.cross(Vector(normal)).normalized() * width * 0.5
		n = Vector(normal).normalized() * thick * 0.5
		mid = base + axis * 0.35
		a = self.v(base - side)
		b = self.v(base + side)
		c = self.v(mid + n)
		d = self.v(mid - n)
		t = self.v(tip)
		if color:
			for f in ([a, b, c], [b, t, c], [t, a, c], [a, t, b, d]):
				self.face(f, color, smooth=False)
			return
		tb, tt = color_base, color_tip
		self.ramp_face([a, b, c], ramp, [tb, tb, (tb + tt) * 0.5], smooth=False)
		self.ramp_face([b, t, c], ramp, [tb, tt, (tb + tt) * 0.5], smooth=False)
		self.ramp_face([t, a, c], ramp, [tt, tb, (tb + tt) * 0.5], smooth=False)
		self.ramp_face([a, t, b, d], ramp, [tb, tt, tb, (tb + tt) * 0.5], smooth=False)

	def patch(self, direction, surface_fn, rad, color, rim_color=None, rim=0.0,
			sides=8, jag=0.0, seed=0.0, lift=1.01):
		"""Disque posé à fleur de surface autour de `direction` (éclat, tache,
		fissure). surface_fn(dir unitaire) -> point de surface. `jag` = bord
		cassé irrégulier, `rim` = largeur d'un liseré `rim_color`."""
		c = Vector(direction).normalized()
		up = Vector((0, 0, 1)) if abs(c.z) < 0.9 else Vector((1, 0, 0))
		u = c.cross(up).normalized()
		w = u.cross(c)
		center = self.v(surface_fn(c) * lift)
		# Anneaux concentriques : un grand patch suit la courbure du fruit.
		n_rings = max(1, int(math.ceil(rad / 0.14)))
		rings, outer = [], []
		for q in range(1, n_rings + 1):
			f = q / n_rings
			row = []
			for k in range(sides):
				a = 2 * math.pi * k / sides
				r = rad * f * (1.0 - jag + 2.0 * jag * hash01(k, seed))
				off = u * math.cos(a) + w * math.sin(a)
				row.append(self.v(surface_fn((c + off * r).normalized()) * lift))
				if q == n_rings and rim > 0.0:
					outer.append(self.v(surface_fn((c + off * (r + rim)).normalized()) * (lift - 0.004)))
			rings.append(row)
		for k in range(sides):
			k2 = (k + 1) % sides
			self.face([center, rings[0][k], rings[0][k2]], color, smooth=False, outward=True)
			for q in range(n_rings - 1):
				a_, b_ = rings[q], rings[q + 1]
				self.face([a_[k], b_[k], b_[k2], a_[k2]], color, smooth=False, outward=True)
			if rim > 0.0:
				inner = rings[-1]
				self.face([inner[k], outer[k], outer[k2], inner[k2]], rim_color, smooth=False, outward=True)

	def streak(self, direction, surface_fn, length, width, color, segments=3, lift=1.008, tilt=0.0):
		"""Trait fin posé sur la surface, orienté selon le méridien (fibres,
		duvet, stries). `tilt` incline le trait (radians)."""
		c = Vector(direction).normalized()
		up = Vector((0, 0, 1))
		east = up.cross(c)
		if east.length < 1e-4:
			east = Vector((1, 0, 0))
		east.normalize()
		north = c.cross(east)
		along = (north * math.cos(tilt) + east * math.sin(tilt)).normalized()
		side = c.cross(along).normalized()
		left, right = [], []
		for k in range(segments + 1):
			t = (k / segments - 0.5) * length
			taper = 1.0 - abs(k / segments - 0.5) * 1.6  # effilé aux deux bouts
			d = (c + along * t).normalized()
			p = surface_fn(d) * lift
			left.append(self.v(p - side * width * 0.5 * taper))
			right.append(self.v(p + side * width * 0.5 * taper))
		for k in range(segments):
			self.face([left[k], right[k], right[k + 1], left[k + 1]], color, smooth=False, outward=True)

	def box(self, center, size, color, colors=None):
		"""Pavé fermé (props, décor). `colors` : dict face->couleur parmi
		front/back/left/right/top/bottom (front = -Y, face caméra)."""
		cx, cy, cz = center
		sx, sy, sz = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
		p = [self.v((cx + dx * sx, cy + dy * sy, cz + dz * sz))
			for dz in (-1, 1) for dy in (-1, 1) for dx in (-1, 1)]
		faces = {
			"bottom": ([0, 1, 3, 2], (0, 0, -1)), "top": ([4, 6, 7, 5], (0, 0, 1)),
			"front": ([0, 4, 5, 1], (0, -1, 0)), "back": ([2, 3, 7, 6], (0, 1, 0)),
			"left": ([0, 2, 6, 4], (-1, 0, 0)), "right": ([1, 5, 7, 3], (1, 0, 0)),
		}
		for key, (idx, n) in faces.items():
			c = (colors or {}).get(key, color)
			if c is None:
				continue
			self.face([p[i] for i in idx], c, smooth=False, facing=n)

	def quad(self, a, b, c, d, color, facing=(0, -1, 0)):
		self.face([self.v(a), self.v(b), self.v(c), self.v(d)], color, smooth=False, facing=facing)

	def tri(self, a, b, c, color, facing=(0, -1, 0)):
		self.face([self.v(a), self.v(b), self.v(c)], color, smooth=False, facing=facing)

	def tri_count(self):
		return sum(len(f[0]) - 2 for f in self.faces)


# ---------------------------------------------------------------- Scène / export

def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def palette_material():
	mat = bpy.data.materials.get("palette")
	if mat:
		return mat
	mat = bpy.data.materials.new("palette")
	mat.use_nodes = True
	nt = mat.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Roughness"].default_value = 0.6
	tex = nt.nodes.new("ShaderNodeTexImage")
	img = bpy.data.images.load(PALETTE_PNG, check_existing=True)
	img.alpha_mode = "NONE"  # alpha = gloss (lu par toon.gdshader), pas de transparence
	tex.image = img
	tex.interpolation = "Linear"
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	return mat


def to_object(mb, name, radius=None):
	# Normalisation (fruits) : le point le plus éloigné de l'origine = rayon de
	# collision. Props (panier, décor) : radius=None, unités déjà en mètres.
	k = 1.0
	if radius is not None:
		k = radius / max(v.length for v in mb.verts)
	me = bpy.data.meshes.new(name)
	me.from_pydata([tuple(v * k) for v in mb.verts], [], [f[0] for f in mb.faces])
	me.update()
	uv = me.uv_layers.new(name="UVMap")
	li = 0
	for poly, (_idx, uvs, smooth) in zip(me.polygons, mb.faces):
		poly.use_smooth = smooth
		for c in range(poly.loop_total):
			uv.data[poly.loop_start + c].uv = uvs[c]
			li += 1
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	if radius is not None:
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	else:
		# Props : volumes fermés (sans `facing`) recalculés, le reste orienté à la main.
		free = [f for i, f in enumerate(bm.faces) if i not in mb.facing]
		if free:
			bmesh.ops.recalc_face_normals(bm, faces=free)
	bm.faces.ensure_lookup_table()
	for fi, want in mb.facing.items():
		f = bm.faces[fi]
		if f.normal.dot(want) < 0.0:
			f.normal_flip()
	for fi in mb.outward:
		f = bm.faces[fi]
		if f.normal.dot(f.calc_center_median()) < 0.0:
			f.normal_flip()
	bm.to_mesh(me)
	bm.free()
	me.materials.append(palette_material())
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def add_face_anchor(obj, height=0.0, size=1.0, radius=1.0):
	"""Empty `face_anchor` sur la surface avant (raycast depuis -Y), à `height`
	(fraction du rayon). Échelle = taille du visage (1 = taille M2)."""
	z = height * radius
	hit, loc, _n, _i = obj.ray_cast(Vector((0, -10 * radius, z)), Vector((0, 1, 0)))
	if not hit:
		raise RuntimeError("%s : raycast de visage raté" % obj.name)
	e = bpy.data.objects.new("face_anchor", None)
	e.empty_display_type = "ARROWS"
	e.empty_display_size = radius * 0.3
	e.location = loc
	e.scale = (size, size, size)
	e.parent = obj
	bpy.context.scene.collection.objects.link(e)
	return e


def export_glb(obj, path):
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	for c in obj.children:
		c.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.export_scene.gltf(
		filepath=path,
		export_format="GLB",
		use_selection=True,
		export_yup=True,
		export_apply=True,
		export_texcoords=True,
		export_normals=True,
		export_materials="EXPORT",
		# Aucune image embarquée : le jeu lit assets/textures/palette.png via le
		# matériau partagé (sinon Godot extrait une copie de la palette par .glb).
		export_image_format="NONE",
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)


def build_asset(module, out_dir):
	"""Construit + exporte un asset. Retourne un rapport (dict)."""
	reset_scene()
	radius = fruit_radius(module.FRUIT_ID)
	mb = MeshBuilder()
	module.build(mb)
	name = "fruit_%s" % module.FRUIT_ID
	obj = to_object(mb, name, radius)
	face = getattr(module, "FACE", {})
	add_face_anchor(obj, face.get("height", 0.0), face.get("size", 1.0), radius)
	os.makedirs(out_dir, exist_ok=True)
	path = os.path.join(out_dir, name + ".glb")
	export_glb(obj, path)
	tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
	far = max(v.co.length for v in obj.data.vertices)
	rep = {"asset": name, "tris": tris, "radius": round(far, 4), "target": radius, "path": path}
	if tris >= MAX_TRIS:
		raise RuntimeError("%s : %d triangles (max %d)" % (name, tris, MAX_TRIS))
	print("ASSET %(asset)s tris=%(tris)d radius=%(radius).4f target=%(target).4f" % rep)
	return rep


PREVIEW_COLLECTION = "MergeFruits"


def preview(module, location=(0.0, 0.0, 0.0)):
	"""Aperçu live (Blender MCP) : construit le fruit dans la collection
	MergeFruits de la scène ouverte, sans réinitialiser la scène de l'utilisateur.
	Remplace l'aperçu précédent du même fruit. Retourne l'objet."""
	scene = bpy.context.scene
	col = bpy.data.collections.get(PREVIEW_COLLECTION)
	if col is None:
		col = bpy.data.collections.new(PREVIEW_COLLECTION)
		scene.collection.children.link(col)
	name = "fruit_%s" % module.FRUIT_ID
	old = bpy.data.objects.get(name)
	if old:
		for c in list(old.children):
			bpy.data.objects.remove(c, do_unlink=True)
		me = old.data
		bpy.data.objects.remove(old, do_unlink=True)
		if me and me.users == 0:
			bpy.data.meshes.remove(me)
	radius = fruit_radius(module.FRUIT_ID)
	mb = MeshBuilder()
	module.build(mb)
	obj = to_object(mb, name, radius)
	scene.collection.objects.unlink(obj)
	col.objects.link(obj)
	face = getattr(module, "FACE", {})
	anchor = add_face_anchor(obj, face.get("height", 0.0), face.get("size", 1.0), radius)
	scene.collection.objects.unlink(anchor)
	col.objects.link(anchor)
	obj.location = location
	return obj


def build_prop(module, out_dir):
	"""Construit + exporte un prop (panier, étal, décor) : `ASSET_NAME`,
	`build(mb)` en mètres, repère Blender (Z haut, avant = -Y)."""
	reset_scene()
	mb = MeshBuilder()
	module.build(mb)
	obj = to_object(mb, module.ASSET_NAME)
	os.makedirs(out_dir, exist_ok=True)
	path = os.path.join(out_dir, module.ASSET_NAME + ".glb")
	export_glb(obj, path)
	tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
	limit = getattr(module, "MAX_TRIS", 3000)
	if tris >= limit:
		raise RuntimeError("%s : %d triangles (max %d)" % (module.ASSET_NAME, tris, limit))
	print("ASSET %s tris=%d" % (module.ASSET_NAME, tris))
	return {"asset": module.ASSET_NAME, "tris": tris, "path": path}


def run_prop(module):
	"""Point d'entrée d'un script de prop lancé seul."""
	build_prop(module, out_dir_from_argv())


def preview_prop(module, location=(0.0, 0.0, 0.0)):
	"""Aperçu live d'un prop dans la collection MergeFruits (Blender MCP)."""
	scene = bpy.context.scene
	col = bpy.data.collections.get(PREVIEW_COLLECTION)
	if col is None:
		col = bpy.data.collections.new(PREVIEW_COLLECTION)
		scene.collection.children.link(col)
	old = bpy.data.objects.get(module.ASSET_NAME)
	if old:
		me = old.data
		bpy.data.objects.remove(old, do_unlink=True)
		if me and me.users == 0:
			bpy.data.meshes.remove(me)
	mb = MeshBuilder()
	module.build(mb)
	obj = to_object(mb, module.ASSET_NAME)
	scene.collection.objects.unlink(obj)
	col.objects.link(obj)
	obj.location = location
	return obj


def out_dir_from_argv():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	return argv[0] if argv else os.path.join(ROOT, "assets", "models")


def run(module):
	"""Point d'entrée d'un script d'asset lancé seul."""
	build_asset(module, out_dir_from_argv())
