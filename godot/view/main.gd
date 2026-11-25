extends Node3D
## Rendu 3D isométrique (vertical slice) : laboratoire sous-marin, éclairage cyan/ambre, contamination violette,
## vitres sur l'océan, coupe automatique des murs côté caméra, brouillard de guerre, effets de tir et de destruction,
## caméra cinématique facultative. Lit AbyssBattle et rejoue ses événements ; n'écrit jamais dans l'état.

const SAVE_PATH := "user://abyss_save.json"

var battle: AbyssBattle
var hud: AbyssHud
var pivot := Node3D.new()
var yaw := Node3D.new()
var pitch := Node3D.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var unit_nodes := {}
var wall_nodes := {} # idx -> Node3D (cloisons et caisses destructibles)
var cell_nodes := {} # idx -> Array[Node3D] (pour le brouillard)
var hull_nodes: Array = [] # [Node3D, normale]
var fog_quads := {}
var overlay := Node3D.new()
var artifact_node: Node3D
var selected: AbyssUnit
var mode := "move"
var pending := {}
var busy := false
var speed := 1.0
var cine := true
var yaw_step := 0
var touches := {}
var pinch_d := 0.0
var drag_moved := false
var drag_from := Vector2.ZERO
var mats := {}

func _ready() -> void:
	battle = _load_or_new()
	_build_env()
	_build_map()
	_build_props()
	for u in battle.units:
		_build_unit(u)
	add_child(overlay)
	_build_camera()
	hud = AbyssHud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	hud.confirm.connect(_confirm)
	hud.cancel.connect(func(): _select(selected))
	hud.select_unit.connect(func(id): _select(battle.unit(id)))
	hud.rotate_cam.connect(_rotate)
	hud.setting.connect(_on_setting)
	hud.restart.connect(func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		get_tree().reload_current_scene())
	for s in battle.living(true):
		_select(s)
		break
	_sync()
	_update_cutaway()
	if battle.turn > 1 or battle.living(true).any(func(u): return u.tu < u.max_tu):
		hud.flash("Partie reprise (tour %d)" % battle.turn, AbyssHud.CYAN)
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('autoplay')"):
		_autoplay()

func _query(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('%s') || ''" % key)
	return String(v) if v else ""

## Reprise automatique d'une partie en cours (sauvegarde locale versionnée), sinon nouvelle mission.
func _load_or_new() -> AbyssBattle:
	var seed := _query("seed")
	if seed == "" and FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			var b := AbyssBattle.from_dict(d)
			if b and b.outcome == "ongoing":
				return b
	return AbyssBattle.new(seed if seed != "" else "thetis-%d" % (int(Time.get_unix_time_from_system()) % 100000))

func _save() -> void:
	if battle.outcome != "ongoing":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(battle.to_dict()))

# ---------- matériaux et primitives ----------

func _mat(key: String, color: Color, metal := 0.4, rough := 0.6, emit := Color.BLACK, alpha := 1.0) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.metallic = metal
	m.roughness = rough
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 1.8
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cell_pos(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, battle.grid.z(p), p.y + 0.5)

func _track(p: Vector2i, n: Node3D) -> void:
	var k := battle.grid.idx(p)
	if not cell_nodes.has(k):
		cell_nodes[k] = []
	cell_nodes[k].append(n)

# ---------- décor ----------

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070d16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a4a60")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("0a2232")
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# lumière froide filtrée par la surface, ombres dynamiques
	sun.light_color = Color("a8dcff")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	# fond marin : plancher océanique, roches et neige marine hors de la station
	var w := battle.grid.w
	var h := battle.grid.h
	var sea := _box(self, Vector3(80, 0.2, 80), Vector3(w / 2.0, -3.2, h / 2.0), _mat("seabed", Color("0c1c2a"), 0, 1))
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rock := _mat("rock", Color("16283a"), 0.1, 0.9)
	for i in 14:
		var a := i * 0.45
		var r := 13.0 + (i % 4) * 2.5
		var c := CylinderMesh.new(); c.top_radius = 0.3 + (i % 3) * 0.3; c.bottom_radius = 1.0 + (i % 2); c.height = 2 + (i % 5)
		_mesh(self, c, Vector3(w / 2.0 + cos(a) * r, -3 + c.height / 2.0, h / 2.0 + sin(a) * r), rock)
	var snow := CPUParticles3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.02; sm.height = 0.04; sm.radial_segments = 4; sm.rings = 2
	snow.mesh = sm
	snow.material_override = _mat("snow", Color("c8e6f5"), 0, 1, Color("6fa8c0"), 0.6)
	snow.amount = 140
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18, 1, 18)
	snow.direction = Vector3(0.2, -1, 0.1)
	snow.gravity = Vector3(0, -0.05, 0)
	snow.initial_velocity_min = 0.1
	snow.initial_velocity_max = 0.3
	snow.position = Vector3(w / 2.0, 6, h / 2.0)
	add_child(snow)

func _build_map() -> void:
	var g := battle.grid
	var floor_a := _mat("floorA", Color("2e4252"), 0.65, 0.4)
	var floor_b := _mat("floorB", Color("29394a"), 0.65, 0.45)
	var evac := _mat("evacFloor", Color("3d3a28"), 0.5, 0.5)
	var seam := _mat("seam", Color("39d9ef"), 0, 1, Color("1aa8c0"))
	var plat := _mat("plat", Color("465766"), 0.75, 0.3)
	var under := _mat("under", Color("141e28"), 0.5, 0.7)
	var wall := _mat("wall", Color("4a5d6c"), 0.6, 0.45)
	var hull := _mat("hull", Color("223240"), 0.55, 0.55)
	var stripe := _mat("stripe", Color("ffb547"), 0, 1, Color("ff9a2a"))
	stripe.emission_energy_multiplier = 0.5
	var glass := _mat("glass", Color("1d6a8a"), 0.1, 0.05, Color("0a3a55"), 0.55)
	var water := _mat("water", Color("0e6a80"), 0.1, 0.05, Color("0a4a60"), 0.7)
	var crate := _mat("crate", Color("5a4a34"), 0.3, 0.7)
	var console := _mat("console", Color("2b3c4a"), 0.7, 0.35)
	var screen := _mat("screen", Color("39d9ef"), 0, 0.2, Color("39d9ef"))
	var term := _mat("term", Color("52c99a"), 0, 0.2, Color("52c99a"))
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			var t := g.tile(p)
			var z := g.z(p)
			var c := Vector3(x + 0.5, z, y + 0.5)
			if t == AbyssGrid.T.HULL:
				# coque : haute avec une vitre sur l'océan ; abaissée automatiquement côté caméra
				var hn := Node3D.new()
				hn.position = Vector3(x + 0.5, 0, y + 0.5)
				add_child(hn)
				_box(hn, Vector3(1, 2.4, 1), Vector3(0, 1.2, 0), hull)
				var inner := Vector3(clampi(7 - x, -1, 1) if x == 0 or x == g.w - 1 else 0, 0, clampi(7 - y, -1, 1) if y == 0 or y == g.h - 1 else 0)
				if (x + y) % 3 == 0 and (x == 0 or y == 0 or x == g.w - 1 or y == g.h - 1):
					_box(hn, Vector3(0.7 if inner.x == 0 else 1.02, 0.9, 0.7 if inner.z == 0 else 1.02), Vector3(0, 1.4, 0), glass)
				_box(hn, Vector3(1.01, 0.04, 1.01), Vector3(0, 0.9, 0), _mat("hullTrim", Color("2b3d4c"), 0.8, 0.3))
				var n := Vector3(-1 if x == 0 else (1 if x == g.w - 1 else 0), 0, -1 if y == 0 else (1 if y == g.h - 1 else 0))
				hull_nodes.append([hn, n])
				continue
			if z >= 1.0:
				_track(p, _box(self, Vector3(1, 1, 1), Vector3(c.x, 0.5, c.z), under))
			elif t == AbyssGrid.T.STAIRS:
				_track(p, _box(self, Vector3(1, 0.25, 1), Vector3(c.x, 0.125, c.z), under))
				_track(p, _box(self, Vector3(0.5, 0.25, 1), Vector3(c.x + 0.25, 0.375, c.z), under))
			var fm: Material = plat if z >= 1.0 else (evac if battle.in_evac(p) else (floor_a if (x + y) % 2 else floor_b))
			var f := _box(self, Vector3(0.97, 0.08, 0.97), c - Vector3(0, 0.04, 0), fm)
			_track(p, f)
			if (x * 7 + y * 3) % 5 == 0 and z < 1.0 and t != AbyssGrid.T.WATER:
				_track(p, _box(self, Vector3(0.6, 0.012, 0.04), c + Vector3(0, 0.005, 0), seam)) # balisage lumineux au sol
			if t == AbyssGrid.T.WATER:
				f.position.y -= 0.12
				_track(p, _box(self, Vector3(1, 0.04, 1), c + Vector3(0, 0.02, 0), water))
			elif t == AbyssGrid.T.WALL:
				var n := Node3D.new()
				n.position = c
				add_child(n)
				_box(n, Vector3(1, AbyssData.WALL_H, 1), Vector3(0, AbyssData.WALL_H / 2, 0), wall)
				_box(n, Vector3(1.01, 0.03, 1.01), Vector3(0, AbyssData.WALL_H * 0.72, 0), stripe)
				_box(n, Vector3(0.12, AbyssData.WALL_H * 0.6, 1.02), Vector3(0.3, AbyssData.WALL_H * 0.4, 0), _mat("rib", Color("38495a"), 0.8, 0.3))
				wall_nodes[g.idx(p)] = n
				_track(p, n)
			elif t == AbyssGrid.T.LOW:
				var n := Node3D.new()
				n.position = c
				add_child(n)
				if p == battle.terminal:
					_box(n, Vector3(0.7, 0.75, 0.5), Vector3(0, 0.375, 0), console)
					var sc := _box(n, Vector3(0.6, 0.35, 0.04), Vector3(0, 0.95, 0), term)
					sc.rotation_degrees.x = -20
					var o := OmniLight3D.new(); o.light_color = Color("52c99a"); o.omni_range = 2.5; o.light_energy = 1.2; o.position = Vector3(0, 1.1, 0.3)
					n.add_child(o)
				elif (x + y) % 2:
					_box(n, Vector3(0.82, 0.7, 0.82), Vector3(0, 0.35, 0), crate)
					_box(n, Vector3(0.84, 0.06, 0.84), Vector3(0, 0.5, 0), _mat("crateBand", Color("8a6a3a"), 0.4, 0.5))
				else:
					_box(n, Vector3(0.8, 0.65, 0.55), Vector3(0, 0.33, 0), console)
					var sc := _box(n, Vector3(0.7, 0.3, 0.04), Vector3(0, 0.78, -0.12), screen)
					sc.rotation_degrees.x = 15
				wall_nodes[g.idx(p)] = n
				_track(p, n)
	# rambarde lumineuse au bord de la passerelle (lecture des hauteurs)
	var rail := _mat("rail", Color("39d9ef"), 0, 1, Color("2ad0ff"))
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			if g.z(p) < 1.0 or g.tile(p) == AbyssGrid.T.HULL:
				continue
			for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]:
				var q: Vector2i = p + d
				if g.z(q) < 1.0 and g.tile(q) != AbyssGrid.T.STAIRS and g.tile(q) != AbyssGrid.T.HULL:
					var off := Vector3(d.x * 0.48, 1.25, d.y * 0.48)
					_track(p, _box(self, Vector3(0.04 if d.x else 1, 0.04, 1 if d.x else 0.04), Vector3(x + 0.5, 0, y + 0.5) + off, rail))

func _build_props() -> void:
	var g := battle.grid
	# éclairages : ambre au sas, néons cyan du labo, alarme rouge, contamination violette mesurée
	for l in [[Vector3(2.5, 2.2, 2.5), Color("ffb547"), 5.0, 1.6, false], [Vector3(5, 2.4, 8.5), Color("39d9ef"), 6.0, 1.3, true],
			[Vector3(11.5, 2.6, 3), Color("39d9ef"), 6.0, 1.2, false], [Vector3(13.5, 2.0, 8), Color("2ae8ff"), 4.0, 1.4, false],
			[Vector3(14, 2.2, 12), Color("e5484d"), 4.5, 1.6, false], [Vector3(4, 1.6, 12), Color("9863f5"), 4.5, 1.8, false]]:
		var o := OmniLight3D.new()
		o.position = l[0]; o.light_color = l[1]; o.omni_range = l[2]; o.light_energy = l[3]; o.shadow_enabled = l[4]
		add_child(o)
		if l[1] == Color("e5484d") or l[1] == Color("9863f5"):
			var tw := create_tween().set_loops()
			tw.tween_property(o, "light_energy", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(o, "light_energy", l[3], 1.1).set_trans(Tween.TRANS_SINE)
	# contamination violette autour du nid (sud-ouest)
	var goo := _mat("goo", Color("5a2a9a"), 0.2, 0.15, Color("6a2adf"))
	for p in [Vector2i(2, 11), Vector2i(3, 12), Vector2i(4, 11), Vector2i(2, 12), Vector2i(5, 12), Vector2i(1, 11)]:
		var s := SphereMesh.new(); s.radius = 0.32; s.height = 0.18
		_track(p, _mesh(self, s, _cell_pos(p) + Vector3((p.x % 2) * 0.15, 0.02, (p.y % 2) * -0.15), goo))
	# cuve de confinement brisée près de l'artefact
	var tank := Node3D.new()
	tank.position = Vector3(6.5, 0, 12.5)
	add_child(tank)
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.38; cyl.bottom_radius = 0.38; cyl.height = 1.5
	_mesh(tank, cyl, Vector3(0, 0.75, 0), _mat("tank", Color("39d9ef"), 0.1, 0.05, Color("0f5a70"), 0.35))
	var cap := CylinderMesh.new(); cap.top_radius = 0.45; cap.bottom_radius = 0.45; cap.height = 0.12
	_mesh(tank, cap, Vector3(0, 1.55, 0), _mat("wall", Color.BLACK))
	_mesh(tank, cap, Vector3(0, 0.06, 0), _mat("wall", Color.BLACK))
	_track(Vector2i(6, 12), tank)
	# artefact
	artifact_node = Node3D.new()
	add_child(artifact_node)
	var core := PrismMesh.new(); core.size = Vector3(0.35, 0.5, 0.35)
	var top := _mesh(artifact_node, core, Vector3(0, 0.85, 0), _mat("artifact", Color("dffcff"), 0.2, 0.1, Color("39d9ef")))
	var bottom := _mesh(artifact_node, core, Vector3(0, 0.35, 0), _mat("artifact", Color.BLACK))
	bottom.rotation_degrees.x = 180
	var al := OmniLight3D.new(); al.light_color = Color("39d9ef"); al.omni_range = 4.0; al.light_energy = 2.2; al.position = Vector3(0, 0.8, 0)
	artifact_node.add_child(al)
	var spin := create_tween().set_loops()
	spin.tween_property(top, "rotation_degrees:y", 360.0, 4.0).from(0.0)
	var pulse := create_tween().set_loops()
	pulse.tween_property(al, "light_energy", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(al, "light_energy", 2.4, 0.9).set_trans(Tween.TRANS_SINE)

func _build_unit(u: AbyssUnit) -> void:
	var root := Node3D.new()
	root.position = _cell_pos(u.cell)
	add_child(root)
	unit_nodes[u.id] = root
	var body := UnitVisuals.build(u.kind, _mat)
	body.name = "Body"
	root.add_child(body)
	if u.human:
		var lamp := SpotLight3D.new()
		lamp.name = "Lamp"
		lamp.position = Vector3(0, 1.3, 0.2)
		lamp.rotation_degrees = Vector3(-20, 180, 0)
		lamp.spot_range = 7.0
		lamp.spot_angle = 30.0
		lamp.light_energy = 2.0
		lamp.light_color = Color("d8f4ff")
		lamp.shadow_enabled = true
		body.add_child(lamp)
	if u.kind == "spectre":
		var tw := create_tween().set_loops()
		tw.tween_property(body, "position:y", 0.15, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(body, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	var ring := TorusMesh.new(); ring.inner_radius = 0.36; ring.outer_radius = 0.42
	var rm := _mesh(root, ring, Vector3(0, 0.03, 0), _mat("ring", Color("39d9ef"), 0, 1, Color("39d9ef")))
	rm.name = "Ring"
	rm.visible = false
	var lbl := Label3D.new()
	lbl.name = "Hp"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.0, 0)
	lbl.font_size = 38
	lbl.pixel_size = 0.006
	lbl.outline_size = 8
	lbl.no_depth_test = true
	root.add_child(lbl)

func _build_camera() -> void:
	pivot.position = Vector3(battle.grid.w / 2.0, 0, battle.grid.h / 2.0)
	add_child(pivot)
	pivot.add_child(yaw)
	yaw.rotation_degrees.y = 45
	yaw.add_child(pitch)
	pitch.rotation_degrees.x = -35.264 # isométrie vraie
	pitch.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	cam.position = Vector3(0, 0, 30)
	cam.far = 100.0

func _rotate(dir: int) -> void:
	yaw_step += dir
	var tw := create_tween()
	tw.tween_property(yaw, "rotation_degrees:y", 45.0 + 90.0 * yaw_step, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_update_cutaway)

## Coupe façon maquette : les pans de coque tournés vers la caméra sont abaissés pour voir l'intérieur.
func _update_cutaway() -> void:
	var back := cam.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	for hn in hull_nodes:
		var low: bool = (hn[1] as Vector3).dot(back) > 0.3
		(hn[0] as Node3D).scale = Vector3(1, 0.12 if low else 1.0, 1)

func _on_setting(key: String, v: Variant) -> void:
	match key:
		"speed": speed = v
		"cine": cine = v
		"shadows":
			sun.shadow_enabled = v
			for id in unit_nodes:
				var lamp: Node = unit_nodes[id].get_node_or_null("Body/Lamp")
				if lamp:
					lamp.shadow_enabled = v

# ---------- entrées tactiles ----------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		pinch_d = 0.0
	elif e is InputEventScreenDrag and touches.size() >= 2:
		touches[e.index] = e.position
		var pts: Array = touches.values()
		var d: float = pts[0].distance_to(pts[1])
		if pinch_d > 0.0:
			cam.size = clampf(cam.size * pinch_d / d, 4.0, 18.0)
		pinch_d = d
		drag_moved = true
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size = clampf(cam.size * 0.9, 4.0, 18.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = clampf(cam.size * 1.1, 4.0, 18.0)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				drag_moved = false
				drag_from = e.position
			elif not drag_moved and touches.size() <= 1:
				_tap(e.position)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and touches.size() <= 1:
		if e.position.distance_to(drag_from) > 12:
			drag_moved = true
		if drag_moved:
			var k := cam.size / get_viewport().get_visible_rect().size.y
			var right := cam.global_transform.basis.x
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			pivot.position += (-right * e.relative.x + fwd * e.relative.y * 1.7) * k

func _pick(pos: Vector2) -> Vector2i:
	var o := cam.project_ray_origin(pos)
	var n := cam.project_ray_normal(pos)
	for hgt in [1.0, 0.5, 0.0]:
		if absf(n.y) < 0.001:
			continue
		var t: float = (hgt - o.y) / n.y
		var hit := o + n * t
		var c := Vector2i(int(floor(hit.x)), int(floor(hit.z)))
		if battle.grid.inside(c) and absf(battle.grid.z(c) - hgt) < 0.01:
			return c
	return Vector2i(-1, -1)

func _tap(pos: Vector2) -> void:
	if busy or battle.outcome != "ongoing" or battle.side != "human":
		return
	var c := _pick(pos)
	if c.x < 0:
		return
	var u := battle.unit_at(c)
	if mode == "heal" and u and u.human:
		var err := battle.heal_error(selected, u)
		pending = {} if err else {"cell": c, "cmd": {"type": "heal", "unit": selected.id, "target": u.id}}
		hud.set_preview("Soin de %s · %d UT · +%d PV%s" % [u.name, AbyssData.MEDKIT_TU, AbyssData.MEDKIT_HEAL, (" — " + err) if err else ""], err == "")
		return
	if u and u.human:
		_select(u)
		return
	if selected == null or not selected.alive:
		return
	if not pending.is_empty() and pending.get("cell") == c:
		_confirm()
		return
	pending = {}
	if u and not u.human and _visible(u):
		var m := mode if mode in ["snap", "aimed"] else ("aimed" if selected.tu >= battle.shot_cost(selected, "aimed") else "snap")
		var info := battle.shot_info(selected, u, m)
		_clear_overlay()
		_beam(_cell_pos(selected.cell) + Vector3(0, 1.0, 0), _cell_pos(u.cell) + Vector3(0, 1.0, 0), Color("52c99a") if info["chance"] >= 50 else (AbyssHud.AMBER if info["chance"] >= 25 else AbyssHud.RED), overlay, 0.035)
		var label := "Tir précis" if m == "aimed" else "Tir rapide"
		if info["error"] != "":
			hud.set_preview("%s : %s" % [label, info["error"]], false)
			return
		pending = {"cell": c, "cmd": {"type": "shoot", "unit": selected.id, "target": u.id, "mode": m}}
		hud.set_preview("%s · %d UT · %d %% · couvert %s · reste %d UT" % [label, info["cost"], info["chance"], ["aucun", "partiel", "total"][info["cover"]], selected.tu - info["cost"]], true)
		return
	if mode == "throw":
		var err := battle.throw_error(selected, c)
		_show_reach()
		_blast(c)
		if err == "":
			pending = {"cell": c, "cmd": {"type": "throw", "unit": selected.id, "to": c}}
		hud.set_preview("Grenade · %d UT · rayon 2, abat cloisons et caisses%s" % [AbyssData.GRENADE_TU, (" — " + err) if err else ""], err == "")
		return
	if mode == "breach" and battle.grid.tile(c) == AbyssGrid.T.WALL:
		var bi := battle.breach_info(selected, c)
		if bi["error"] == "":
			pending = {"cell": c, "cmd": {"type": "breach", "unit": selected.id, "at": c}}
		hud.set_preview("Brèche · %d UT · la cloison s'effondre%s" % [bi["cost"], (" — " + bi["error"]) if bi["error"] else ""], bi["error"] == "")
		return
	var r := battle.reach(selected)
	var k := battle.grid.idx(c)
	if not r["cost"].has(k) or r["cost"][k] == 0:
		mode = "move"
		_show_reach()
		hud.set_preview("Hors de portée.", false)
		_refresh_hud()
		return
	var path := battle.grid.path_to(r, c)
	var cost: int = int(r["cost"][k])
	_show_reach()
	var dot := SphereMesh.new(); dot.radius = 0.06; dot.height = 0.12; dot.radial_segments = 6; dot.rings = 3
	for p in path:
		_mesh(overlay, dot, _cell_pos(p) + Vector3(0, 0.12, 0), _mat("dot", Color("e4edf5"), 0, 1, Color("39d9ef")))
	var reactors := 0
	var cov := 0
	for e in battle.spotted_by(true):
		if battle.grid.can_see(e, c) and e.tu >= battle.shot_cost(e, "snap"):
			reactors += 1
		cov = maxi(cov, battle.grid.cover_against(c, e.cell))
	_cover_marks(c)
	pending = {"cell": c, "cmd": {"type": "move", "unit": selected.id, "to": c}}
	hud.set_preview("Déplacement · %d UT · reste %d · %s · couvert %s%s" % [cost, selected.tu - cost, "en hauteur" if battle.grid.z(c) >= 1 else "au sol",
		["aucun", "partiel", "total"][cov], (" · %d réaction(s) possible(s)" % reactors) if reactors else ""], true)

func _on_action(m: String) -> void:
	if busy or selected == null:
		return
	match m:
		"end":
			await _run({"type": "end_turn"})
		"kneel", "watch", "reload", "interact":
			await _run({"type": m, "unit": selected.id})
		"evac":
			var split := battle.evac_split()
			var carry: bool = split["leaving"].any(func(u): return u.carrying)
			pending = {"cell": Vector2i(-9, -9), "cmd": {"type": "evacuate"}}
			hud.set_preview("Évacuation · %d partent, %d restent · %s" % [split["leaving"].size(), split["staying"].size(),
				"artefact à bord : victoire" if carry else "sans l'artefact : retraite (échec)"], true)
		_:
			mode = "move" if mode == m else m
			pending = {}
			_clear_overlay()
			_show_reach()
			hud.set_preview({"snap": "Tir rapide : touchez un ennemi.", "aimed": "Tir précis : touchez un ennemi.", "throw": "Grenade : touchez la case visée.",
				"breach": "Brèche : touchez une cloison (6 cases max).", "heal": "Soin : touchez un soldat au contact (ou vous-même).", "move": ""}[mode], false)
			_refresh_hud()

func _confirm() -> void:
	if pending.is_empty() or busy:
		return
	var cmd: Dictionary = pending["cmd"]
	pending = {}
	await _run(cmd)

func _select(u: AbyssUnit) -> void:
	if u == null or not u.alive or u.evacuated:
		return
	selected = u
	mode = "move"
	pending = {}
	for id in unit_nodes:
		unit_nodes[id].get_node("Ring").visible = id == u.id
	create_tween().tween_property(pivot, "position", Vector3(u.cell.x + 0.5, 0, u.cell.y + 0.5), 0.35).set_trans(Tween.TRANS_SINE)
	_clear_overlay()
	_show_reach()
	hud.set_preview("", false)
	_refresh_hud()

# ---------- aperçus ----------

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _show_reach() -> void:
	if selected == null or not selected.alive or battle.side != "human" or battle.outcome != "ongoing":
		return
	var r := battle.reach(selected)
	var keep := battle.shot_cost(selected, "snap")
	var tile := BoxMesh.new(); tile.size = Vector3(0.84, 0.015, 0.84)
	for k in r["cost"]:
		if r["cost"][k] == 0:
			continue
		var p := Vector2i(k % battle.grid.w, k / battle.grid.w)
		var ok: bool = selected.tu - r["cost"][k] >= keep
		var mi := _mesh(overlay, tile, _cell_pos(p) + Vector3(0, 0.015, 0), _mat("reachOk" if ok else "reachLow", Color("39d9ef") if ok else Color("ffb547"), 0, 1, Color("0e5868") if ok else Color("6a4012"), 0.22))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Boucliers de couverture autour de la case visée (cyan = total, ambre = partiel).
func _cover_marks(c: Vector2i) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = c + d
		var t := battle.grid.tile(q)
		var lvl := 2 if t == AbyssGrid.T.WALL or t == AbyssGrid.T.HULL else (1 if t == AbyssGrid.T.LOW else 0)
		if lvl == 0:
			continue
		var m := _box(overlay, Vector3(0.5 if d.y else 0.06, 0.35 if lvl == 2 else 0.22, 0.06 if d.y else 0.5), _cell_pos(c) + Vector3(d.x * 0.42, 0.3, d.y * 0.42),
			_mat("shieldFull" if lvl == 2 else "shieldHalf", Color("39d9ef") if lvl == 2 else Color("ffb547"), 0, 1, Color("39d9ef") if lvl == 2 else Color("ffb547"), 0.7))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _blast(c: Vector2i) -> void:
	var tile := BoxMesh.new(); tile.size = Vector3(0.9, 0.03, 0.9)
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 2, c.x + 3):
			var p := Vector2i(x, y)
			if battle.grid.inside(p):
				_mesh(overlay, tile, _cell_pos(p) + Vector3(0, 0.05, 0), _mat("blast", Color("ff7a3d"), 0, 1, Color("ff5a1d"), 0.35))

func _beam(a: Vector3, b: Vector3, col: Color, parent: Node3D, width := 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, a.distance_to(b))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (a + b) / 2.0
	if a.distance_to(b) > 0.01:
		mi.look_at(b, Vector3.UP)
	return mi

# ---------- synchronisation, brouillard ----------

func _visible(u: AbyssUnit) -> bool:
	return u.human or battle.seen_by_humans(u)

func _sync() -> void:
	for u in battle.units:
		var n: Node3D = unit_nodes[u.id]
		n.position = _cell_pos(u.cell)
		n.visible = u.alive and not u.evacuated and _visible(u)
		(n.get_node("Body") as Node3D).scale = Vector3(1, 0.78 if u.kneeling else 1.0, 1)
		n.rotation.y = atan2(float(u.facing.x), float(u.facing.y))
		var lbl: Label3D = n.get_node("Hp")
		lbl.text = "%d%s%s" % [u.hp, " veille" if u.watching else "", " ART" if u.carrying else ""]
		lbl.modulate = Color("39d9ef") if u.human else Color("e5484d")
	artifact_node.visible = battle.artifact.x >= 0 and battle.explored[battle.grid.idx(battle.artifact)] == 1
	if battle.artifact.x >= 0:
		artifact_node.position = _cell_pos(battle.artifact)
	_fog()
	_refresh_hud()

## Brouillard : cases jamais vues masquées, cases mémorisées assombries, cases visibles normales.
func _fog() -> void:
	var g := battle.grid
	var tile := BoxMesh.new(); tile.size = Vector3(1.0, 0.02, 1.0)
	var shade := _mat("fog", Color("02060a"), 0, 1, Color.BLACK, 0.62)
	for k in cell_nodes:
		var p := Vector2i(k % g.w, k / g.w)
		var known := battle.explored[k] == 1
		for n in cell_nodes[k]:
			if is_instance_valid(n):
				n.visible = known
		var seen := known and battle.living(true).any(func(h): return g.can_see(h, p, 0.3))
		if known and not seen:
			if not fog_quads.has(k):
				var q := _mesh(self, tile, _cell_pos(p) + Vector3(0, 0.03, 0), shade)
				q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				fog_quads[k] = q
			fog_quads[k].visible = true
		elif fog_quads.has(k):
			fog_quads[k].visible = false

func _refresh_hud() -> void:
	hud.refresh(battle, selected, mode, busy)

func _wait(t: float) -> void:
	await get_tree().create_timer(t / speed).timeout

func _run(cmd: Dictionary) -> void:
	busy = true
	_clear_overlay()
	hud.set_preview("", false)
	_refresh_hud()
	var ev := battle.apply(cmd)
	await _play(ev)
	_save()
	busy = false
	mode = "move"
	if battle.outcome != "ongoing":
		_clear_overlay()
		hud.show_end(battle)
		_refresh_hud()
		return
	if selected == null or not selected.alive or selected.evacuated:
		selected = null
		for s in battle.living(true):
			selected = s
			break
	_select(selected)

# ---------- effets ----------

func _float(at: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 54
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = col
	l.no_depth_test = true
	add_child(l)
	l.global_position = at + Vector3(0, 2.1, 0)
	var tw := create_tween()
	tw.tween_property(l, "global_position:y", at.y + 2.9, 1.0 / minf(speed, 2.0))
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0 / minf(speed, 2.0))
	tw.tween_callback(l.queue_free)

func _flash_light(at: Vector3, col: Color, rng: float, energy: float, dur: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = col
	o.omni_range = rng
	o.light_energy = energy
	add_child(o)
	o.global_position = at
	var tw := create_tween()
	tw.tween_property(o, "light_energy", 0.0, dur)
	tw.tween_callback(o.queue_free)

func _sparks(at: Vector3, col: Color, amount: int, vel: float, life := 0.5) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.035; sm.height = 0.07; sm.radial_segments = 4; sm.rings = 2
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = life
	p.spread = 70.0
	p.direction = Vector3.UP
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, -6, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)

func _muzzle(n: Node3D) -> Vector3:
	var m: Node3D = n.get_node_or_null("Body/Muzzle")
	return m.global_position if m else n.global_position + Vector3(0, 1.0, 0)

## Caméra cinématique courte (facultative) : resserre le cadre entre tireur et cible, puis revient.
func _cine_in(a: Vector3, b: Vector3) -> void:
	if not cine or speed > 1.0:
		return
	var mid := (a + b) / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "size", clampf(a.distance_to(b) * 0.9 + 3.0, 4.5, 8.0), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivot, "position", Vector3(mid.x, 0, mid.z), 0.25).set_trans(Tween.TRANS_SINE)
	await tw.finished

func _cine_out(size: float) -> void:
	if not cine or speed > 1.0:
		return
	await get_tree().create_timer(0.25).timeout
	create_tween().tween_property(cam, "size", size, 0.3).set_trans(Tween.TRANS_SINE)

func _walk_bob(n: Node3D, dur: float) -> void:
	var body: Node3D = n.get_node("Body")
	var tw := create_tween()
	tw.tween_property(body, "position:y", 0.06, dur / 2)
	tw.tween_property(body, "position:y", 0.0, dur / 2)

func _play(events: Array) -> void:
	for e in events:
		match e["t"]:
			"move":
				var u := battle.unit(e["unit"])
				var n: Node3D = unit_nodes[u.id]
				var to := _cell_pos(e["to"])
				n.rotation.y = atan2(float(e["to"].x - e["from"].x), float(e["to"].y - e["from"].y))
				if not e["seen"]:
					n.position = to
					n.visible = false
					continue
				n.visible = true
				var dur := 0.2 / speed
				_walk_bob(n, dur)
				var tw := create_tween()
				tw.tween_property(n, "position", to, dur)
				await tw.finished
				if u.human:
					_fog()
			"spotted":
				var u := battle.unit(e["unit"])
				unit_nodes[u.id].visible = true
				hud.flash("Contact sonar : %s" % u.name, AbyssHud.RED)
				if battle.side != "human":
					create_tween().tween_property(pivot, "position", Vector3(u.cell.x + 0.5, 0, u.cell.y + 0.5), 0.3 / speed)
				await _wait(0.35)
			"interrupt":
				if battle.unit(e["unit"]).human:
					hud.flash("%s s'arrête : contact !" % battle.unit(e["unit"]).name, AbyssHud.RED)
			"shot":
				var u := battle.unit(e["unit"])
				var n: Node3D = unit_nodes[u.id]
				n.rotation.y = atan2(float(e["to"].x - e["from"].x), float(e["to"].y - e["from"].y))
				if e["reaction"]:
					hud.flash("Tir de réaction : %s" % u.name, AbyssHud.RED)
				var col: Color = {"rifle": Color("9ff3ff"), "pistol": Color("c8f6ff"), "harpoon": Color("ffe08a"), "dart": Color("7dffc4"), "acid": Color("c6ff4d"), "psi": Color("c58bff")}[e["weapon"]]
				var a := _muzzle(n)
				var b := _cell_pos(e["to"]) + Vector3(0, 1.0, 0)
				if not e["hit"]:
					b += Vector3(0.45, 0.35, -0.3)
				var size := cam.size
				var cinematic: bool = u.human and e["mode"] == "aimed" and not e["reaction"]
				if cinematic:
					await _cine_in(a, b)
				# recul de l'arme, éclair, traceur, étincelles d'impact
				var body: Node3D = n.get_node("Body")
				var kick := create_tween()
				kick.tween_property(body, "position:z", -0.08, 0.05)
				kick.tween_property(body, "position:z", 0.0, 0.12)
				_flash_light(a, col, 4.0, 4.0, 0.2)
				_sparks(a, col, 8, 2.0, 0.2)
				var beam := _beam(a, b, col, self, 0.06 if e["weapon"] in ["harpoon", "psi"] else 0.035)
				await _wait(0.08)
				beam.queue_free()
				_sparks(b, col if e["hit"] else Color("c9d6e0"), 14, 3.0, 0.4)
				if not e["hit"]:
					_float(_cell_pos(e["to"]), "Raté (%d %%)" % e["chance"], Color("c9d6e0"))
				await _wait(0.22)
				if cinematic:
					_cine_out(size)
			"damage":
				var u := battle.unit(e["unit"])
				var n: Node3D = unit_nodes[u.id]
				_float(_cell_pos(u.cell), "-%d%s" % [e["amount"], " blessé" if e["wounded"] else ""], Color("ff7b6b"))
				if e["drained"] > 0:
					hud.flash("%s désorienté : -%d UT au prochain tour" % [u.name, e["drained"]], Color("9863f5"))
				var body: Node3D = n.get_node("Body")
				var tw := create_tween()
				tw.tween_property(body, "rotation_degrees:x", -14.0, 0.06)
				tw.tween_property(body, "rotation_degrees:x", 0.0, 0.2)
				_flash_light(_cell_pos(u.cell) + Vector3(0, 1, 0), Color("e5484d"), 2.5, 2.5, 0.25)
				await _wait(0.2)
			"death":
				var n: Node3D = unit_nodes[e["unit"]]
				var u := battle.unit(e["unit"])
				hud.flash("%s %s" % [u.name, "est tombé" if u.human else "neutralisé"], AbyssHud.RED if u.human else AbyssHud.GREEN)
				var tw := create_tween()
				tw.tween_property(n, "rotation:z", 1.45, 0.45 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(n, "position:y", n.position.y - 0.15, 0.2 / speed)
				await tw.finished
				_sparks(n.global_position + Vector3(0, 0.3, 0), Color("9863f5") if not u.human else Color("e5484d"), 10, 1.5, 0.6)
				await _wait(0.3)
				n.visible = false
			"explosion":
				var at := _cell_pos(e["at"])
				_flash_light(at + Vector3(0, 1, 0), Color("ff8a3d"), 9.0, 9.0, 0.8)
				_sparks(at + Vector3(0, 0.4, 0), Color("ffb060"), 70, 7.0, 0.9)
				var ring := TorusMesh.new(); ring.inner_radius = 0.2; ring.outer_radius = 0.35
				var rm := _mesh(self, ring, at + Vector3(0, 0.1, 0), _mat("shock", Color("ffb547"), 0, 1, Color("ff7a20"), 0.6))
				var tw := create_tween().set_parallel()
				tw.tween_property(rm, "scale", Vector3(6, 1, 6), 0.45)
				tw.tween_property(rm, "transparency", 1.0, 0.45)
				tw.chain().tween_callback(rm.queue_free)
				var shake := create_tween()
				for i in 5:
					shake.tween_property(cam, "h_offset", 0.12 * (1 if i % 2 else -1), 0.04)
				shake.tween_property(cam, "h_offset", 0.0, 0.04)
				await _wait(0.45)
			"destroy", "wall_hit":
				var k := battle.grid.idx(e["at"])
				if e["t"] == "wall_hit":
					_sparks(_cell_pos(e["at"]) + Vector3(0, 1, 0), Color("ffd27a"), 12, 2.5, 0.4)
					_float(_cell_pos(e["at"]), "Cloison fissurée", Color("ffd27a"))
					continue
				if wall_nodes.has(k):
					_collapse(wall_nodes[k])
					wall_nodes.erase(k)
				await _wait(0.15)
			"heal":
				var t := battle.unit(e["target"])
				_float(_cell_pos(t.cell), "+%d PV" % e["amount"], Color("52c99a"))
				_flash_light(_cell_pos(t.cell) + Vector3(0, 1, 0), Color("52c99a"), 3.0, 2.0, 0.6)
				await _wait(0.3)
			"reload":
				_float(_cell_pos(battle.unit(e["unit"]).cell), "Rechargé", Color("c9e6ff"))
			"pickup":
				hud.flash("%s récupère l'artefact" % battle.unit(e["unit"]).name, AbyssHud.CYAN)
				artifact_node.visible = false
			"alarm":
				hud.flash("L'artefact pulse : tous les hostiles convergent !", AbyssHud.RED)
				_flash_light(_cell_pos(battle.unit(events.filter(func(x): return x["t"] == "pickup")[0]["unit"]).cell) + Vector3(0, 1, 0), Color("39d9ef"), 14.0, 6.0, 1.2)
				await _wait(0.6)
			"logs":
				hud.flash("Journal du terminal téléchargé", AbyssHud.GREEN)
			"drop":
				hud.flash("L'artefact est tombé au sol", AbyssHud.RED)
			"bleed":
				_float(_cell_pos(battle.unit(e["unit"]).cell), "-%d saignement" % e["amount"], Color("ff9a8a"))
			"turn":
				hud.flash("Activité hostile…" if e["side"] == "alien" else "Tour %d" % e["turn"], AbyssHud.RED if e["side"] == "alien" else AbyssHud.CYAN)
				_refresh_hud()
			"evacuate":
				for id in e["units"]:
					var n: Node3D = unit_nodes[id]
					create_tween().tween_property(n, "position:y", n.position.y + 3.0, 0.6)
				await _wait(0.6)
	_sync()

## Effondrement : le bloc se fragmente, les morceaux rebondissent et restent ; poussière brève.
func _collapse(n: Node3D) -> void:
	var base := n.position
	var mat := _mat("rubble", Color("3a4a58"), 0.5, 0.7)
	_sparks(base + Vector3(0, 0.6, 0), Color("8aa0b0"), 24, 3.0, 0.7)
	for i in 7:
		var s := 0.16 + 0.06 * (i % 3)
		var piece := _box(self, Vector3(s, s * 0.8, s), base + Vector3(0, 0.4 + (i % 4) * 0.35, 0), mat)
		var target := base + Vector3((i % 3 - 1) * 0.32 + randf_range(-0.1, 0.1), s * 0.4, (i / 3 - 1) * 0.32 + randf_range(-0.1, 0.1))
		var tw := create_tween()
		tw.tween_property(piece, "position", target, 0.45 / speed).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(piece, "rotation", Vector3(randf() * 2, randf() * 2, randf()), 0.45 / speed)
	n.queue_free()

## Partie automatique (?autoplay) : sert aux tests de performance et de non-régression.
func _autoplay() -> void:
	speed = 4.0
	while battle.outcome == "ongoing" and battle.turn < 12:
		var ev: Array = []
		AbyssAI.run(battle, true, ev)
		await _play(ev)
		if battle.outcome == "ongoing":
			await _run({"type": "end_turn"})
	if battle.outcome != "ongoing":
		hud.show_end(battle)
