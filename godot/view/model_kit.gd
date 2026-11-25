class_name ModelKit
extends RefCounted
## Décors 3D définitifs (GLB Tripo de Max) branchés sur le kit modulaire, sans toucher aux cartes ni à la simulation.
## Déposer un fichier au bon nom suffit : il remplace la pièce provisoire correspondante (voir docs/MODELES-3D.md).
##
##   res://assets/models/kit/<thème>/<nom>.glb   (thème : station, port, nid ; prioritaire)
##   res://assets/models/kit/<nom>.glb           (commun à tous les thèmes)
##   res://assets/models/props/<nom>.glb         (objets isolés : remplacent les objets peints des planches)
##
## Mise en place automatique (aucun réglage nécessaire si le modèle est « propre ») :
## - échelle : la dimension de référence de la pièce (largeur d'une case, hauteur d'un couvert…) est ramenée à sa cible ;
## - orientation : un module de mur dont la plus grande longueur est en Z est tourné pour courir le long de X ;
## - origine : centré sur la case, base à y = 0 (dessus à y = 0 pour les dalles de sol) ;
## - matériaux : ombres, faces arrière masquées, néons recolorés (cyan humain, violet alien) ;
## - pas de collisions physiques : le combat se joue sur la grille de la simulation (lignes de tir, couverts),
##   le décor n'est que visuel (moins de calcul sur téléphone).
## Réglage fin d'un modèle qui sort de la convention : table TUNING (échelle, rotation, décalage).

const KIT := "res://assets/models/kit/%s.glb"
const PROPS := "res://assets/models/props/%s.glb"

## Pièce du kit (clé interne) -> [nom du fichier, mode de mise à l'échelle, valeur cible (m)]
## modes : "width" (plus grande dimension horizontale), "height" (hauteur), "tile" (dalle : largeur, dessus à 0)
const PIECES := {
	"floor": ["sol_dalle", "tile", 1.0],
	"floor_b": ["sol_dalle_02", "tile", 1.0], # variante semée sur une case sur cinq
	"deck_high": ["plateforme", "width", 1.0],
	"pool": ["sol_bassin", "tile", 1.0],
	"hull": ["mur_coque", "width", 1.0],
	"hull_w": ["mur_hublot", "width", 1.0],
	"hull_c": ["mur_angle", "width", 1.0],
	"hull_x": ["mur_contamine", "width", 1.0],
	"wall": ["cloison", "width", 1.0],
	"stairs": ["escalier", "width", 1.0],
	"rail": ["garde_corps", "width", 1.0],
	"cradle": ["berceau_artefact", "width", 1.1],
	"crane": ["grue", "height", 8.5],
}
## Noms propres à un thème, cherchés avant le nom générique (architecture extraterrestre du Nid).
const THEME_NAMES := {"nid": {"hull": "mur_biomecanique", "hull_c": "mur_biomecanique", "hull_w": "mur_alien_b", "wall": "pilier_biomecanique"}}
## Couverts : fichiers numérotés (couvert_bas_01, 02… ; couvert_haut_01…), choisis case par case.
const COVER_LOW_H := 1.0
const COVER_HIGH_H := 1.6
## Objets peints des planches (sprites) -> modèle 3D qui les remplace quand il existe.
const PROP_MODELS := {
	"k006_3": "terminal_vertical", "p001_s4": "console_commandement", "k008_1": "console_commandement",
	"p003_s4": "panneau_electrique", "k008_3": "panneau_electrique", "k006_4": "panneau_electrique",
	"p002_s4": "capsule_confinement", "k006_2": "capsule_confinement",
	"k007_1": "reacteur", "k007_3": "reacteur", "k007_5": "reacteur", "p005_s1": "reacteur", "p005_s2": "reacteur",
	"k005_1": "caisse_militaire", "p007_s1": "caisse_militaire", "k005_5": "caisse_militaire",
	"k005_2": "barricade", "p009_s1": "barricade", "p009_s2": "barricade",
	"p006_s1": "tuyau_droit", "k010_3": "tuyau_coude",
	"k005_3": "conteneur", "p004_s4": "reservoir", "p008_s1": "reservoir",
	"k006_1": "equipement_labo", "k006_5": "equipement_labo", "k006_6": "equipement_labo", "k008_6": "equipement_labo",
	"k009_1": "mur_biomecanique", "k009_2": "pilier_biomecanique", "k009_3": "artefact_alien", "k009_4": "oeuf_alien",
	"k009_5": "arche_alien", "k009_6": "cristaux_violets", "k010_5": "masse_organique",
}
## Réglages par fichier : {"scale": facteur, "yaw": degrés, "offset": Vector3}
const TUNING := {}

const CYAN := Color("39d9ef")
const VIOLET := Color("9863f5")
## Fichiers aliens (néons violets) : tout ce qui commence par ces préfixes.
const ALIEN := ["mur_bio", "mur_contamine", "pilier_bio", "arche", "oeuf", "cocon", "nid_", "masse", "cristaux", "artefact_alien",
	"structure_organique", "ruche", "roche"]

## Dossier racine (les tests le remplacent par un dossier temporaire).
static var root := "res://assets/models/"
static var _cache := {}

static func _path(rel: String) -> String:
	return root + rel + ".glb"

static func _exists(rel: String) -> bool:
	var p := _path(rel)
	return ResourceLoader.exists(p) if p.begins_with("res://") else FileAccess.file_exists(p)

static func _load(rel: String) -> Node3D:
	var p := _path(rel)
	if p.begins_with("res://"):
		var ps := load(p) as PackedScene # null si l'import a échoué (GLB compressé meshopt/Draco) : pièce provisoire gardée
		return ps.instantiate() if ps else null
	var doc := GLTFDocument.new() # fichiers hors projet (tests) : chargement GLB à la volée
	var st := GLTFState.new()
	if doc.append_from_file(p, st) != OK:
		return null
	return doc.generate_scene(st) as Node3D

## Fichier du thème s'il existe, sinon fichier commun, sinon "".
static func find(name: String, theme: String) -> String:
	for rel in ["kit/%s/%s" % [theme, name], "kit/" + name]:
		if _exists(rel):
			return rel
	return ""

## Modèle d'une pièce du kit, prêt pour un MultiMesh : {"mesh": Mesh, "xform": Transform3D} ou {} (provisoire gardé).
## Le maillage importé est gardé tel quel (niveaux de détail générés à l'import conservés) ; la mise en place est
## portée par `xform`, à composer avec la transformation de chaque case.
static func piece(key: String, theme: String) -> Dictionary:
	var base := key.rstrip("0123456789.")
	if not PIECES.has(base):
		return {}
	var spec: Array = PIECES[base]
	var rel := ""
	for name in [THEME_NAMES.get(theme, {}).get(base, ""), spec[0]]:
		if name != "" and rel == "":
			rel = find(name, theme)
	if rel == "":
		return {}
	var ck := rel + "|" + key
	if not _cache.has(ck):
		_cache[ck] = _fit_mesh(rel, spec[1], spec[2])
	return _cache[ck]

## Fusionne les maillages d'un fichier en un seul (un appel de rendu par matériau) et calcule sa mise en place.
static func _fit_mesh(rel: String, mode: String, target: float) -> Dictionary:
	var scene := _load(rel)
	if scene == null:
		return {}
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh
	var local := Transform3D.IDENTITY
	if meshes.size() == 1: # cas Tripo : un seul maillage, gardé tel quel (avec ses niveaux de détail)
		var mi := meshes[0] as MeshInstance3D
		mesh = mi.mesh
		local = _global(mi, scene)
		mesh = _with_materials(mesh, mi, rel)
	else:
		var out := ArrayMesh.new()
		for m in meshes:
			var mi := m as MeshInstance3D
			var xf := _global(mi, scene)
			for s in mi.mesh.get_surface_count():
				var st := SurfaceTool.new()
				st.append_from(mi.mesh, s, xf)
				st.commit(out)
				out.surface_set_material(out.get_surface_count() - 1, _material(mi.get_active_material(s), rel))
		mesh = out
	scene.free()
	var fit := _fit(local * mesh.get_aabb() if local != Transform3D.IDENTITY else mesh.get_aabb(), mode, target, rel)
	return {"mesh": mesh, "xform": fit * local}

static func _global(n: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != top:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

static func _with_materials(mesh: Mesh, mi: MeshInstance3D, rel: String) -> Mesh:
	var m := mesh.duplicate() as Mesh
	for s in m.get_surface_count():
		m.surface_set_material(s, _material(mi.get_active_material(s), rel))
	return m

## Mise à l'échelle, orientation et origine d'après la boîte englobante.
static func _fit(box: AABB, mode: String, target: float, rel: String) -> Transform3D:
	var name := rel.get_file()
	var t: Dictionary = TUNING.get(name, {})
	var yaw := deg_to_rad(float(t.get("yaw", 0.0)))
	if mode in ["width", "tile"] and t.get("yaw", null) == null and box.size.z > box.size.x * 1.15:
		yaw = PI / 2 # module livré dans l'autre sens : il doit courir le long de X
	if mode == "length" and t.get("yaw", null) == null and box.size.x > box.size.z:
		yaw = -PI / 2 # arme livrée le long de X : canon remis vers +Z (sens à régler dans TUNING si besoin)
	var ref: float = box.size.y if mode == "height" else maxf(box.size.x, box.size.z)
	if mode == "length":
		ref = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k: float = (target / ref if ref > 0.0001 else 1.0) * float(t.get("scale", 1.0))
	var c := box.get_center()
	var y0: float = box.end.y if mode == "tile" else (c.y if mode == "length" else box.position.y)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k)
	var o: Vector3 = Basis(Vector3.UP, yaw) * (Vector3(-c.x, -y0, -c.z) * k) + (t.get("offset", Vector3.ZERO) as Vector3)
	return Transform3D(b, o)

## Matériau d'un modèle : copie réglée pour le jeu (ombres, faces arrière) et néons recolorés selon le camp.
static func _material(src: Material, rel: String) -> Material:
	if not (src is StandardMaterial3D):
		return src
	var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_BACK
	var alien := is_alien(rel.get_file())
	var glow := m.emission_enabled or m.emission_texture != null or _named_glow(src.resource_name)
	if glow:
		m.emission_enabled = true
		m.emission = VIOLET if alien else CYAN
		m.emission_energy_multiplier = 1.6
		if m.emission_texture != null:
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	return m

static func _named_glow(n: String) -> bool:
	var l := n.to_lower()
	for w in ["emis", "glow", "neon", "light", "led", "lumi"]:
		if w in l:
			return true
	return false

static func is_alien(name: String) -> bool:
	for p in ALIEN:
		if name.begins_with(p):
			return true
	return false

## Objet 3D isolé (couvert, objet mural, décor) mis à l'échelle sur sa hauteur, ou null.
static func node(rel: String, height: float) -> Node3D:
	if rel == "" or not _exists(rel):
		return null
	var ck := "node|" + rel
	if not _cache.has(ck):
		var fm := _fit_mesh(rel, "height", 1.0)
		_cache[ck] = fm
	var fm: Dictionary = _cache[ck]
	if fm.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = fm["mesh"]
	mi.transform = fm["xform"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * height
	holder.add_child(mi)
	return holder

## Modèle qui remplace un objet peint (sprite d'une planche), ou null.
static func prop_for(sprite: String, height: float, theme: String) -> Node3D:
	if not PROP_MODELS.has(sprite):
		return null
	var name: String = PROP_MODELS[sprite]
	for rel in ["props/%s/%s" % [theme, name], "props/" + name]:
		if _exists(rel):
			return node(rel, height)
	return null

## Couvert numéroté du thème (bas ou haut), choisi par `pick`, ou null s'il n'y en a aucun.
static func cover(theme: String, high: bool, pick: int) -> Node3D:
	var stem := "couvert_haut_%02d" if high else "couvert_bas_%02d"
	var found: Array[String] = []
	for i in range(1, 13):
		var rel := find(stem % i, theme)
		if rel != "":
			found.append(rel)
	if found.is_empty():
		return null
	return node(found[pick % found.size()], COVER_HIGH_H if high else COVER_LOW_H)

## Arme (weapons/<nom>.glb) mise à la longueur voulue, canon vers +Z, ou null si elle n'a pas été livrée.
static func weapon(name: String, length: float) -> Node3D:
	var rel := "weapons/" + name
	if not _exists(rel):
		return null
	var ck := "weapon|" + rel
	if not _cache.has(ck):
		_cache[ck] = _fit_mesh(rel, "length", 1.0)
	var fm: Dictionary = _cache[ck]
	if fm.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = fm["mesh"]
	mi.transform = fm["xform"]
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * length
	holder.add_child(mi)
	return holder

static func clear_cache() -> void:
	_cache.clear()
