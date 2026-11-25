class_name AbyssKit
extends RefCounted
## Kit modulaire 3D d'ABYSS PROTOCOL (références KIT-001 à 010, salle ENV-007 Némésis).
## Chaque pièce est un vrai modèle : arêtes chanfreinées, matériaux PBR (albédo, normales, rugosité)
## projetés en triplanaire, et un seul maillage partagé par type de pièce (mémoire et appels de rendu réduits).
## Convention : origine au centre de la case au niveau du sol, 1 unité = 1 m, +Y en haut.
## Réutilisable pour les prochaines missions : les cartes ne décrivent que des cases, le kit fait le reste.

const TEX := "res://assets/textures/%s_%s.png"
static var _mats := {}
static var _meshes := {}

# ---------- thèmes de carte (station, port de surface, nid organique) ----------

## Thème du décor en cours : "station" (labo, Némésis), "port" (Port attaqué), "nid" (Le Nid).
static var theme := "station"
## Substitution de matériaux appliquée aux pièces construites pendant la construction du décor (vide sinon :
## les unités et les effets gardent leurs matériaux).
static var remap := {}
const REMAPS := {
	"port": {"floor": "asphalt", "hull": "concrete", "grate": "rust", "plate": "rust", "led_cyan": "led_amber", "water": "sea", "crate": "rust"},
	"nid": {"floor": "rock_floor", "hull": "rock", "grate": "rock_top", "plate": "chitin", "steel": "bone", "dark": "rock", "hazard": "goo",
		"led_cyan": "led_violet", "led_amber": "led_violet", "water": "bile", "glass": "goo", "brass": "bone", "crate": "chitin"},
}
const THEME_OF := {"port": "port", "nid": "nid"}

## Ouvre la construction du décor d'une carte : choisit le thème et active la substitution de matériaux.
static func begin_theme(map_id: String) -> void:
	theme = THEME_OF.get(map_id, "station")
	remap = REMAPS.get(theme, {})

## Ferme la construction du décor (les pièces construites ensuite gardent leurs matériaux d'origine).
static func end_theme() -> void:
	remap = {}

## Clé de cache d'une pièce : une version par thème.
static func _key(key: String) -> String:
	return key if theme == "station" else theme + ":" + key

# ---------- matériaux ----------

## Matériaux du kit, créés une fois. Couleurs : bible artistique V3.1.
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"plate", "hull", "floor", "grate", "hazard", "crate":
			m.albedo_texture = load(TEX % [key, "albedo"])
			m.normal_enabled = true
			m.normal_texture = load(TEX % [key, "normal"])
			m.normal_scale = 0.8
			m.roughness_texture = load(TEX % [key, "rough"])
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.metallic = {"plate": 0.55, "hull": 0.6, "floor": 0.45, "grate": 0.75, "hazard": 0.2, "crate": 0.25}[key]
			m.uv1_triplanar = true
			m.uv1_triplanar_sharpness = 4.0
			m.uv1_scale = Vector3.ONE * ({"hull": 0.5, "hazard": 2.0, "crate": 1.2}.get(key, 1.0))
			if key in ["floor", "grate"]:
				# projection dans le repère du monde : les dalles se prolongent d'une case à l'autre, la grille de jeu
				# ne se lit plus dans le sol (refonte V1) ; 1 texture = 2 m pour le sol
				m.uv1_world_triplanar = true
			if key == "floor":
				m.uv1_scale = Vector3.ONE * 0.5
		"screen", "screen_green":
			m.albedo_texture = load(TEX % ["screen", "albedo"])
			m.emission_enabled = true
			m.emission_texture = load(TEX % ["screen", "emission"])
			m.emission = Color(0.3, 0.75, 0.45) if key == "screen_green" else Color(0.3, 0.6, 0.75)
			m.emission_energy_multiplier = 1.0
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.roughness = 0.45
			m.metallic = 0.0
		"asphalt": _tex(m, "floor", Color(0.46, 0.45, 0.43), 0.05, 0.5, true)
		"concrete": _tex(m, "plate", Color(1.0, 0.97, 0.9), 0.05, 0.8, false)
		"rust": _tex(m, "hull", Color(1.35, 0.72, 0.42), 0.3, 0.9, false)
		"cont_red": _tex(m, "hull", Color(1.3, 0.34, 0.24), 0.3, 1.4, false)
		"cont_blue": _tex(m, "hull", Color(0.36, 0.62, 1.05), 0.3, 1.4, false)
		"cont_teal": _tex(m, "hull", Color(0.28, 0.9, 0.82), 0.3, 1.4, false)
		"cont_ochre": _tex(m, "hull", Color(1.4, 1.0, 0.34), 0.3, 1.4, false)
		"sea":
			_flat(m, Color(0.04, 0.1, 0.14, 0.92), 0.5, 0.06) # bassin portuaire de nuit : reflets des lampadaires
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("0c3244")
		"rock_floor":
			_tex(m, "flesh", Color(0.3, 0.26, 0.32), 0.0, 0.16, true)
			_matte(m)
		"rock":
			_tex(m, "flesh", Color(0.3, 0.26, 0.33), 0.0, 0.3, false)
			_matte(m)
		"rock_top":
			_tex(m, "flesh", Color(0.36, 0.3, 0.4), 0.0, 0.25, true)
			_matte(m)
		"chitin":
			_tex(m, "flesh", Color(0.34, 0.22, 0.4), 0.1, 0.8, false)
			m.rim_enabled = true
			m.rim = 0.3
			m.emission_enabled = true
			m.emission = Color("1c0830")
		"bone": _flat(m, Color("a79c88"), 0.05, 0.55)
		"bile":
			_flat(m, Color(0.1, 0.04, 0.16, 0.9), 0.2, 0.04) # mares phosphorescentes du Nid
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("4a1ca8")
			m.emission_energy_multiplier = 0.3
		"steel": _flat(m, Color("6d7c88"), 0.85, 0.3)
		"armor": _flat(m, Color("3a4856"), 0.65, 0.36)
		"armor_dark": _flat(m, Color("2c3946"), 0.55, 0.45)
		"dark": _flat(m, Color("141c24"), 0.5, 0.6)
		"rubber": _flat(m, Color("1a1d20"), 0.0, 0.85)
		"brass": _flat(m, Color("a07a3c"), 0.9, 0.35)
		"glass":
			_flat(m, Color(0.45, 0.8, 0.95, 0.22), 0.1, 0.03)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("0a3a55")
			m.emission_energy_multiplier = 0.6
		"ocean":
			_flat(m, Color("0b3048"), 0.1, 0.05)
			m.emission_enabled = true
			m.emission = Color("0e4a6a")
			m.emission_energy_multiplier = 0.9
		"water":
			_flat(m, Color(0.02, 0.1, 0.14, 0.82), 0.4, 0.03) # eau sombre et profonde (refonte V1)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("06303e")
		"goo":
			_flat(m, Color("26103f"), 0.1, 0.18)
			m.emission_enabled = true
			m.emission = Color("6a2adf")
			m.emission_energy_multiplier = 0.45
			m.rim_enabled = true
			m.rim = 0.6
		"beam":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var g := Gradient.new()
			g.set_color(0, Color(0.35, 0.75, 1.0, 0.0))
			g.add_point(0.25, Color(0.35, 0.75, 1.0, 0.16))
			g.set_color(g.get_point_count() - 1, Color(0.35, 0.75, 1.0, 0.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill_to = Vector2(0, 1)
			gt.width = 4
			gt.height = 64
			m.albedo_texture = gt
			m.disable_receive_shadows = true
		_:
			# néons : cyan, ambre, rouge, vert, violet
			var c := {"led_cyan": Color("39d9ef"), "led_amber": Color("ffb547"), "led_red": Color("e5484d"),
				"led_green": Color("52c99a"), "led_violet": Color("9863f5")}.get(key, Color.MAGENTA) as Color
			_flat(m, c.darkened(0.4), 0.0, 0.4)
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.6
	_mats[key] = m
	return m

## Matériau texturé teinté (peaux aliennes, combinaisons) : `tex` = flesh, fabric, plate…
static func tinted(key: String, tex: String, tint: Color, metal := 0.1, emit := Color.BLACK, rim := 0.0) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX % [tex, "albedo"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX % [tex, "normal"])
	m.roughness_texture = load(TEX % [tex, "rough"])
	m.metallic = metal
	m.normal_scale = 0.45
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.6 if tex == "flesh" else 2.0)
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
	_mats[key] = m
	return m

## Matériau texturé (textures du kit) teinté ; `world` = projection dans le repère du monde (sols continus).
static func _tex(m: StandardMaterial3D, tex: String, tint: Color, metal: float, scale: float, world: bool) -> void:
	m.albedo_texture = load(TEX % [tex, "albedo"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX % [tex, "normal"])
	m.normal_scale = 0.7
	m.roughness_texture = load(TEX % [tex, "rough"])
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE * scale

## Roche mate : sans scintillement (pas de carte de rugosité, relief adouci).
static func _matte(m: StandardMaterial3D) -> void:
	m.roughness_texture = null
	m.roughness = 0.95
	m.normal_scale = 0.35

static func _flat(m: StandardMaterial3D, c: Color, metal: float, rough: float) -> void:
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough

# ---------- géométrie ----------

## Pavé aux arêtes chanfreinées (26 faces) : les reflets sur les chanfreins donnent l'aspect usiné.
static func bevel_box(s: Vector3, b: float) -> ArrayMesh:
	var key := "bb%s%s" % [s, b]
	if _meshes.has(key):
		return _meshes[key]
	var h := s / 2.0
	var q := h - Vector3.ONE * minf(b, minf(h.x, minf(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := func(a: int, va: float, c: int, vc: float, k: int, vk: float) -> Vector3:
		var v := Vector3.ZERO
		v[a] = va; v[c] = vc; v[k] = vk
		return v
	for a in 3:
		var c := (a + 1) % 3
		var k := (a + 2) % 3
		for sg in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[a] = sg
			_quad(st, P.call(a, h[a] * sg, c, -q[c], k, -q[k]), P.call(a, h[a] * sg, c, q[c], k, -q[k]),
				P.call(a, h[a] * sg, c, q[c], k, q[k]), P.call(a, h[a] * sg, c, -q[c], k, q[k]), n)
			for sc in [-1.0, 1.0]: # chanfrein entre la face a et la face c
				var ne := Vector3.ZERO
				ne[a] = sg; ne[c] = sc
				_quad(st, P.call(a, h[a] * sg, c, q[c] * sc, k, -q[k]), P.call(a, h[a] * sg, c, q[c] * sc, k, q[k]),
					P.call(a, q[a] * sg, c, h[c] * sc, k, q[k]), P.call(a, q[a] * sg, c, h[c] * sc, k, -q[k]), ne.normalized())
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_tri(st, Vector3(h.x * sx, q.y * sy, q.z * sz), Vector3(q.x * sx, h.y * sy, q.z * sz),
					Vector3(q.x * sx, q.y * sy, h.z * sz), Vector3(sx, sy, sz).normalized())
	var m := st.commit()
	_meshes[key] = m
	return m

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0: # Godot : faces avant dans le sens horaire
		var t := b; b = c; c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)

static func cyl(r_top: float, r_bot: float, h: float, seg := 14) -> CylinderMesh:
	var key := "cy%s_%s_%s_%d" % [r_top, r_bot, h, seg]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = seg; c.rings = 1
		_meshes[key] = c
	return _meshes[key]

## Assembleur : regroupe les parties d'une pièce par matériau, en un seul maillage multi-surfaces mis en cache.
class Piece:
	var tools := {}
	func add(mesh: Mesh, at: Vector3, m: String, rot := Vector3.ZERO, scl := Vector3.ONE) -> Piece:
		if not tools.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[m] = st
		var b := Basis.from_euler(rot * PI / 180.0).scaled(scl)
		(tools[m] as SurfaceTool).append_from(mesh, 0, Transform3D(b, at))
		return self
	func box(s: Vector3, at: Vector3, m: String, bevel := 0.02, rot := Vector3.ZERO) -> Piece:
		return add(AbyssKit.bevel_box(s, bevel), at, m, rot)
	## Tuyau droit entre deux points.
	func pipe(a: Vector3, b: Vector3, r: float, m: String) -> Piece:
		var d := b - a
		var mesh := AbyssKit.cyl(r, r, d.length(), 10)
		var up := Vector3.UP
		var axis := up.cross(d.normalized())
		var basis := Basis.IDENTITY if axis.length() < 0.001 else Basis(axis.normalized(), up.angle_to(d.normalized()))
		if not tools.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[m] = st
		(tools[m] as SurfaceTool).append_from(mesh, 0, Transform3D(basis, (a + b) / 2.0))
		return self
	func build() -> ArrayMesh:
		var out := ArrayMesh.new()
		for k in tools:
			var st: SurfaceTool = tools[k]
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, AbyssKit.mat(AbyssKit.remap.get(k, k)))
		return out

## Maillage partagé d'une pièce (construit une fois).
static func mesh_of(key: String, make: Callable) -> ArrayMesh:
	key = _key(key)
	if not _meshes.has(key):
		_meshes[key] = (make.call() as Piece).build()
	return _meshes[key]

## Pose toutes les copies d'une pièce en un seul objet (MultiMesh) : un appel de rendu au lieu d'un par case.
static func batch(parent: Node3D, key: String, make: Callable, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var ext := ModelKit.piece(key, theme) # modèle 3D définitif s'il a été livré (docs/MODELES-3D.md)
	mm.mesh = ext["mesh"] if ext else mesh_of(key, make)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Transform3D) * ext["xform"] if ext else xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	parent.add_child(mi)
	return mi

## Instancie une pièce (maillage partagé) ; `make` n'est appelé qu'une fois par clé.
static func spawn(key: String, make: Callable, parent: Node3D, at: Vector3, yaw := 0.0) -> MeshInstance3D:
	var ext := ModelKit.piece(key, theme)
	if ext:
		var gi := MeshInstance3D.new()
		gi.mesh = ext["mesh"]
		gi.transform = Transform3D(Basis(Vector3.UP, yaw), at) * (ext["xform"] as Transform3D)
		parent.add_child(gi)
		return gi
	key = _key(key)
	if not _meshes.has(key):
		_meshes[key] = (make.call() as Piece).build()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi

# ---------- pièces (KIT-001 murs, 002 portes, 003 sols, 004 structures, 005 couverts, 006/008 équipements) ----------

## Dalle de sol 1 m : tôle larmée chanfreinée ; variante sas avec bordure de danger.
static func floor_tile(evac: bool) -> Piece:
	var p := Piece.new().box(Vector3(1.0, 0.1, 1.0), Vector3(0, -0.05, 0), "floor", 0.0) # sans joint : sol continu
	if evac:
		for i in 4:
			var r := i * 90.0
			var off := Vector3(0, 0.003, 0.44).rotated(Vector3.UP, deg_to_rad(r))
			p.box(Vector3(0.98, 0.012, 0.09), off, "hazard", 0.004, Vector3(0, r, 0))
	return p

## Bande de danger sur le bord +Z d'une case (pourtour du sas uniquement, pas de quadrillage).
static func evac_edge() -> Piece:
	return Piece.new().box(Vector3(1.0, 0.012, 0.12), Vector3(0, 0.004, 0.44), "hazard", 0.004)

## Cloison destructible (KIT-001) : cadre porteur, panneau, faisceau de tuyaux et voyant ambre.
static func wall(h: float) -> Piece:
	if theme == "port":
		return _shed_wall(h)
	if theme == "nid":
		return _rib_wall(h)
	var p := Piece.new()
	for sx in [-0.43, 0.43]:
		p.box(Vector3(0.14, h, 0.34), Vector3(sx, h / 2, 0), "plate", 0.025)
	p.box(Vector3(0.74, h - 0.12, 0.18), Vector3(0, h / 2, 0), "plate", 0.03)
	p.box(Vector3(1.0, 0.1, 0.3), Vector3(0, h - 0.05, 0), "steel", 0.02)
	p.box(Vector3(1.0, 0.12, 0.32), Vector3(0, 0.06, 0), "dark", 0.02)
	p.box(Vector3(0.7, 0.06, 0.22), Vector3(0, h * 0.55, 0), "hazard", 0.01)
	for i in 3: # faisceau de tuyaux côté +Z
		var y := 0.35 + i * 0.13
		p.pipe(Vector3(-0.5, y, 0.14 + 0.05 * (i % 2)), Vector3(0.5, y, 0.14 + 0.05 * (i % 2)), 0.035 - i * 0.006, "steel" if i else "brass")
	for sx in [-0.3, 0.3]: # colliers de fixation
		p.box(Vector3(0.05, 0.46, 0.08), Vector3(sx, 0.48, 0.17), "dark", 0.01)
	p.pipe(Vector3(0.25, 0.2, -0.12), Vector3(0.25, h - 0.15, -0.12), 0.04, "steel") # descente verticale
	p.box(Vector3(0.1, 0.06, 0.05), Vector3(-0.2, h - 0.25, -0.1), "led_amber", 0.01)
	return p

## Coque de la station (KIT-004) : soubassement, montants, hublot sur l'océan ou panneau nervuré.
static func hull(window: bool) -> Piece:
	if theme == "port":
		return _quay(window)
	if theme == "nid":
		return _cave_wall(window)
	var p := Piece.new()
	p.box(Vector3(1.0, 0.95, 1.0), Vector3(0, 0.475, 0), "hull", 0.03)
	p.box(Vector3(1.02, 0.08, 1.02), Vector3(0, 0.95, 0), "steel", 0.02)
	p.box(Vector3(1.0, 0.25, 1.0), Vector3(0, 2.28, 0), "hull", 0.04)
	if window:
		for sx in [-0.44, 0.44]:
			for sz in [-0.44, 0.44]:
				p.box(Vector3(0.12, 1.2, 0.12), Vector3(sx, 1.58, sz), "plate", 0.03)
		p.box(Vector3(0.9, 1.15, 0.9), Vector3(0, 1.58, 0), "ocean", 0.0)
		p.box(Vector3(0.96, 1.2, 0.96), Vector3(0, 1.58, 0), "glass", 0.08)
	else:
		p.box(Vector3(1.0, 1.25, 1.0), Vector3(0, 1.58, 0), "hull", 0.03)
		for sx in [-0.3, 0.0, 0.3]:
			p.box(Vector3(0.08, 1.2, 1.04), Vector3(sx, 1.58, 0), "steel", 0.02)
	return p

## Port : cloison d'entrepôt en tôle ondulée rouillée, poteau d'acier, bande de signalisation.
static func _shed_wall(h: float) -> Piece:
	var p := Piece.new()
	p.box(Vector3(1.0, h - 0.1, 0.12), Vector3(0, h / 2, 0), "rust", 0.01)
	for i in 8: # ondulations
		var x := -0.44 + i * 0.126
		p.box(Vector3(0.05, h - 0.14, 0.16), Vector3(x, h / 2, 0), "rust", 0.015)
	for sx in [-0.47, 0.47]:
		p.box(Vector3(0.08, h, 0.2), Vector3(sx, h / 2, 0), "steel", 0.015)
	p.box(Vector3(1.0, 0.08, 0.22), Vector3(0, h - 0.04, 0), "steel", 0.015)
	p.box(Vector3(1.0, 0.22, 0.2), Vector3(0, 0.11, 0), "concrete", 0.02)
	p.box(Vector3(0.94, 0.08, 0.17), Vector3(0, 0.75, 0), "hazard", 0.005)
	return p

## Nid : pilier organique, côtes de chitine tressées, nervure lumineuse.
static func _rib_wall(h: float) -> Piece:
	var p := Piece.new()
	p.box(Vector3(0.9, 0.3, 0.4), Vector3(0, 0.15, 0), "rock", 0.08, Vector3(0, 0, 3))
	for i in 5:
		var x := -0.38 + i * 0.19
		var bend := 0.08 * (1 if i % 2 else -1)
		p.pipe(Vector3(x, 0.1, 0.0), Vector3(x + bend, h * 0.55, bend), 0.07 - 0.008 * (i % 2), "chitin")
		p.pipe(Vector3(x + bend, h * 0.55, bend), Vector3(x * 0.7, h, -bend * 0.5), 0.055, "chitin")
	p.pipe(Vector3(-0.45, h * 0.35, 0.12), Vector3(0.45, h * 0.62, 0.1), 0.03, "goo")
	p.pipe(Vector3(-0.42, h * 0.8, -0.1), Vector3(0.44, h * 0.48, -0.12), 0.025, "goo")
	p.box(Vector3(0.95, 0.16, 0.32), Vector3(0, h - 0.06, 0), "chitin", 0.06)
	return p

## Port : quai bétonné bas, garde-corps, lampadaire au sodium un module sur trois (sur le côté +Z : extérieur).
static func _quay(lamp: bool) -> Piece:
	var p := Piece.new()
	p.box(Vector3(1.0, 0.75, 1.0), Vector3(0, 0.375, 0), "concrete", 0.04)
	p.box(Vector3(1.04, 0.1, 1.04), Vector3(0, 0.8, 0), "concrete", 0.03)
	p.box(Vector3(1.0, 0.06, 0.06), Vector3(0, 0.6, -0.52), "hazard", 0.005)
	for sx in [-0.42, 0.42]:
		p.pipe(Vector3(sx, 0.85, 0.2), Vector3(sx, 1.85, 0.2), 0.03, "steel")
	p.pipe(Vector3(-0.5, 1.82, 0.2), Vector3(0.5, 1.82, 0.2), 0.025, "steel")
	p.pipe(Vector3(-0.5, 1.35, 0.2), Vector3(0.5, 1.35, 0.2), 0.018, "steel")
	if lamp:
		p.pipe(Vector3(0, 0.85, 0.25), Vector3(0, 3.3, 0.25), 0.05, "dark")
		p.pipe(Vector3(0, 3.3, 0.25), Vector3(0, 3.42, -0.25), 0.035, "dark")
		p.box(Vector3(0.26, 0.08, 0.36), Vector3(0, 3.4, -0.35), "dark", 0.02)
		p.box(Vector3(0.2, 0.02, 0.28), Vector3(0, 3.355, -0.35), "led_amber", 0.0)
	else:
		p.add(cyl(0.12, 0.15, 0.22, 10), Vector3(0.2, 0.96, -0.2), "dark") # bollard
	return p

## Nid : paroi de caverne, blocs de roche empilés, cristaux violets dans les variantes « lumineuses ».
static func _cave_wall(glow: bool) -> Piece:
	var p := Piece.new()
	p.box(Vector3(1.1, 1.0, 1.1), Vector3(0, 0.5, 0), "rock", 0.18, Vector3(0, 8, 2))
	p.box(Vector3(0.95, 0.85, 1.0), Vector3(0.06, 1.35, 0.05), "rock", 0.2, Vector3(4, -14, -5))
	p.box(Vector3(0.8, 0.7, 0.85), Vector3(-0.08, 2.05, 0.1), "rock", 0.22, Vector3(-6, 22, 6))
	p.box(Vector3(0.5, 0.35, 0.5), Vector3(0.18, 2.5, 0.15), "rock", 0.12, Vector3(10, 40, 0))
	if glow:
		for i in 3:
			var at := Vector3(-0.25 + i * 0.22, 0.9 + 0.35 * (i % 2), -0.5)
			p.add(PrismMesh.new(), at, "led_violet", Vector3(-25 + 20 * i, 30 * i, 15 - 15 * i), Vector3(0.12, 0.35 - 0.06 * i, 0.12))
	else:
		p.pipe(Vector3(-0.4, 0.2, -0.52), Vector3(0.1, 1.6, -0.5), 0.04, "goo")
	return p

## Caisse de munitions militaire (KIT-005) : couvert partiel.
static func crate() -> Piece:
	var p := Piece.new().box(Vector3(0.78, 0.58, 0.66), Vector3(0, 0.29, 0), "crate", 0.035)
	p.box(Vector3(0.82, 0.07, 0.7), Vector3(0, 0.6, 0), "crate", 0.02)
	for sx in [-0.39, 0.39]:
		for sz in [-0.33, 0.33]:
			p.box(Vector3(0.06, 0.6, 0.06), Vector3(sx, 0.31, sz), "steel", 0.012)
	for sx in [-0.42, 0.42]:
		p.box(Vector3(0.03, 0.05, 0.22), Vector3(sx, 0.42, 0), "dark", 0.01)
	p.box(Vector3(0.18, 0.04, 0.04), Vector3(0, 0.45, 0.34), "steel", 0.01)
	p.box(Vector3(0.3, 0.02, 0.01), Vector3(0, 0.2, 0.335), "led_cyan", 0.0)
	p.box(Vector3(0.5, 0.3, 0.44), Vector3(0.08, 0.79, -0.04), "crate", 0.03, Vector3(0, 12, 0)) # petite caisse empilée
	return p

## Barricade tactique (PROP-009) : dalle d'acier inclinée sur étais, bandes de danger. Couvert partiel.
static func barricade() -> Piece:
	var p := Piece.new()
	p.box(Vector3(0.92, 0.7, 0.1), Vector3(0, 0.38, 0.05), "plate", 0.025, Vector3(-12, 0, 0))
	p.box(Vector3(0.92, 0.12, 0.11), Vector3(0, 0.58, 0.0), "hazard", 0.01, Vector3(-12, 0, 0))
	p.box(Vector3(0.94, 0.06, 0.14), Vector3(0, 0.74, -0.03), "steel", 0.015, Vector3(-12, 0, 0))
	for sx in [-0.36, 0.36]:
		p.box(Vector3(0.08, 0.06, 0.5), Vector3(sx, 0.03, -0.12), "dark", 0.01)
		p.box(Vector3(0.06, 0.55, 0.06), Vector3(sx, 0.3, -0.2), "steel", 0.01, Vector3(32, 0, 0))
	p.box(Vector3(0.05, 0.03, 0.01), Vector3(0.3, 0.45, 0.125), "led_amber", 0.0, Vector3(-12, 0, 0))
	return p

## Console de laboratoire (KIT-006 / KIT-008) : couvert partiel avec écran incliné.
static func console(green: bool) -> Piece:
	var scr := "screen_green" if green else "screen"
	var p := Piece.new().box(Vector3(0.8, 0.7, 0.5), Vector3(0, 0.35, 0), "plate", 0.03)
	p.box(Vector3(0.84, 0.06, 0.6), Vector3(0, 0.73, 0.04), "steel", 0.02, Vector3(-12, 0, 0))
	p.box(Vector3(0.6, 0.02, 0.18), Vector3(0, 0.77, 0.14), "dark", 0.005, Vector3(-12, 0, 0)) # clavier
	p.box(Vector3(0.74, 0.44, 0.06), Vector3(0, 1.0, -0.16), "dark", 0.02, Vector3(-18, 0, 0))
	p.box(Vector3(0.66, 0.36, 0.01), Vector3(0, 1.0, -0.125), scr, 0.0, Vector3(-18, 0, 0))
	for i in 4:
		p.box(Vector3(0.6, 0.02, 0.01), Vector3(0, 0.15 + i * 0.07, 0.255), "dark", 0.0) # ouïes
	p.box(Vector3(0.05, 0.05, 0.02), Vector3(0.3, 0.62, 0.255), "led_green" if green else "led_cyan", 0.0)
	p.pipe(Vector3(-0.3, 0.02, -0.25), Vector3(-0.3, 0.02, -0.55), 0.025, "rubber")
	return p

## Passerelle (KIT-004) : soubassement plein, caillebotis, nez de dalle ambre.
static func deck_high() -> Piece:
	var p := Piece.new().box(Vector3(0.98, 0.92, 0.98), Vector3(0, 0.46, 0), "hull", 0.02)
	p.box(Vector3(1.0, 0.07, 1.0), Vector3(0, 0.965, 0), "grate", 0.01)
	return p

## Garde-corps sur un bord de passerelle (le bord est en +Z ; tourner la pièce pour les autres côtés).
static func railing() -> Piece:
	if theme == "nid": # bord de corniche : lèvre de roche irrégulière
		var r := Piece.new()
		for i in 3:
			r.box(Vector3(0.36, 0.16 + 0.06 * (i % 2), 0.16), Vector3(-0.33 + i * 0.33, 1.02, 0.42), "rock", 0.05, Vector3(0, 12 * (i - 1), 8 * (i - 1)))
		return r
	var p := Piece.new()
	p.pipe(Vector3(-0.5, 1.95, 0.46), Vector3(0.5, 1.95, 0.46), 0.022, "steel")
	p.pipe(Vector3(-0.5, 1.5, 0.46), Vector3(0.5, 1.5, 0.46), 0.016, "steel")
	p.pipe(Vector3(0.45, 1.0, 0.46), Vector3(0.45, 1.97, 0.46), 0.025, "steel")
	p.box(Vector3(1.0, 0.1, 0.025), Vector3(0, 1.08, 0.47), "hazard", 0.004)
	p.box(Vector3(1.0, 0.015, 0.03), Vector3(0, 1.0, 0.49), "led_cyan", 0.0)
	return p

## Volée de marches de `z0` à `z1` montant vers +X (KIT-004).
static func stairs(z0: float, z1: float) -> Piece:
	var p := Piece.new()
	var n := 4
	for i in n:
		var top := z0 + (z1 - z0) * (i + 1) / n
		p.box(Vector3(1.0 / n, top - z0 + 0.04, 0.84), Vector3(-0.5 + (i + 0.5) / n, (top + z0) / 2.0 - 0.02, 0), "dark", 0.0)
		p.box(Vector3(1.0 / n + 0.01, 0.04, 0.84), Vector3(-0.5 + (i + 0.5) / n, top - 0.02, 0), "grate", 0.006)
		p.box(Vector3(0.02, 0.03, 0.84), Vector3(-0.5 + (i + 1.0) / n - 0.01, top - 0.005, 0), "hazard", 0.0)
	var ang := rad_to_deg(atan2(z1 - z0, 1.0))
	for sz in [-0.45, 0.45]:
		p.box(Vector3(1.12, 0.14, 0.06), Vector3(0, (z0 + z1) / 2.0 + 0.02, sz), "steel", 0.015, Vector3(0, 0, ang))
		p.pipe(Vector3(-0.5, z0 + 0.95, sz), Vector3(0.5, z1 + 0.95, sz), 0.02, "steel")
	return p

## Bassin : fond en caillebotis immergé + surface d'eau.
static func pool() -> Piece:
	if theme == "port": # eau du bassin portuaire : profonde, sans fond visible
		return Piece.new().box(Vector3(1.0, 0.03, 1.0), Vector3(0, -0.16, 0), "sea", 0.0)
	var p := Piece.new().box(Vector3(1.0, 0.06, 1.0), Vector3(0, -0.2, 0), "grate", 0.0)
	p.box(Vector3(1.0, 0.03, 1.0), Vector3(0, -0.02, 0), "water", 0.0)
	return p

## Berceau de confinement Némésis (ENV-007) : socle praticable, anneau émetteur suspendu, cuve brisée.
static func cradle() -> Piece:
	var p := Piece.new()
	p.add(cyl(0.48, 0.5, 0.12, 24), Vector3(0, 0.06, 0), "steel")
	p.add(cyl(0.4, 0.4, 0.02, 24), Vector3(0, 0.125, 0), "led_cyan")
	p.add(cyl(0.36, 0.36, 0.03, 24), Vector3(0, 0.14, 0), "dark")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38; ring.outer_radius = 0.48; ring.rings = 24; ring.ring_segments = 8
	p.add(ring, Vector3(0, 2.25, 0), "steel")
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 0.36; ring2.outer_radius = 0.39; ring2.rings = 24; ring2.ring_segments = 6
	p.add(ring2, Vector3(0, 2.2, 0), "led_cyan")
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var d := Vector3(cos(a), 0, sin(a))
		p.pipe(d * 0.44 + Vector3(0, 2.25, 0), d * 0.44 + Vector3(0, 3.6, 0), 0.04, "steel")
		p.pipe(d * 0.5 + Vector3(0, 0.1, 0), d * 0.52 + Vector3(0, 0.55, 0), 0.03, "dark") # griffes du socle
	# éclats de la cuve brisée, figés au sol
	for i in 7:
		var a := TAU * i / 7.0
		var r := 0.55 + 0.12 * (i % 3)
		p.box(Vector3(0.18 - 0.02 * (i % 3), 0.01, 0.1), Vector3(cos(a) * r, 0.01, sin(a) * r), "glass", 0.0, Vector3(0, rad_to_deg(a) * 1.7, 0))
	p.add(cyl(0.47, 0.47, 0.35 + 0.0, 24), Vector3(0, 0.3, 0), "glass") # base de cuve restée en place
	return p

## Excroissance alienne (KIT-009) : tendrils violets au sol.
static func tendrils(seed_i: int) -> Piece:
	var p := Piece.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	for k in 3:
		var at := Vector3(rng.randf_range(-0.3, 0.3), 0.02, rng.randf_range(-0.3, 0.3))
		var dir := rng.randf() * TAU
		for s in 5:
			dir += rng.randf_range(-0.7, 0.7)
			var nxt := at + Vector3(cos(dir), 0, sin(dir)) * 0.16
			p.pipe(at, nxt, 0.045 - s * 0.007, "goo")
			at = nxt
		p.add(cyl(0.0, 0.09, 0.12, 8), at - Vector3(0, -0.04, 0), "goo")
	var blob := SphereMesh.new()
	blob.radius = 0.2; blob.height = 0.16; blob.radial_segments = 12; blob.rings = 6
	p.add(blob, Vector3(0, 0.02, 0), "goo")
	return p

## Faisceau de lumière (faux rayons volumétriques sous les hublots).
static func light_beam() -> Piece:
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 3.2)
	return Piece.new().add(q, Vector3(0, 1.4, 0.9), "beam", Vector3(-35, 0, 0))

# ---------- objets des planches KIT / PROP de Max (sprites détourés, tools/extract_views.py) ----------

const PROP := "res://assets/props/%s.png"
## Couverts bas : [sprite, hauteur en m, sprite détruit]. Choix déterministe par case.
const COVERS := [["p007_s1", 0.9, "p007_s4"], ["k005_1", 1.1, "k010_2"], ["p009_s1", 1.0, "p009_s4"], ["k006_4", 1.35, "k010_2"],
	["k008_3", 1.5, "k010_2"], ["k006_6", 1.3, "k010_2"], ["k005_5", 1.0, "k010_2"], ["k008_6", 0.8, "k010_2"],
	["p008_s2", 0.95, "k010_2"], ["p005_s2", 1.05, "k010_2"], ["k007_1", 1.1, "k010_2"], ["k007_5", 1.05, "k010_2"]]

const COVERS_PORT := [["k005_1", 1.1, "k010_2"], ["k005_4", 0.8, "k010_2"], ["p007_s1", 0.9, "p007_s4"], ["p009_s2", 1.0, "p009_s4"],
	["k005_5", 1.0, "k010_2"], ["p008_s1", 0.95, "k010_2"], ["k005_2", 1.0, "k010_2"], ["p004_s4", 1.15, "k010_2"]]
const COVERS_NID := [["k009_4", 1.35, "k010_5"], ["k009_6", 1.25, "k010_5"], ["k010_5", 0.85, "k010_5"], ["k009_2", 1.5, "k010_5"], ["k009_1", 1.25, "k010_5"]]

## Couverts bas du thème en cours.
static func covers() -> Array:
	return {"port": COVERS_PORT, "nid": COVERS_NID}.get(theme, COVERS)

## Objet peint, debout face à la caméra (axe vertical), éclairé par la scène. `height` = hauteur à l'écran (m).
static func prop(name: String, height: float, shadow := false) -> Node3D:
	var model := ModelKit.prop_for(name, height, theme) # modèle 3D définitif s'il a été livré
	if model:
		return model
	var t: Texture2D = load(PROP % name)
	var sp := Sprite3D.new()
	sp.texture = t
	sp.pixel_size = height / float(t.get_height())
	sp.offset = Vector2(0, t.get_height() / 2.0)
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.shaded = false # éclairage peint de la planche conservé : lisible même dans les zones sombres
	sp.double_sided = true
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# teinte d'ambiance : acier froid (station), sodium de nuit (port), violet (nid)
	sp.modulate = {"port": Color(0.86, 0.82, 0.76), "nid": Color(0.78, 0.7, 0.88)}.get(theme, Color(0.78, 0.84, 0.92))
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.scale = Vector3(1, 1.18, 1) # compense le raccourci de la caméra plongeante (35°)
	return sp

## Débris d'une cloison détruite.
static func rubble_chunk(s: float) -> ArrayMesh:
	return bevel_box(Vector3(s, s * 0.7, s * 0.9), s * 0.15)
