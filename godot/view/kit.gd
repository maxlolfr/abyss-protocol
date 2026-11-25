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
## matériaux à shader (phase 3) : eau, fond de bassin à caustiques, vue sur l'océan
const SHADERS := {"water": "water", "pool_floor": "caustic_floor", "ocean": "ocean"}

# ---------- matériaux ----------

## Matériaux du kit, créés une fois. Couleurs : bible artistique V3.1.
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	if key in SHADERS:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://view/shaders/%s.gdshader" % SHADERS[key])
		sm.set_shader_parameter("caus", load("res://assets/textures/caustics.png"))
		sm.set_shader_parameter("nmap", load("res://assets/textures/water_normal.png"))
		sm.set_shader_parameter("albedo_tex", load(TEX % ["grate", "albedo"]))
		_mats[key] = sm
		return sm
	var m := StandardMaterial3D.new()
	match key:
		"grate_cut":
			m.albedo_texture = load("res://assets/textures/fx_grate_cut.png")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE
			m.albedo_color = Color(0.5, 0.52, 0.55)
			m.metallic = 0.6
			m.roughness = 0.62
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"ao":
			# ombre de contact peinte (phase 3) : assombrit le pied des parois, sans calcul d'éclairage
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var ag := Gradient.new()
			ag.set_color(0, Color(0, 0, 0, 0.62))
			ag.set_color(1, Color(0, 0, 0, 0.0))
			var at := GradientTexture2D.new()
			at.gradient = ag
			at.fill_to = Vector2(0, 1)
			at.width = 4
			at.height = 64
			m.albedo_texture = at
			m.disable_receive_shadows = true
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
			var c := {"led_cyan": Color("39d9ef"), "led_cyan_soft": Color("1f7f8f"), "led_amber": Color("ffb547"), "led_red": Color("e5484d"),
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
			out.surface_set_material(out.get_surface_count() - 1, AbyssKit.mat(k))
		return out

## Maillage partagé d'une pièce (construit une fois).
static func mesh_of(key: String, make: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = (make.call() as Piece).build()
	return _meshes[key]

## Pose toutes les copies d'une pièce en un seul objet (MultiMesh) : un appel de rendu au lieu d'un par case.
static func batch(parent: Node3D, key: String, make: Callable, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_of(key, make)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	parent.add_child(mi)
	return mi

## Instancie une pièce (maillage partagé) ; `make` n'est appelé qu'une fois par clé.
static func spawn(key: String, make: Callable, parent: Node3D, at: Vector3, yaw := 0.0) -> MeshInstance3D:
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

## Coque de la station (phase 3, d'après KIT-001 et ENV-007) : paroi monumentale en relief.
## Soubassement, pilastre porteur, panneau en retrait encadré de lisses, corniche et conduite haute.
## Variantes : 0 = panneau et faisceau de tuyaux, 1 = grille de ventilation + lampe-cage ambre, 2 = grande baie sur l'océan.
## L'intérieur de la salle est du côté -Z (la pièce est tournée pour que +Z regarde dehors).
static func hull(variant: int) -> Piece:
	var p := Piece.new()
	var H := 2.75
	p.box(Vector3(1.0, H, 0.62), Vector3(0, H / 2, 0.19), "hull", 0.0) # masse de la paroi (côté extérieur)
	p.box(Vector3(1.0, 0.03, 1.0), Vector3(0, H + 0.015, 0.0), "dark", 0.0) # chaperon sombre (lecture en vue de dessus)
	p.box(Vector3(1.0, 0.42, 0.2), Vector3(0, 0.21, -0.27), "armor_dark", 0.03) # soubassement
	p.box(Vector3(1.0, 0.05, 0.24), Vector3(0, 0.44, -0.27), "steel", 0.015)
	p.box(Vector3(0.16, H, 0.26), Vector3(-0.42, H / 2, -0.24), "plate", 0.03) # pilastre porteur
	p.box(Vector3(0.2, 0.3, 0.3), Vector3(-0.42, H - 0.5, -0.27), "plate", 0.04) # chapiteau
	p.box(Vector3(1.0, 0.24, 0.42), Vector3(0, H - 0.12, -0.17), "plate", 0.03) # corniche
	p.box(Vector3(1.0, 0.025, 0.02), Vector3(0, H - 0.27, -0.385), "led_cyan_soft", 0.0) # filet lumineux
	p.pipe(Vector3(-0.5, H - 0.42, -0.31), Vector3(0.5, H - 0.42, -0.31), 0.06, "steel")
	p.pipe(Vector3(-0.5, H - 0.55, -0.33), Vector3(0.5, H - 0.55, -0.33), 0.035, "brass")
	match variant:
		0:
			p.box(Vector3(0.68, 1.5, 0.08), Vector3(0.08, 1.25, -0.16), "plate", 0.02) # panneau en retrait
			p.box(Vector3(0.84, 0.07, 0.12), Vector3(0.08, 2.03, -0.18), "steel", 0.015)
			p.box(Vector3(0.84, 0.07, 0.12), Vector3(0.08, 0.5, -0.18), "steel", 0.015)
			for i in 4: # faisceau de tuyaux (KIT-001 n°4)
				var y := 0.68 + i * 0.1
				p.pipe(Vector3(-0.5, y, -0.27 - (i % 2) * 0.03), Vector3(0.5, y, -0.27 - (i % 2) * 0.03), 0.032 - (i % 2) * 0.008, "steel" if i % 3 else "brass")
			for sx in [-0.15, 0.3]:
				p.box(Vector3(0.05, 0.5, 0.1), Vector3(sx, 0.83, -0.31), "dark", 0.01)
			p.pipe(Vector3(0.3, 0.45, -0.25), Vector3(0.3, 2.0, -0.25), 0.045, "steel") # descente verticale
			p.box(Vector3(0.14, 0.2, 0.06), Vector3(0.0, 1.55, -0.21), "dark", 0.01) # boîtier
			p.box(Vector3(0.04, 0.04, 0.02), Vector3(0.03, 1.6, -0.24), "led_green", 0.0)
		1:
			p.box(Vector3(0.68, 1.5, 0.08), Vector3(0.08, 1.25, -0.16), "plate", 0.02)
			p.box(Vector3(0.5, 0.62, 0.05), Vector3(0.1, 1.0, -0.21), "dark", 0.01) # grille de ventilation
			for i in 7:
				p.box(Vector3(0.48, 0.03, 0.05), Vector3(0.1, 0.74 + i * 0.087, -0.235), "steel", 0.005, Vector3(25, 0, 0))
			p.box(Vector3(0.84, 0.07, 0.12), Vector3(0.08, 2.03, -0.18), "steel", 0.015)
			# lampe-cage ambre (ENV-007) au-dessus de la grille
			p.add(cyl(0.07, 0.07, 0.16, 10), Vector3(0.1, 1.78, -0.29), "led_amber")
			p.add(cyl(0.09, 0.09, 0.04, 10), Vector3(0.1, 1.68, -0.29), "dark")
			p.add(cyl(0.09, 0.09, 0.04, 10), Vector3(0.1, 1.88, -0.29), "dark")
			for a in 4:
				var d := Vector3(cos(a * PI / 2), 0, sin(a * PI / 2)) * 0.085
				p.box(Vector3(0.015, 0.2, 0.015), Vector3(0.1, 1.78, -0.29) + d, "dark", 0.0)
		2:
			# grande baie : cadre épais chanfreiné, vitre, océan derrière
			p.box(Vector3(1.0, 0.5, 0.3), Vector3(0, 0.45 + 0.25, -0.15), "plate", 0.03) # allège
			p.box(Vector3(1.0, 0.18, 0.34), Vector3(0, 0.96, -0.2), "steel", 0.05) # appui
			p.box(Vector3(1.0, 0.2, 0.34), Vector3(0, 2.34, -0.2), "steel", 0.05) # linteau
			for sx in [-0.46, 0.46]:
				p.box(Vector3(0.08, 1.5, 0.3), Vector3(sx, 1.65, -0.18), "steel", 0.03)
			p.box(Vector3(0.05, 1.3, 0.06), Vector3(0.12, 1.65, -0.1), "steel", 0.01) # meneau
			p.box(Vector3(0.92, 1.3, 0.02), Vector3(0, 1.65, -0.08), "glass", 0.0)
			var q := QuadMesh.new()
			q.size = Vector2(1.0, 1.6)
			p.add(q, Vector3(0, 1.65, 0.45), "ocean", Vector3(0, 180, 0))
			for sx in [-0.5, 0.5]: # joues intérieures (embrasure)
				p.box(Vector3(0.02, 1.4, 0.6), Vector3(sx * 0.98, 1.65, 0.18), "hull", 0.0)
	return p

## Ombre de contact au pied d'une paroi : bande dégradée posée au sol, côté -Z (intérieur).
static func ao_edge() -> Piece:
	var q := PlaneMesh.new()
	q.size = Vector2(1.0, 0.7)
	return Piece.new().add(q, Vector3(0, 0.012, -0.85), "ao", Vector3(0, 180, 0))

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
## Phase 3 : la mezzanine repose sur une ossature visible (poutres en I, entretoises, panneaux en retrait).
static func deck_high() -> Piece:
	var p := Piece.new().box(Vector3(0.8, 0.78, 0.8), Vector3(0, 0.45, 0), "armor_dark", 0.02) # noyau en retrait
	p.box(Vector3(1.0, 0.14, 1.0), Vector3(0, 0.86, 0), "plate", 0.03) # longeron sous plancher
	p.box(Vector3(1.0, 0.07, 1.0), Vector3(0, 0.965, 0), "grate", 0.01)
	for sx in [-0.44, 0.44]:
		for sz in [-0.44, 0.44]:
			p.box(Vector3(0.12, 0.84, 0.12), Vector3(sx, 0.42, sz), "steel", 0.02) # poteaux
	for r in 4: # entretoises en X sur chaque face
		var rot := r * 90.0
		var o := Vector3(0, 0, 0.43).rotated(Vector3.UP, deg_to_rad(rot))
		p.box(Vector3(1.05, 0.05, 0.04), o + Vector3(0, 0.45, 0), "dark", 0.01, Vector3(0, rot, 38))
		p.box(Vector3(1.05, 0.05, 0.04), o + Vector3(0, 0.45, 0), "dark", 0.01, Vector3(0, rot, -38))
	p.box(Vector3(1.0, 0.1, 1.0), Vector3(0, 0.05, 0), "dark", 0.01) # semelle
	return p

## Garde-corps sur un bord de passerelle (le bord est en +Z ; tourner la pièce pour les autres côtés).
static func railing() -> Piece:
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

## Bassin (phase 3) : fosse de 0,7 m, fond à caustiques, eau animée au shader.
static func pool() -> Piece:
	var p := Piece.new().box(Vector3(1.0, 0.06, 1.0), Vector3(0, -0.7, 0), "pool_floor", 0.0)
	var q := PlaneMesh.new()
	q.size = Vector2(1.0, 1.0)
	p.add(q, Vector3(0, -0.09, 0), "water")
	return p

## Paroi de bassin ou de caniveau sur le bord +Z : béton d'acier sombre, margelle à bande de danger.
static func pit_side(depth: float, lip: bool) -> Piece:
	var p := Piece.new().box(Vector3(1.0, depth, 0.06), Vector3(0, -depth / 2, 0.47), "armor_dark", 0.0)
	p.box(Vector3(1.0, 0.04, 0.04), Vector3(0, -depth * 0.45, 0.43), "steel", 0.0) # cornière
	if lip:
		p.box(Vector3(1.0, 0.05, 0.12), Vector3(0, 0.0, 0.47), "steel", 0.015)
		p.box(Vector3(1.0, 0.012, 0.06), Vector3(0, 0.03, 0.47), "hazard", 0.003)
	return p

## Caniveau technique (ENV-007) : fosse sous caillebotis ajouré, conduites et lueur cyan au fond.
static func trench() -> Piece:
	var p := Piece.new().box(Vector3(1.0, 0.04, 1.0), Vector3(0, -0.5, 0), "dark", 0.0)
	p.pipe(Vector3(-0.5, -0.36, -0.2), Vector3(0.5, -0.36, -0.2), 0.09, "steel")
	p.pipe(Vector3(-0.5, -0.4, 0.12), Vector3(0.5, -0.4, 0.12), 0.06, "brass")
	p.pipe(Vector3(-0.5, -0.42, 0.32), Vector3(0.5, -0.42, 0.32), 0.04, "steel")
	p.box(Vector3(1.0, 0.02, 0.03), Vector3(0, -0.47, 0.0), "led_cyan", 0.0)
	for sx in [-0.25, 0.25]:
		p.box(Vector3(0.06, 0.2, 0.9), Vector3(sx, -0.4, 0.0), "dark", 0.01) # supports
	p.box(Vector3(1.0, 0.03, 1.0), Vector3(0, -0.02, 0), "grate_cut", 0.0)
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

## Objet peint, debout face à la caméra (axe vertical), éclairé par la scène. `height` = hauteur à l'écran (m).
static func prop(name: String, height: float, shadow := false) -> Sprite3D:
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
	sp.modulate = Color(0.78, 0.84, 0.92) # teinte froide de la station
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.scale = Vector3(1, 1.18, 1) # compense le raccourci de la caméra plongeante (35°)
	return sp

## Débris d'une cloison détruite.
static func rubble_chunk(s: float) -> ArrayMesh:
	return bevel_box(Vector3(s, s * 0.7, s * 0.9), s * 0.15)
