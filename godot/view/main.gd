extends Node3D
## Rendu 3D isométrique (vertical slice) : laboratoire sous-marin, éclairage cyan/ambre, contamination violette,
## vitres sur l'océan, coupe automatique des murs côté caméra, brouillard de guerre, effets de tir et de destruction,
## caméra cinématique facultative. Lit AbyssBattle et rejoue ses événements ; n'écrit jamais dans l'état.

const SAVE_PATH := "user://abyss_save.json"
## Habillage propre à chaque carte : lumières [position, couleur, portée, énergie, ombres] et contamination.
const PROPS := {
	"lab": {"lights": [[Vector3(2.5, 2.2, 2.5), Color("ffb547"), 5.0, 1.8, false], [Vector3(5, 2.6, 8.5), Color("8fe8ff"), 7.0, 1.3, false],
			[Vector3(11.5, 2.8, 3), Color("39d9ef"), 6.5, 1.2, false], [Vector3(13.5, 2.0, 8), Color("2ae8ff"), 4.0, 1.4, false],
			[Vector3(14, 2.2, 12), Color("e5484d"), 4.5, 1.6, false], [Vector3(3, 1.4, 11.5), Color("9863f5"), 4.5, 1.9, false],
			[Vector3(9.5, 2.6, 11), Color("ffcf8a"), 5.0, 0.9, false]],
		"goo": [Vector2i(2, 11), Vector2i(3, 12), Vector2i(4, 11), Vector2i(1, 11), Vector2i(5, 12), Vector2i(2, 9)]},
	# ENV-007 : cuve centrale cyan, mezzanines froides, sas ambre, alarme rouge, contamination violette à l'ouest
	"nemesis": {"lights": [[Vector3(7.5, 2.4, 11.5), Color("ffb547"), 5.5, 1.8, false], [Vector3(7.5, 3.2, 3.5), Color("8fe8ff"), 7.5, 1.5, false],
			[Vector3(2.5, 3.0, 2.5), Color("39d9ef"), 5.5, 1.1, false], [Vector3(13.5, 3.0, 2.5), Color("39d9ef"), 5.5, 1.1, false],
			[Vector3(13.5, 2.0, 8), Color("e5484d"), 4.5, 1.6, false], [Vector3(3.5, 1.4, 6.5), Color("9863f5"), 5.0, 1.9, false],
			[Vector3(7.5, 2.6, 7.5), Color("ffcf8a"), 5.0, 0.8, false]],
		"goo": [Vector2i(6, 4), Vector2i(8, 2), Vector2i(4, 6), Vector2i(3, 7), Vector2i(9, 5), Vector2i(6, 2), Vector2i(1, 6)]},
}

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
var world_env: WorldEnvironment
var snow: CPUParticles3D
var quality := "haute"
var hull_mm := {} # coque en MultiMesh : la coupe côté caméra modifie les instances
var fog_layers: Array[MultiMesh] = [] # [inconnu, mémorisé]
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
var audio := AbyssAudio.new()
var dressing := AbyssDressing.new()
var _occl_t := 0.0
var _story := {}
var combat_music := false
var show_intro := true # écran titre + briefing (désactivé par les captures et tests)

func _ready() -> void:
	battle = _load_or_new()
	_build_env()
	add_child(dressing)
	_build_map()
	_build_props()
	for u in battle.units:
		_build_unit(u)
	add_child(overlay)
	_build_camera()
	add_child(audio)
	pivot.add_child(audio.listener) # écouteur au centre de la vue (la caméra orthographique est à 30 m)
	audio.listener.make_current()
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
	if battle.units.any(func(u): return u.carrying):
		dressing.set_alarm(true) # partie reprise pendant l'extraction
	var mobile := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	_apply_quality(_query("q") if _query("q") in ["haute", "moyenne", "basse"] else ("moyenne" if mobile else "haute"))
	hud.set_quality(quality)
	var resumed := battle.turn > 1 or battle.living(true).any(func(u): return u.tu < u.max_tu)
	if resumed:
		hud.flash("Partie reprise (tour %d)" % battle.turn, AbyssHud.CYAN)
	var auto: bool = OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('autoplay')")
	if show_intro and not auto:
		var sc := AbyssScreens.new()
		add_child(sc)
		audio.music("mus_01_abyss_protocol", 0.5)
		sc.closed.connect(_mission_audio)
		sc.show_title(resumed, func():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			get_tree().reload_current_scene())
	else:
		_mission_audio()
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).has('autoplay')"):
		_autoplay()

## Ambiance du labo + musique d'exploration ; passage au thème de combat au premier contact ou à l'alarme.
func _mission_audio() -> void:
	if not _story.has("intro") and battle.turn == 1:
		_story["intro"] = true
		hud.flash("Station Némésis, secteur confinement. Silence radio depuis 72 heures.", AbyssHud.CYAN)
	audio.ambience(true)
	audio.music("mus_03_contact_hostile" if combat_music else "mus_02_silent_depths", 2.0)

func _combat_audio() -> void:
	if not combat_music:
		combat_music = true
		audio.music("mus_03_contact_hostile", 1.5)

func _where(u: AbyssUnit) -> Variant:
	return unit_nodes[u.id].global_position + Vector3(0, 1, 0) if _visible(u) else null

func _query(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('%s') || ''" % key)
	return String(v) if v else ""

## Reprise automatique d'une partie en cours (sauvegarde locale versionnée), sinon nouvelle mission.
func _load_or_new() -> AbyssBattle:
	var seed := _query("seed")
	var map := _query("map") if _query("map") != "" else "nemesis" # ?map=lab : ancien laboratoire
	if seed == "" and FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary and String(d.get("map", "lab")) == map:
			var b := AbyssBattle.from_dict(d)
			if b and b.outcome == "ongoing":
				return b
	return AbyssBattle.new(seed if seed != "" else "thetis-%d" % (int(Time.get_unix_time_from_system()) % 100000), map)

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
	env.ambient_light_color = Color("1e2a34") # refonte V1 : ambiance acier neutre, le bleu devient un accent
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.35
	env.fog_enabled = true
	env.fog_light_color = Color("060d14")
	env.fog_density = 0.025
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	world_env = we
	we.environment = env
	add_child(we)
	# lumière froide filtrée par la surface, ombres dynamiques
	sun.light_color = Color("c4d4e2")
	sun.light_energy = 0.4
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	# fond marin : plancher océanique, roches et neige marine hors de la station
	var w := battle.grid.w
	var h := battle.grid.h
	var sea := _box(self, Vector3(80, 0.2, 80), Vector3(w / 2.0, -3.2, h / 2.0), _mat("seabed", Color("08131d"), 0, 1))
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rock := _mat("rock", Color("0e1a26"), 0.1, 0.9)
	for i in 14:
		var a := i * 0.45
		var r := 13.0 + (i % 4) * 2.5
		var c := SphereMesh.new(); c.radius = 1.0 + (i % 3) * 0.5; c.height = c.radius * (1.0 + (i % 4) * 0.4); c.radial_segments = 7; c.rings = 4
		var rk := _mesh(self, c, Vector3(w / 2.0 + cos(a) * r, -3.2 + c.height * 0.3, h / 2.0 + sin(a) * r), rock)
		rk.rotation = Vector3(i * 0.3, i * 1.1, i * 0.2)
	snow = CPUParticles3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.02; sm.height = 0.04; sm.radial_segments = 4; sm.rings = 2
	snow.mesh = sm
	snow.material_override = _mat("snow", Color("c8e6f5"), 0, 1, Color("6fa8c0"), 0.6)
	snow.amount = 90
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

func _bat(b: Dictionary, key: String, t: Transform3D) -> void:
	if not b.has(key):
		b[key] = []
	b[key].append(t)

func _build_map() -> void:
	var g := battle.grid
	var K := AbyssKit
	var batch := {}
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			var t := g.tile(p)
			var z := g.z(p)
			var c := Vector3(x + 0.5, z, y + 0.5)
			if t == AbyssGrid.T.HULL:
				# coque : haute, hublot sur l'océan un module sur trois ; abaissée automatiquement côté caméra
				var hn := Node3D.new()
				hn.position = Vector3(x + 0.5, 0, y + 0.5)
				add_child(hn)
				var edge := x == 0 or y == 0 or x == g.w - 1 or y == g.h - 1
				var win := edge and (x + y) % 3 == 0 and not ((x == 0 or x == g.w - 1) and (y == 0 or y == g.h - 1))
				var n := Vector3(-1 if x == 0 else (1 if x == g.w - 1 else 0), 0, -1 if y == 0 else (1 if y == g.h - 1 else 0))
				var hk := "hull_w" if win else "hull"
				_bat(batch, hk, Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), hn.position))
				if win and (x + y) % 2 == 0:
					var beam := K.spawn("beam", K.light_beam, hn, Vector3.ZERO, atan2(-n.x, -n.z))
					beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# équipements fixés à la paroi intérieure : conduites (PROP-006), excroissances aliennes (KIT-009)
				if not win and edge and (x * 5 + y) % 4 == 0 and n.length() == 1.0:
					var pipe := K.prop("p006_s1", 0.42)
					pipe.position = -n * 0.56 + Vector3(0, 1.75, 0)
					hn.add_child(pipe)
				elif not win and edge and battle.map_id == "nemesis" and x == 0 and y >= 5 and y <= 8:
					var growth := K.prop("k009_1", 1.1)
					growth.position = -n * 0.55 + Vector3(0, 0.2, 0)
					hn.add_child(growth)
				hull_nodes.append([hn, n, hk, batch[hk].size() - 1])
				continue
			if t == AbyssGrid.T.STAIRS:
				# volée continue : de la hauteur du voisin bas à celle du voisin haut
				var lo := Vector2i.ZERO
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if g.z(p - d) < z and g.z(p + d) > g.z(p - d):
						lo = d
				var z0 := g.z(p - lo)
				var z1 := minf(z0 + 0.5, 1.0)
				_track(p, K.spawn("stairs%s" % z0, K.stairs.bind(z0, z1), self, Vector3(c.x, 0, c.z), -atan2(float(lo.y), float(lo.x))))
				continue
			if z >= 1.0:
				_bat(batch, "deck_high", Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.z)))
			elif t == AbyssGrid.T.WATER:
				_bat(batch, "pool", Transform3D(Basis.IDENTITY, c))
			else:
				_bat(batch, "floor", Transform3D(Basis.IDENTITY, c))
				if battle.in_evac(p): # pourtour du sas seulement
					for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
						if not battle.in_evac(p + d) and g.tile(p + d) != AbyssGrid.T.HULL:
							_bat(batch, "evac_edge", Transform3D(Basis(Vector3.UP, atan2(float(d.x), float(d.y))), c))
			if t == AbyssGrid.T.WALL:
				# orientation : la cloison suit ses voisines
				var along_x := g.tile(p + Vector2i(1, 0)) in [AbyssGrid.T.WALL, AbyssGrid.T.HULL] or g.tile(p - Vector2i(1, 0)) in [AbyssGrid.T.WALL, AbyssGrid.T.HULL]
				var n := Node3D.new()
				n.position = c
				add_child(n)
				K.spawn("wall", K.wall.bind(AbyssData.WALL_H), n, Vector3.ZERO, 0.0 if along_x else PI / 2)
				wall_nodes[g.idx(p)] = n
				_track(p, n)
			elif t == AbyssGrid.T.LOW:
				var n := Node3D.new()
				n.position = c
				add_child(n)
				if p == battle.terminal:
					n.add_child(K.prop("k006_3", 1.25))
					var o := OmniLight3D.new(); o.light_color = Color("52c99a"); o.omni_range = 2.5; o.light_energy = 1.2; o.position = Vector3(0, 1.1, 0.3)
					n.add_child(o)
					n.set_meta("wreck", "k010_2")
				else:
					var cv: Array = K.COVERS[(x * 7 + y * 3) % K.COVERS.size()]
					n.add_child(K.prop(cv[0], cv[1]))
					n.set_meta("wreck", cv[2])
				wall_nodes[g.idx(p)] = n
				_track(p, n)
	# sols, passerelles et bassins : un objet par type de dalle (MultiMesh)
	var makers := {"floor": K.floor_tile.bind(false), "evac_edge": K.evac_edge, "deck_high": K.deck_high, "pool": K.pool,
		"hull": K.hull.bind(false), "hull_w": K.hull.bind(true)}
	for key in batch:
		var mmi := K.batch(self, key, makers[key], batch[key])
		if key.begins_with("hull"):
			hull_mm[key] = mmi.multimesh
	# brouillard : deux couches (inconnu = masqué, mémorisé = assombri), une instance par case
	for alpha in [1.0, 0.62]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := PlaneMesh.new(); q.size = Vector2(1.0, 1.0)
		mm.mesh = q
		mm.instance_count = g.w * g.h
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _mat("fog%s" % alpha, Color("02060a"), 0, 1, Color.BLACK, alpha)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		fog_layers.append(mm)
	var rails := {}
	# garde-corps au bord de la passerelle (lecture des hauteurs)
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			if g.z(p) < 1.0 or g.tile(p) == AbyssGrid.T.HULL:
				continue
			for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]:
				var q: Vector2i = p + d
				if g.z(q) < 1.0 and g.tile(q) != AbyssGrid.T.STAIRS and g.tile(q) != AbyssGrid.T.HULL:
					_bat(rails, "rail", Transform3D(Basis(Vector3.UP, atan2(float(d.x), float(d.y))), Vector3(x + 0.5, 0, y + 0.5)))
	if rails.has("rail"):
		K.batch(self, "rail", K.railing, rails["rail"])

func _build_props() -> void:
	# éclairages façon ENV-007 : ambre au sas, néons cyan du labo, alarme rouge, contamination violette
	dressing.build(self)
	for l in PROPS[battle.map_id]["lights"] if battle.map_id != "nemesis" else []:
		var o := OmniLight3D.new()
		o.position = l[0]; o.light_color = l[1]; o.omni_range = l[2]; o.light_energy = l[3]; o.shadow_enabled = l[4]
		o.omni_attenuation = 1.4
		add_child(o)
		if l[1] == Color("e5484d") or l[1] == Color("9863f5"):
			var tw := create_tween().set_loops()
			tw.tween_property(o, "light_energy", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(o, "light_energy", l[3], 1.1).set_trans(Tween.TRANS_SINE)
	# contamination violette autour du nid (sud-ouest), KIT-009
	for p in PROPS[battle.map_id]["goo"]:
		var gi: int = p.x * 31 + p.y
		var gs := AbyssKit.prop(["k010_5", "k009_6", "k009_4"][gi % 3], [0.45, 0.7, 0.75][gi % 3])
		gs.position = _cell_pos(p) + Vector3(0.18 * ((gi % 3) - 1), 0, 0.15 * ((gi % 2) * 2 - 1))
		add_child(gs)
		_track(p, gs)
	# berceau de confinement Némésis à l'emplacement de l'artefact
	var cr := AbyssKit.spawn("cradle", AbyssKit.cradle, self, _cell_pos(battle.artifact))
	_track(battle.artifact, cr)
	# artefact Némésis : cristal noir aux nervures cyan, en lévitation
	artifact_node = Node3D.new()
	add_child(artifact_node)
	var core := PrismMesh.new(); core.size = Vector3(0.3, 0.45, 0.3)
	var top := _mesh(artifact_node, core, Vector3(0, 1.05, 0), _mat("artifact", Color("0d1620"), 0.9, 0.15, Color("39d9ef")))
	var bottom := _mesh(artifact_node, core, Vector3(0, 0.6, 0), _mat("artifact", Color.BLACK))
	bottom.rotation_degrees.x = 180
	var halo := TorusMesh.new(); halo.inner_radius = 0.26; halo.outer_radius = 0.29
	var hm := _mesh(artifact_node, halo, Vector3(0, 0.82, 0), AbyssKit.mat("led_cyan"))
	hm.rotation_degrees.x = 70
	var al := OmniLight3D.new(); al.light_color = Color("39d9ef"); al.omni_range = 4.5; al.light_energy = 2.4; al.position = Vector3(0, 1.0, 0)
	artifact_node.add_child(al)
	var spin := create_tween().set_loops()
	spin.tween_property(top, "rotation_degrees:y", 360.0, 4.0).from(0.0)
	var spin2 := create_tween().set_loops()
	spin2.tween_property(hm, "rotation_degrees:y", -360.0, 6.0).from(0.0)
	var bob := create_tween().set_loops()
	bob.tween_property(top, "position:y", 1.12, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(top, "position:y", 1.05, 1.6).set_trans(Tween.TRANS_SINE)
	var pulse := create_tween().set_loops()
	pulse.tween_property(al, "light_energy", 1.2, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(al, "light_energy", 2.6, 0.9).set_trans(Tween.TRANS_SINE)

func _build_unit(u: AbyssUnit) -> void:
	var root := Node3D.new()
	root.position = _cell_pos(u.cell)
	add_child(root)
	unit_nodes[u.id] = root
	var body := UnitVisuals.build(u.kind, _mat, u.id)
	body.name = "Body"
	root.add_child(body)
	if u.human:
		var lamp := SpotLight3D.new()
		lamp.name = "Lamp"
		lamp.position = Vector3(0.15, 0.17, 0.09)
		lamp.rotation_degrees = Vector3(-20, 180, 0)
		lamp.spot_range = 5.0
		lamp.spot_angle = 28.0
		lamp.light_energy = 0.7
		lamp.light_color = Color("f2f6ff")
		lamp.shadow_enabled = false # une ombre de projecteur = toute la scène redessinée : réservé à la lumière principale
		var head: Node3D = body.find_child("Head", true, false)
		(head if head else body).add_child(lamp)
	var blob := PlaneMesh.new()
	var bs := 1.7 if u.kind == "carapace" else (0.0 if u.kind == "spectre" else 0.95)
	blob.size = Vector2(bs, bs)
	if bs > 0.0:
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_texture = load("res://assets/textures/fx_pool.png")
		bm.albedo_color = Color(0, 0, 0, 0.62)
		var sh := _mesh(root, blob, Vector3(0, 0.025, 0), bm)
		sh.name = "Contact"
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new(); ring.inner_radius = 0.4; ring.outer_radius = 0.43
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
		var mm: MultiMesh = hull_mm[hn[2]]
		var t := mm.get_instance_transform(hn[3])
		t.basis = Basis(Vector3.UP, atan2((hn[1] as Vector3).x, (hn[1] as Vector3).z)).scaled(Vector3(1, 0.12 if low else 1.0, 1))
		mm.set_instance_transform(hn[3], t)
	dressing.update_cutaway(back)

func _on_setting(key: String, v: Variant) -> void:
	match key:
		"speed": speed = v
		"cine": cine = v
		"shadows":
			sun.shadow_enabled = v
		"quality":
			_apply_quality(v)
		"sound": audio.set_enabled(v)

## Niveaux de qualité. Haute : tout ; Moyenne (défaut sur téléphone) : rendu 3D à 65 % de la résolution native
## (les écrans mobiles sont à 3x) ; Basse : 45 %, sans ombres, sans halo, sans lampes frontales ni neige marine.
func _apply_quality(q: String) -> void:
	quality = q
	dressing.set_quality(q)
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = {"haute": 1.0, "moyenne": 0.65, "basse": 0.45}[q]
	sun.shadow_enabled = q != "basse"
	RenderingServer.directional_shadow_atlas_set_size(2048 if q == "haute" else 1024, true)
	world_env.environment.glow_enabled = q != "basse"
	snow.visible = q != "basse"
	for id in unit_nodes:
		var lamp: Node = unit_nodes[id].find_child("Lamp", true, false)
		if lamp:
			lamp.visible = q != "basse"

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
	audio.ui()
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

## Zone de déplacement : voile très léger + contour fin (cyan = il reste de quoi tirer, ambre = juste marcher).
## La grille s'efface pour laisser voir le sol ; seuls les bords de zone sont tracés.
func _show_reach() -> void:
	if selected == null or not selected.alive or battle.side != "human" or battle.outcome != "ongoing":
		return
	var r := battle.reach(selected)
	var keep := battle.shot_cost(selected, "snap")
	var zone := {}
	for k in r["cost"]:
		if r["cost"][k] > 0:
			zone[k] = 2 if selected.tu - r["cost"][k] >= keep else 1
	var tile := PlaneMesh.new(); tile.size = Vector2(0.96, 0.96)
	var edge_x := BoxMesh.new(); edge_x.size = Vector3(0.96, 0.008, 0.02)
	var edge_z := BoxMesh.new(); edge_z.size = Vector3(0.02, 0.008, 0.96)
	var g := battle.grid
	for k in zone:
		var p := Vector2i(k % g.w, k / g.w)
		var ok: bool = zone[k] == 2
		var col := Color("39d9ef") if ok else Color("ffb547")
		var fill := _mesh(overlay, tile, _cell_pos(p) + Vector3(0, 0.012, 0), _mat("reachFill%s" % ok, col, 0, 1, Color.BLACK, 0.045))
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if zone.get(g.idx(q) if g.inside(q) else -1, 0) >= zone[k]:
				continue
			if not g.inside(q) or g.tile(q) in [AbyssGrid.T.HULL, AbyssGrid.T.WALL, AbyssGrid.T.LOW]:
				continue # le bord d'un mur ou d'un couvert se lit déjà dans le décor
			var e := _mesh(overlay, edge_z if d.x else edge_x, _cell_pos(p) + Vector3(d.x * 0.47, 0.02, d.y * 0.47), _mat("reachEdge%s" % ok, col, 0, 1, col * 0.25, 0.55))
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

## Cloisons et couverts qui cachent une unité (entre elle et la caméra) : rendus translucides.
## Récit de mission : messages à la découverte de la contamination (vue seulement, la simulation n'est pas touchée).
func _process(delta: float) -> void:
	_occl_t += delta
	if _occl_t < 0.2:
		return
	_occl_t = 0.0
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := Vector3(f.z, 0, -f.x)
	var shown: Array[Vector3] = []
	for u in battle.units:
		if u.alive and not u.evacuated and _visible(u):
			shown.append(_cell_pos(u.cell))
	for k in wall_nodes:
		var n: Node3D = wall_nodes[k]
		if not is_instance_valid(n):
			continue
		var hide := false
		for at in shown:
			var d := at - n.position
			var depth := d.dot(f)
			if depth > 0.2 and depth < 2.6 and absf(d.dot(side)) < 0.75 and at.y <= n.position.y + 0.1:
				hide = true
				break
		for c in n.get_children():
			if c is GeometryInstance3D:
				(c as GeometryInstance3D).transparency = 0.6 if hide else 0.0
	# contamination : premier soldat à moins de 2 cases d'une excroissance
	if not _story.has("goo") and battle.side == "human":
		for u in battle.living(true):
			for gp in PROPS[battle.map_id]["goo"]:
				if maxi(absi(u.cell.x - gp.x), absi(u.cell.y - gp.y)) <= 2:
					_story["goo"] = true
					hud.flash("Contamination extraterrestre : tissus biomécaniques sur les parois…", Color("b48cff"))
					audio.sfx("nereid_alert", null, -14.0, 0.6)
					break
			if _story.has("goo"):
				break

func _sync() -> void:
	for u in battle.units:
		var n: Node3D = unit_nodes[u.id]
		n.position = _cell_pos(u.cell)
		n.visible = (u.alive and _visible(u) or n.has_meta("corpse")) and not u.evacuated
		var ap: AnimationPlayer = n.get_node_or_null("Body/Anim")
		if ap and u.alive:
			if u.kneeling and ap.has_animation("kneel") and ap.assigned_animation != "kneel":
				ap.play("kneel", 0.15)
			elif not u.kneeling and ap.assigned_animation == "kneel":
				ap.play("idle", 0.2)
		elif not ap:
			(n.get_node("Body") as Node3D).scale = Vector3(1, 0.78 if u.kneeling else 1.0, 1)
		n.rotation.y = atan2(float(u.facing.x), float(u.facing.y))
		var lbl: Label3D = n.get_node("Hp")
		lbl.visible = u.alive
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
	var hide := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k in cell_nodes:
		for n in cell_nodes[k]:
			if is_instance_valid(n):
				n.visible = battle.explored[k] == 1
	for k in g.w * g.h:
		var p := Vector2i(k % g.w, k / g.w)
		var known := battle.explored[k] == 1
		var hull := g.tile(p) == AbyssGrid.T.HULL
		var seen := known and not hull and battle.living(true).any(func(h): return g.can_see(h, p, 0.3))
		var at := Transform3D(Basis.IDENTITY, _cell_pos(p) + Vector3(0, 0.035, 0))
		fog_layers[0].set_instance_transform(k, at if not known and not hull else hide)
		fog_layers[1].set_instance_transform(k, at if known and not seen and not hull else hide)

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
		audio.music("mus_01_abyss_protocol", 2.0)
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

## Caméra : suit en douceur une unité qui se déplace hors du centre de l'écran.
func _follow(at: Vector3) -> void:
	var flat := Vector3(at.x, 0, at.z)
	if flat.distance_to(pivot.position) > cam.size * 0.32:
		create_tween().tween_property(pivot, "position", pivot.position.lerp(flat, 0.6), 0.45 / speed).set_trans(Tween.TRANS_SINE)

## Secousse brève, proportionnelle à la violence du coup.
func _shake(power: float) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(cam, "v_offset", power * (1.0 if i % 2 else -1.0) * (1.0 - i * 0.22), 0.035)
	tw.tween_property(cam, "v_offset", 0.0, 0.05)

## Joue une animation du modèle articulé (fondu court) ; les animations ponctuelles reviennent au repos.
func _anim(n: Node3D, name: String) -> bool:
	var ap: AnimationPlayer = n.get_node_or_null("Body/Anim")
	if not ap or not ap.has_animation(name):
		return false
	ap.speed_scale = speed
	if ap.current_animation == name and ap.get_animation(name).loop_mode != Animation.LOOP_NONE:
		return true
	ap.play(name, 0.12)
	if name in ["shoot", "hit"]:
		ap.queue("idle")
	return true

func _walk_bob(n: Node3D, dur: float) -> void:
	if _anim(n, "walk"):
		return
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
				_follow(to)
				if u.kind != "spectre":
					audio.sfx("step_metal", to, -9.0 if u.human else -11.0, 1.0 if u.human else (0.75 if u.kind == "carapace" else 1.15), 0.12)
				var tw := create_tween()
				tw.tween_property(n, "position", to, dur)
				await tw.finished
				if u.human:
					_fog()
			"spotted":
				var u := battle.unit(e["unit"])
				unit_nodes[u.id].visible = true
				hud.flash("Contact sonar : %s" % u.name, AbyssHud.RED)
				audio.sfx("nereid_alert" if u.kind == "nereide" else "sonar_signature", null, -2.0)
				_combat_audio()
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
				if not _anim(n, "shoot"):
					var body: Node3D = n.get_node("Body")
					var kick := create_tween()
					kick.tween_property(body, "position:z", -0.08, 0.05)
					kick.tween_property(body, "position:z", 0.0, 0.12)
				# départ : flash de bouche (VFX-001) ou onde psychique (VFX-008), puis projectile visible
				var w: String = e["weapon"]
				_flash_light(a, col, 4.0, 4.0, 0.2)
				var snd: Array = {"rifle": ["rifle_fire", 1.0, 0.0], "pistol": ["rifle_fire", 1.25, -4.0], "harpoon": ["harpoon_fire", 1.0, 0.0],
					"dart": ["alien_plasma", 1.1, -2.0], "acid": ["alien_plasma", 0.7, 0.0], "psi": ["spectre_psionic", 1.0, -1.0]}[w]
				audio.sfx(snd[0], _where(u), snd[2], snd[1])
				if w == "psi":
					AbyssFx.ring(self, a, Color(col, 0.9), 1.0, 0.3 / speed, false)
					await _wait(0.18)
				else:
					AbyssFx.flash(self, a, col.lightened(0.4), 0.8 if w in ["rifle", "pistol", "harpoon"] else 0.45)
					if w in ["rifle", "pistol", "harpoon"]:
						AbyssFx.smoke(self, a, 2, 0.25, 0.7, Color(0.7, 0.72, 0.75, 0.3))
					var ps: Array = {"rifle": [45.0, 0.16, 0.0], "pistol": [40.0, 0.14, 0.0], "harpoon": [18.0, 0.22, 0.05],
						"dart": [22.0, 0.22, 0.0], "acid": [11.0, 0.32, 0.8]}[w]
					await AbyssFx.projectile(self, a, b, col, ps[0] * speed, ps[1], ps[2])
				# impact selon la surface touchée
				var victim := battle.units.filter(func(x): return x.cell == e["to"])
				var surf := "metal"
				if w == "acid":
					surf = "acid"
					AbyssFx.puddle(self, _cell_pos(e["to"]), Color(0.45, 0.95, 0.2, 0.75), 0.9)
				elif w == "psi":
					surf = "psi"
				elif e["hit"] and not victim.is_empty():
					surf = "human" if victim[0].human else "alien"
				AbyssFx.impact(self, b, surf)
				if surf in ["human", "metal"]:
					audio.sfx("armor_impact", b, -3.0 if surf == "human" else -8.0, 1.0 if surf == "human" else 1.2)
				if not e["hit"]:
					_float(_cell_pos(e["to"]), "Raté (%d %%)" % e["chance"], Color("c9d6e0"))
				await _wait(0.22)
				if cinematic:
					_cine_out(size)
			"damage":
				var u := battle.unit(e["unit"])
				var n: Node3D = unit_nodes[u.id]
				_float(_cell_pos(u.cell), "-%d%s" % [e["amount"], " blessé" if e["wounded"] else ""], Color("ff7b6b"))
				if e["amount"] >= 20:
					_shake(0.05 + e["amount"] * 0.002)
				if e["drained"] > 0:
					hud.flash("%s désorienté : -%d UT au prochain tour" % [u.name, e["drained"]], Color("9863f5"))
				if not _anim(n, "hit"):
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
				if _anim(n, "death"):
					n.set_meta("corpse", true) # le corps reste au sol
					await _wait(0.7)
					_sparks(n.global_position + Vector3(0, 0.3, 0), Color("9863f5") if not u.human else Color("e5484d"), 10, 1.5, 0.6)
					await _wait(0.4)
				else:
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
				AbyssFx.explosion(self, at)
				audio.sfx("grenade_blast", at)
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
					audio.sfx("grenade_blast", _cell_pos(e["at"]), -7.0, 1.35)
					wall_nodes.erase(k)
				await _wait(0.15)
			"heal":
				var t := battle.unit(e["target"])
				_float(_cell_pos(t.cell), "+%d PV" % e["amount"], Color("52c99a"))
				_flash_light(_cell_pos(t.cell) + Vector3(0, 1, 0), Color("52c99a"), 3.0, 2.0, 0.6)
				AbyssFx.ring(self, _cell_pos(t.cell) + Vector3(0, 0.05, 0), Color(0.3, 1.0, 0.75, 0.9), 0.8, 0.6) # VFX-010
				AbyssFx.burst(self, _cell_pos(t.cell) + Vector3(0, 0.2, 0), "spark", Color(0.4, 1.0, 0.8), 16, 1.6, 0.9, 0.3, true, Vector3(0, 1.5, 0), 1.0, 15.0, Vector3.UP, true)
				await _wait(0.3)
			"reload":
				_float(_cell_pos(battle.unit(e["unit"]).cell), "Rechargé", Color("c9e6ff"))
			"pickup":
				hud.flash("%s récupère l'artefact" % battle.unit(e["unit"]).name, AbyssHud.CYAN)
				artifact_node.visible = false
				audio.sfx("artifact_pulse", null, -1.0)
			"alarm":
				hud.flash("L'artefact pulse : tous les hostiles convergent ! Regagnez le sas !", AbyssHud.RED)
				dressing.set_alarm(true)
				_combat_audio()
				_flash_light(_cell_pos(battle.unit(events.filter(func(x): return x["t"] == "pickup")[0]["unit"]).cell) + Vector3(0, 1, 0), Color("39d9ef"), 14.0, 6.0, 1.2)
				await _wait(0.6)
			"logs":
				hud.flash("Journal du terminal téléchargé", AbyssHud.GREEN)
				audio.sfx("sonar_signature", null, -6.0, 1.2)
			"drop":
				hud.flash("L'artefact est tombé au sol", AbyssHud.RED)
			"bleed":
				_float(_cell_pos(battle.unit(e["unit"]).cell), "-%d saignement" % e["amount"], Color("ff9a8a"))
			"turn":
				hud.flash("Activité hostile…" if e["side"] == "alien" else "Tour %d" % e["turn"], AbyssHud.RED if e["side"] == "alien" else AbyssHud.CYAN)
				_refresh_hud()
			"evacuate":
				audio.sfx("airlock", null, -2.0)
				for id in e["units"]:
					var n: Node3D = unit_nodes[id]
					create_tween().tween_property(n, "position:y", n.position.y + 3.0, 0.6)
				await _wait(0.6)
	for id in unit_nodes:
		var ap: AnimationPlayer = unit_nodes[id].get_node_or_null("Body/Anim")
		if ap and ap.current_animation == "walk":
			ap.play("idle", 0.25)
	_sync()

## Effondrement : le bloc se fragmente, les morceaux rebondissent et restent ; poussière brève.
func _collapse(n: Node3D) -> void:
	var base := n.position
	var wreck := AbyssKit.prop(String(n.get_meta("wreck", "k010_2")), 0.55)
	wreck.position = base
	add_child(wreck)
	_sparks(base + Vector3(0, 0.6, 0), Color("8aa0b0"), 24, 3.0, 0.7)
	for i in 7:
		var s := 0.16 + 0.06 * (i % 3)
		var piece := _mesh(self, AbyssKit.rubble_chunk(s), base + Vector3(0, 0.4 + (i % 4) * 0.35, 0), AbyssKit.mat("plate"))
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
		audio.music("mus_01_abyss_protocol", 2.0)
