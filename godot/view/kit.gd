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
		"screen", "screen_green":
			m.albedo_texture = load(TEX % ["screen", "albedo"])
			m.emission_enabled = true
			m.emission_texture = load(TEX % ["screen", "emission"])
			m.emission = Color(0.55, 1.0, 0.7) if key == "screen_green" else Color.WHITE
			m.emission_energy_multiplier = 1.1
			m.roughness = 0.45
			m.metallic = 0.0
		"steel": _flat(m, Color("6d7c88"), 0.85, 0.3)
		"armor": _flat(m, Color("5d6e7c"), 0.6, 0.38)
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
			_flat(m, Color(0.05, 0.32, 0.4, 0.72), 0.3, 0.04)
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
	var p := Piece.new().box(Vector3(0.99, 0.1, 0.99), Vector3(0, -0.05, 0), "floor", 0.012)
	if evac:
		for i in 4:
			var r := i * 90.0
			var off := Vector3(0, 0.003, 0.44).rotated(Vector3.UP, deg_to_rad(r))
			p.box(Vector3(0.98, 0.012, 0.09), off, "hazard", 0.004, Vector3(0, r, 0))
	return p

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

## Coque de la station (KIT-004) : soubassement, montants, hublot sur l'océan ou panneau nervuré.
static func hull(window: bool) -> Piece:
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
	p.box(Vector3(0.5, 0.3, 0.44), Vector3(0.08, 0.79, -0.04), "crate", 0.03, Vector3(0, 12, 0)) # petite caisse empilée
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

## Débris d'une cloison détruite.
static func rubble_chunk(s: float) -> ArrayMesh:
	return bevel_box(Vector3(s, s * 0.7, s * 0.9), s * 0.15)
