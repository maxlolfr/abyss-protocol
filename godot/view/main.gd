extends Node3D
## Rendu 3D isométrique de la bataille (prototype Godot). Lit AbyssBattle et rejoue ses événements.
## Modèles temporaires construits en primitives : aucun asset importé.

var battle: AbyssBattle
var hud: AbyssHud
var pivot := Node3D.new() # point visé par la caméra
var yaw := Node3D.new()
var pitch := Node3D.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var unit_nodes := {} # id -> Node3D
var wall_nodes := {} # idx -> Node3D
var overlay := Node3D.new()
var selected: AbyssUnit
var mode := "move"
var pending := {} # aperçu en attente de confirmation
var busy := false
var speed := 1.0
var yaw_step := 0
var touches := {}
var pinch_d := 0.0
var drag_moved := false
var drag_from := Vector2.ZERO
var mats := {}

func _ready() -> void:
	var s := "abyss"
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed') || ''")
		if q:
			s = String(q)
	battle = AbyssBattle.new(s)
	_build_env()
	_build_map()
	for u in battle.units:
		_build_unit(u)
	add_child(overlay)
	_build_camera()
	hud = AbyssHud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	hud.confirm.connect(_confirm)
	hud.select_unit.connect(func(id): _select(battle.unit(id)))
	hud.rotate_cam.connect(_rotate)
	hud.speed_changed.connect(func(v): speed = v)
	hud.shadows_changed.connect(_set_shadows)
	hud.restart.connect(func(): get_tree().reload_current_scene())
	_select(battle.unit("s1"))
	_sync()
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('autoplay')"):
		_autoplay()

# ---------- construction de la scène ----------

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
		m.emission_energy_multiplier = 1.6
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

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("02070b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1d3a4a")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true # voile sous-marin
	env.fog_light_color = Color("06202b")
	env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# lumière froide venant des verrières, avec ombres dynamiques
	sun.light_color = Color("9fd8ff")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-58, 30, 0)
	add_child(sun)
	# éclairages d'ambiance : alarme rouge, cyan des réservoirs, ambre du sas
	for l in [[Vector3(14, 2.3, 9), Color("ff3a2a"), 5.0, true], [Vector3(13, 1.2, 8.5), Color("2ae8ff"), 4.0, false], [Vector3(2, 2.0, 2), Color("ffa040"), 4.5, false], [Vector3(4, 2.2, 11.5), Color("ff3a2a"), 4.5, false]]:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.omni_range = l[2]
		o.light_energy = 1.6
		o.shadow_enabled = l[3]
		add_child(o)
		if l[1] == Color("ff3a2a"):
			var tw := create_tween().set_loops()
			tw.tween_property(o, "light_energy", 0.4, 0.9)
			tw.tween_property(o, "light_energy", 1.8, 0.9)

func _cell_pos(p: Vector2i) -> Vector3:
	return Vector3(p.x + 0.5, battle.grid.z(p), p.y + 0.5)

func _build_map() -> void:
	var g := battle.grid
	var floor_a := _mat("floorA", Color("2a3a46"), 0.6, 0.45)
	var floor_b := _mat("floorB", Color("24333e"), 0.6, 0.5)
	var plat := _mat("plat", Color("3b4c58"), 0.7, 0.35)
	var under := _mat("under", Color("141e26"), 0.5, 0.7)
	var wall := _mat("wall", Color("4a5e6c"), 0.55, 0.5)
	var hull := _mat("hull", Color("1b2832"), 0.4, 0.8)
	var stripe := _mat("stripe", Color("ffb347"), 0, 1, Color("ff9a2a"))
	var crate := _mat("crate", Color("6b5230"), 0.2, 0.8)
	var water := _mat("water", Color("0e6a80"), 0.1, 0.1, Color("0a4a60"), 0.75)
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			var t := g.tile(p)
			var z := g.z(p)
			var c := Vector3(x + 0.5, z, y + 0.5)
			if t == AbyssGrid.T.HULL:
				_box(self, Vector3(1, 1.1, 1), c + Vector3(0, 0.55, 0), hull)
				continue
			if z >= 1.0:
				_box(self, Vector3(1, 1, 1), Vector3(c.x, 0.5, c.z), under)
			elif t == AbyssGrid.T.STAIRS:
				_box(self, Vector3(1, 0.25, 1), Vector3(c.x, 0.125, c.z), under)
				_box(self, Vector3(0.5, 0.25, 1), Vector3(c.x + 0.25, 0.375, c.z), under)
			var f := _box(self, Vector3(0.96, 0.08, 0.96), c - Vector3(0, 0.04, 0), plat if z >= 1.0 else (floor_a if (x + y) % 2 else floor_b))
			if t == AbyssGrid.T.WATER:
				f.position.y -= 0.1
				_box(self, Vector3(1, 0.04, 1), c + Vector3(0, 0.02, 0), water)
			elif t == AbyssGrid.T.WALL:
				var n := Node3D.new()
				n.position = c
				add_child(n)
				_box(n, Vector3(1, AbyssData.WALL_H, 1), Vector3(0, AbyssData.WALL_H / 2, 0), wall)
				_box(n, Vector3(1.02, 0.06, 1.02), Vector3(0, AbyssData.WALL_H * 0.7, 0), stripe)
				wall_nodes[g.idx(p)] = n
			elif t == AbyssGrid.T.LOW:
				var n := Node3D.new()
				n.position = c
				add_child(n)
				_box(n, Vector3(0.8, 0.7, 0.8), Vector3(0, 0.35, 0), crate)
				wall_nodes[g.idx(p)] = n
	# rambarde lumineuse du bord de la passerelle (lecture des hauteurs)
	var rail := _mat("rail", Color("5cf2ff"), 0, 1, Color("2ad0ff"))
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			if g.z(p) < 1.0 or g.tile(p) == AbyssGrid.T.HULL:
				continue
			for d in [Vector2i(0, 1), Vector2i(-1, 0)]:
				var q: Vector2i = p + d
				if g.z(q) < 1.0 and g.tile(q) != AbyssGrid.T.STAIRS and g.tile(q) != AbyssGrid.T.HULL:
					var off := Vector3(d.x * 0.48, 1.02, d.y * 0.48)
					_box(self, Vector3(0.04 if d.x else 1, 0.04, 1 if d.x else 0.04), Vector3(x + 0.5, 0, y + 0.5) + off, rail)

func _build_unit(u: AbyssUnit) -> void:
	var root := Node3D.new()
	root.position = _cell_pos(u.cell)
	add_child(root)
	unit_nodes[u.id] = root
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	match u.kind:
		"soldier":
			var cap := CapsuleMesh.new(); cap.radius = 0.22; cap.height = 1.1
			_mesh(body, cap, Vector3(0, 0.6, 0), _mat("suit", Color("2b4b66"), 0.6, 0.4))
			var hel := SphereMesh.new(); hel.radius = 0.18; hel.height = 0.34
			_mesh(body, hel, Vector3(0, 1.28, 0), _mat("helm", Color("4c84ad"), 0.7, 0.3))
			_box(body, Vector3(0.22, 0.08, 0.06), Vector3(0, 1.3, 0.16), _mat("visor", Color("7ff4ff"), 0, 0.2, Color("40e8ff")))
			_box(body, Vector3(0.07, 0.07, 0.55), Vector3(0.2, 0.85, 0.22), _mat("gun", Color("9fb3c4"), 0.8, 0.3))
			_box(body, Vector3(0.44, 0.05, 0.3), Vector3(0, 0.82, 0), _mat("band", Color("d18b2c"), 0.3, 0.6))
			var lamp := SpotLight3D.new()
			lamp.name = "Lamp"
			lamp.position = Vector3(0, 1.25, 0.25)
			lamp.rotation_degrees = Vector3(-18, 180, 0)
			lamp.spot_range = 7.0
			lamp.spot_angle = 32.0
			lamp.light_energy = 2.2
			lamp.light_color = Color("d8f4ff")
			lamp.shadow_enabled = true
			body.add_child(lamp)
		"nereide":
			var cap := CapsuleMesh.new(); cap.radius = 0.2; cap.height = 1.35
			_mesh(body, cap, Vector3(0, 0.7, 0), _mat("ner", Color("167a6c"), 0.3, 0.35))
			var fin := PrismMesh.new(); fin.size = Vector3(0.05, 0.45, 0.4)
			_mesh(body, fin, Vector3(0, 1.35, -0.12), _mat("fin", Color("2bc4a0"), 0.2, 0.4, Color("0f6a55")))
			_box(body, Vector3(0.2, 0.05, 0.05), Vector3(0, 1.2, 0.18), _mat("nerEye", Color("d8ffef"), 0, 0.2, Color("9fffd0")))
			_box(body, Vector3(0.05, 0.05, 0.6), Vector3(0.18, 0.9, 0.25), _mat("dart", Color("9ff7d6"), 0.2, 0.4, Color("3ac79a")))
		"carapace":
			var sh := SphereMesh.new(); sh.radius = 0.55; sh.height = 0.7
			_mesh(body, sh, Vector3(0, 0.45, 0), _mat("cara", Color("8a5530"), 0.5, 0.45))
			for i in 6:
				var leg := CylinderMesh.new(); leg.top_radius = 0.04; leg.bottom_radius = 0.03; leg.height = 0.5
				var a := (i - 2.5) * 0.5
				var lm := _mesh(body, leg, Vector3(sin(a) * 0.5 * (1 if i < 3 else -1), 0.18, cos(a) * 0.35), _mat("leg", Color("4b2f1c"), 0.3, 0.7))
				lm.rotation_degrees = Vector3(0, 0, 50 if i < 3 else -50)
			_box(body, Vector3(0.3, 0.06, 0.06), Vector3(0, 0.55, 0.5), _mat("caraEye", Color("ffb347"), 0, 0.2, Color("ff9a2a")))
		"spectre":
			var dome := SphereMesh.new(); dome.radius = 0.38; dome.height = 0.5; dome.is_hemisphere = true
			_mesh(body, dome, Vector3(0, 1.35, 0), _mat("spec", Color("a46bff"), 0, 0.2, Color("7a3cff"), 0.8))
			for i in 7:
				var t := CylinderMesh.new(); t.top_radius = 0.025; t.bottom_radius = 0.008; t.height = 0.9
				_mesh(body, t, Vector3(cos(i * 0.9) * 0.22, 0.9, sin(i * 0.9) * 0.22), _mat("tent", Color("c58bff"), 0, 0.3, Color("6a2adf"), 0.85))
			var o := OmniLight3D.new()
			o.position = Vector3(0, 1.3, 0)
			o.light_color = Color("b070ff")
			o.omni_range = 3.0
			o.light_energy = 1.4
			body.add_child(o)
			var tw := create_tween().set_loops()
			tw.tween_property(body, "position:y", 0.15, 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(body, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	# anneau de sélection et barre de vie
	var ring := TorusMesh.new(); ring.inner_radius = 0.34; ring.outer_radius = 0.4
	var rm := _mesh(root, ring, Vector3(0, 0.03, 0), _mat("ring", Color("5cf2ff"), 0, 1, Color("5cf2ff")))
	rm.name = "Ring"
	rm.visible = false
	var lbl := Label3D.new()
	lbl.name = "Hp"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.0, 0)
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.outline_size = 8
	lbl.no_depth_test = true
	root.add_child(lbl)
	_face(u)

func _face(u: AbyssUnit) -> void:
	var n: Node3D = unit_nodes[u.id]
	n.rotation.y = atan2(float(u.facing.x), float(u.facing.y))

func _build_camera() -> void:
	pivot.position = Vector3(battle.grid.w / 2.0, 0, battle.grid.h / 2.0)
	add_child(pivot)
	pivot.add_child(yaw)
	yaw.rotation_degrees.y = 45
	yaw.add_child(pitch)
	pitch.rotation_degrees.x = -35.264 # isométrie vraie
	pitch.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.0
	cam.position = Vector3(0, 0, 30)
	cam.far = 100.0

func _rotate(dir: int) -> void:
	yaw_step += dir
	create_tween().tween_property(yaw, "rotation_degrees:y", 45.0 + 90.0 * yaw_step, 0.35).set_trans(Tween.TRANS_SINE)

func _set_shadows(on: bool) -> void:
	sun.shadow_enabled = on
	for id in unit_nodes:
		var lamp: Node = unit_nodes[id].get_node_or_null("Body/Lamp")
		if lamp:
			lamp.shadow_enabled = on

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
			cam.size = clampf(cam.size * pinch_d / d, 5.0, 20.0)
		pinch_d = d
		drag_moved = true
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size = clampf(cam.size * 0.9, 5.0, 20.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = clampf(cam.size * 1.1, 5.0, 20.0)
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

## Case touchée : on teste les plans de hauteur de haut en bas (passerelle, escalier, sol).
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
		_beam(_cell_pos(selected.cell) + Vector3(0, 1.0, 0), _cell_pos(u.cell) + Vector3(0, 1.0, 0), Color("7dffb0") if info["chance"] >= 50 else (Color("ffd27a") if info["chance"] >= 25 else Color("ff6a5a")))
		if info["error"] != "":
			hud.set_preview("%s : %s" % ["Tir précis" if m == "aimed" else "Tir rapide", info["error"]], false)
			return
		pending = {"cell": c, "cmd": {"type": "shoot", "unit": selected.id, "target": u.id, "mode": m}}
		hud.set_preview("%s · %d UT · %d %% · couvert %s · reste %d UT" % ["Tir précis" if m == "aimed" else "Tir rapide", info["cost"], info["chance"], ["aucun", "partiel", "total"][info["cover"]], selected.tu - info["cost"]], true)
		return
	if mode == "throw":
		var err := battle.throw_error(selected, c)
		_show_reach()
		_blast(c)
		if err == "":
			pending = {"cell": c, "cmd": {"type": "throw", "unit": selected.id, "to": c}}
		hud.set_preview("Grenade · %d UT · rayon 2, abat les cloisons au contact%s" % [AbyssData.GRENADE_TU, (" — " + err) if err else ""], err == "")
		return
	if mode == "breach" and battle.grid.tile(c) == AbyssGrid.T.WALL:
		var bi := battle.breach_info(selected, c)
		if bi["error"] == "":
			pending = {"cell": c, "cmd": {"type": "breach", "unit": selected.id, "at": c}}
		hud.set_preview("Brèche au harpon · %d UT · la cloison s'effondre%s" % [bi["cost"], (" — " + bi["error"]) if bi["error"] else ""], bi["error"] == "")
		return
	var r := battle.reach(selected)
	var k := battle.grid.idx(c)
	if not r["cost"].has(k) or r["cost"][k] == 0:
		mode = "move"
		_show_reach()
		hud.set_preview("Hors de portée — touchez une case en surbrillance.", false)
		_refresh_hud()
		return
	var path := battle.grid.path_to(r, c)
	var cost: int = int(r["cost"][k])
	_show_reach()
	for p in path:
		var dot := SphereMesh.new(); dot.radius = 0.07; dot.height = 0.14
		_mesh(overlay, dot, _cell_pos(p) + Vector3(0, 0.12, 0), _mat("dot", Color("9ff3ff"), 0, 1, Color("9ff3ff")))
	var reactors := 0
	for e in battle.spotted_by(true):
		if battle.grid.can_see(e, c) and e.tu >= battle.shot_cost(e, "snap"):
			reactors += 1
	var cov := 0
	for e in battle.spotted_by(true):
		cov = maxi(cov, battle.grid.cover_against(c, e.cell))
	pending = {"cell": c, "cmd": {"type": "move", "unit": selected.id, "to": c}}
	hud.set_preview("Déplacement · %d UT · reste %d UT · niveau %s · couvert %s%s" % [cost, selected.tu - cost, "haut" if battle.grid.z(c) >= 1 else "bas",
		["aucun", "partiel", "total"][cov], (" · ATTENTION %d tir(s) de réaction" % reactors) if reactors else ""], true)

func _on_action(m: String) -> void:
	if busy:
		return
	if m == "end":
		await _run({"type": "end_turn"})
		return
	if m in ["kneel", "watch"]:
		await _run({"type": m, "unit": selected.id})
		return
	mode = "move" if mode == m else m
	pending = {}
	_clear_overlay()
	_show_reach()
	hud.set_preview({"snap": "Tir rapide : touchez un ennemi visible.", "aimed": "Tir précis : touchez un ennemi visible.", "throw": "Grenade : touchez la case visée.",
		"breach": "Brèche : touchez une cloison à 6 cases maximum.", "move": "Déplacement : touchez une case."}[mode], false)
	_refresh_hud()

func _confirm() -> void:
	if pending.is_empty() or busy:
		return
	var cmd: Dictionary = pending["cmd"]
	pending = {}
	await _run(cmd)

func _select(u: AbyssUnit) -> void:
	if u == null or not u.alive:
		return
	selected = u
	mode = "move"
	pending = {}
	for id in unit_nodes:
		unit_nodes[id].get_node("Ring").visible = id == u.id
	create_tween().tween_property(pivot, "position", Vector3(u.cell.x + 0.5, 0, u.cell.y + 0.5), 0.35).set_trans(Tween.TRANS_SINE)
	_clear_overlay()
	_show_reach()
	hud.set_preview("%s : touchez une case pour vous déplacer, ou un ennemi pour tirer." % u.name, false)
	_refresh_hud()

# ---------- aperçus ----------

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _show_reach() -> void:
	if selected == null or not selected.alive or battle.side != "human":
		return
	var r := battle.reach(selected)
	var keep := battle.shot_cost(selected, "snap")
	var tile := BoxMesh.new(); tile.size = Vector3(0.86, 0.02, 0.86)
	for k in r["cost"]:
		if r["cost"][k] == 0:
			continue
		var p := Vector2i(k % battle.grid.w, k / battle.grid.w)
		var ok: bool = selected.tu - r["cost"][k] >= keep
		_mesh(overlay, tile, _cell_pos(p) + Vector3(0, 0.02, 0), _mat("reachOk" if ok else "reachLow", Color("2fd6ff") if ok else Color("ffa63d"), 0, 1, Color("1a90b0") if ok else Color("b06a20"), 0.35))

func _blast(c: Vector2i) -> void:
	var tile := BoxMesh.new(); tile.size = Vector3(0.9, 0.03, 0.9)
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 2, c.x + 3):
			var p := Vector2i(x, y)
			if battle.grid.inside(p):
				_mesh(overlay, tile, _cell_pos(p) + Vector3(0, 0.05, 0), _mat("blast", Color("ff7a3d"), 0, 1, Color("ff5a1d"), 0.4))

func _beam(a: Vector3, b: Vector3, col: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, a.distance_to(b))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	(parent if parent else overlay).add_child(mi)
	mi.global_position = (a + b) / 2.0
	mi.look_at(b, Vector3.UP)
	return mi

# ---------- synchronisation et rejeu ----------

func _visible(u: AbyssUnit) -> bool:
	return u.human or battle.seen_by_humans(u)

func _sync() -> void:
	for u in battle.units:
		var n: Node3D = unit_nodes[u.id]
		n.position = _cell_pos(u.cell)
		n.visible = u.alive and _visible(u)
		n.scale = Vector3(1, 0.8 if u.kneeling else 1.0, 1)
		var lbl: Label3D = n.get_node("Hp")
		lbl.text = "%d%s%s" % [u.hp, " veille" if u.watching else "", " genou" if u.kneeling else ""]
		lbl.modulate = Color("5cf2ff") if u.human else Color("ff6a5a")
		_face(u)
	_refresh_hud()

func _refresh_hud() -> void:
	hud.refresh(battle, selected, mode, busy)

func _wait(t: float) -> void:
	await get_tree().create_timer(t / speed).timeout

func _run(cmd: Dictionary) -> void:
	busy = true
	_clear_overlay()
	hud.set_preview("…", false)
	_refresh_hud()
	var ev := battle.apply(cmd)
	await _play(ev)
	busy = false
	mode = "move"
	if battle.outcome != "ongoing":
		_clear_overlay()
		hud.set_preview("Mission terminée.", false)
		hud.show_end(battle)
		_refresh_hud()
		return
	if selected == null or not selected.alive:
		for s in battle.living(true):
			selected = s
			break
	_select(selected)

func _float(at: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = col
	l.no_depth_test = true
	add_child(l)
	l.global_position = at + Vector3(0, 2.2, 0)
	var tw := create_tween()
	tw.tween_property(l, "global_position:y", at.y + 3.0, 1.0 / minf(speed, 2.0))
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0 / minf(speed, 2.0))
	tw.tween_callback(l.queue_free)

func _flash_light(at: Vector3, col: Color, rng: float, energy: float, dur: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = col
	o.omni_range = rng
	o.light_energy = energy
	add_child(o)
	o.global_position = at + Vector3(0, 1.0, 0)
	var tw := create_tween()
	tw.tween_property(o, "light_energy", 0.0, dur)
	tw.tween_callback(o.queue_free)

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
				var tw := create_tween()
				tw.tween_property(n, "position", to, 0.16 / speed)
				await tw.finished
			"spotted":
				var u := battle.unit(e["unit"])
				unit_nodes[u.id].visible = true
				hud.flash("Contact sonar : %s" % u.name)
				if battle.side != "human":
					create_tween().tween_property(pivot, "position", Vector3(u.cell.x + 0.5, 0, u.cell.y + 0.5), 0.3 / speed)
				await _wait(0.35)
			"interrupt":
				if battle.unit(e["unit"]).human:
					hud.flash("%s s'arrête : contact !" % battle.unit(e["unit"]).name)
			"shot":
				var u := battle.unit(e["unit"])
				var n: Node3D = unit_nodes[u.id]
				n.rotation.y = atan2(float(e["to"].x - e["from"].x), float(e["to"].y - e["from"].y))
				if e["reaction"]:
					hud.flash("Tir de réaction : %s" % u.name)
				var a := _cell_pos(e["from"]) + Vector3(0, 1.0, 0)
				var b := _cell_pos(e["to"]) + Vector3(0, 1.0 if e["target"] != "" else 1.2, 0)
				if not e["hit"]:
					b += Vector3(0.35, 0.3, -0.25)
				var col: Color = {"rifle": Color("9ff3ff"), "pistol": Color("c8f6ff"), "harpoon": Color("ffe08a"), "dart": Color("7dffc4"), "acid": Color("c6ff4d"), "psi": Color("c58bff")}[e["weapon"]]
				var beam := _beam(a, b, col, self)
				_flash_light(a, col, 4.0, 3.0, 0.25)
				if not e["hit"]:
					_float(_cell_pos(e["to"]), "Raté (%d %%)" % e["chance"], Color("c9d6e0"))
				await _wait(0.25)
				beam.queue_free()
			"damage":
				var u := battle.unit(e["unit"])
				_float(_cell_pos(u.cell), "-%d%s" % [e["amount"], " blessé" if e["wounded"] else ""], Color("ff7b6b"))
				await _wait(0.2)
			"death":
				var n: Node3D = unit_nodes[e["unit"]]
				hud.flash("%s neutralisé" % battle.unit(e["unit"]).name)
				var tw := create_tween()
				tw.tween_property(n, "rotation:z", 1.4, 0.4 / speed)
				tw.tween_property(n, "scale", Vector3(1, 0.2, 1), 0.3 / speed)
				await tw.finished
				n.visible = false
			"explosion":
				var at := _cell_pos(e["at"])
				_flash_light(at, Color("ff8a3d"), 9.0, 8.0, 0.7)
				var parts := CPUParticles3D.new()
				var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12
				parts.mesh = sm
				parts.material_override = _mat("spark", Color("ffb060"), 0, 1, Color("ff7a20"))
				parts.amount = 60
				parts.one_shot = true
				parts.explosiveness = 1.0
				parts.lifetime = 0.8
				parts.direction = Vector3.UP
				parts.spread = 80.0
				parts.initial_velocity_min = 2.0
				parts.initial_velocity_max = 6.0
				add_child(parts)
				parts.global_position = at + Vector3(0, 0.4, 0)
				parts.emitting = true
				get_tree().create_timer(1.5).timeout.connect(parts.queue_free)
				await _wait(0.4)
			"destroy", "wall_hit":
				var k := battle.grid.idx(e["at"])
				if e["t"] == "wall_hit":
					_float(_cell_pos(e["at"]), "Cloison fissurée", Color("ffd27a"))
					continue
				if wall_nodes.has(k):
					_collapse(wall_nodes[k])
					wall_nodes.erase(k)
				await _wait(0.15)
			"kneel", "watch":
				pass
			"bleed":
				_float(_cell_pos(battle.unit(e["unit"]).cell), "-%d saignement" % e["amount"], Color("ff9a8a"))
			"turn":
				hud.flash("Activité hostile…" if e["side"] == "alien" else "Tour %d" % e["turn"])
				_refresh_hud()
			"outcome":
				pass
	_sync()

## Effondrement : le bloc se fragmente en morceaux qui tombent et restent en décombres.
func _collapse(n: Node3D) -> void:
	var base := n.position
	var mat := _mat("rubble", Color("3a4650"), 0.5, 0.7)
	for i in 8:
		var s := 0.18 + 0.06 * (i % 3)
		var piece := _box(self, Vector3(s, s, s), base + Vector3(0, 0.4 + (i % 4) * 0.35, 0), mat)
		var target := base + Vector3((i % 3 - 1) * 0.3 + randf_range(-0.1, 0.1), s / 2.0, (i / 3 - 1) * 0.3 + randf_range(-0.1, 0.1))
		var tw := create_tween()
		tw.tween_property(piece, "position", target, 0.45 / speed).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(piece, "rotation", Vector3(randf() * 2, randf() * 2, randf()), 0.45 / speed)
	n.queue_free()

## Partie automatique (tests de performance et de non-régression) : ?autoplay dans l'URL.
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
