class_name AbyssDressing
extends Node3D
## Habillage et atmosphère de la salle (refonte V1, directive DA du 25/11) :
## - objets peints des planches KIT / PROP de Max adossés aux parois (machines, cuves, baies, générateurs),
##   contamination biomécanique côté ouest ; masqués quand la paroi est abaissée par la coupe caméra ;
## - lumière : peu de vraies lumières (chaque lumière coûte une passe de rendu en WebGL) mais des « flaques »
##   de lumière au sol gratuites, néon qui grésille, alarme rouge qui s'allume à l'extraction ;
## - particules : poussière en suspension, vapeur des conduites, fuite d'eau, étincelles d'une console cassée.
## Aucun effet sur la simulation : purement visuel.

const POOL_TEX := "res://assets/textures/fx_pool.png"
## objets muraux : [sprite, hauteur (m)]
const WALL_TECH := [["k006_2", 2.0], ["k007_3", 1.05], ["k008_3", 1.7], ["p005_s1", 1.05], ["k007_6", 1.1], ["k008_4", 1.45],
	["k006_5", 1.0], ["k007_2", 1.0], ["k005_3", 1.25], ["p008_s1", 0.9], ["k008_1", 1.15], ["k006_1", 1.0]]
const WALL_ALIEN := [["k009_1", 1.6], ["k009_5", 1.5], ["k009_2", 1.9], ["k009_6", 1.4]]

var main: Node
var decor: Array = [] # [Node3D, normale de la paroi]
var emergency: Array[OmniLight3D] = []
var beacons: Array[Node3D] = []
var ambient_fx: Array[Node] = []
var spark_at := Vector3.ZERO
var _t := 0.0
var _next_spark := 3.0

func build(m: Node) -> void:
	main = m
	var g: AbyssGrid = main.battle.grid
	var nem: bool = main.battle.map_id == "nemesis"
	var k := 0
	var steam_spots: Array[Vector3] = []
	for y in g.h:
		for x in g.w:
			var p := Vector2i(x, y)
			if g.tile(p) != AbyssGrid.T.HULL:
				continue
			# paroi qui donne sur une case intérieure
			var inner := Vector2i(-99, -99)
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if g.inside(p + d) and g.tile(p + d) not in [AbyssGrid.T.HULL, AbyssGrid.T.STAIRS]:
					inner = p + d
					break
			if inner.x < -50:
				continue
			k += 1
			var edge := x == 0 or y == 0 or x == g.w - 1 or y == g.h - 1
			var window := edge and (x + y) % 3 == 0
			if window or k % 2 == 1:
				continue
			var n := Vector3(p.x - inner.x, 0, p.y - inner.y) # normale vers l'extérieur
			var at := Vector3(inner.x + 0.5, g.z(inner), inner.y + 0.5) + n * 0.42
			var alien := nem and x <= 3 and y >= 4 and y <= 9
			var list: Array = WALL_ALIEN if alien else WALL_TECH
			var pick: Array = list[(x * 5 + y * 3) % list.size()]
			var sp: Sprite3D = AbyssKit.prop(pick[0], pick[1], true)
			sp.position = at
			add_child(sp)
			decor.append([sp, n])
			if pick[0] in ["p005_s1", "k007_3", "k007_6"] and steam_spots.size() < 3:
				steam_spots.append(at + Vector3(0, pick[1] * 0.8, 0))
	_lights(nem)
	_particles(nem, steam_spots)

## Masque les objets adossés aux parois abaissées (coupe façon maquette côté caméra).
func update_cutaway(back: Vector3) -> void:
	for d in decor:
		(d[0] as Node3D).visible = (d[1] as Vector3).dot(back) <= 0.3

func _pool(at: Vector3, col: Color, radius: float, alpha: float) -> MeshInstance3D:
	var q := PlaneMesh.new()
	q.size = Vector2(radius * 2, radius * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load(POOL_TEX)
	m.albedo_color = Color(col, alpha)
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	add_child(mi)
	return mi

func _light(at: Vector3, col: Color, rng: float, energy: float, pool_r := 0.0, pool_a := 0.16, floor_y := 0.03) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = col
	o.omni_range = rng
	o.light_energy = energy
	o.omni_attenuation = 1.3
	add_child(o)
	if pool_r > 0.0:
		_pool(Vector3(at.x, floor_y, at.z), col, pool_r, pool_a)
	return o

func _lights(nem: bool) -> void:
	if not nem:
		return
	# lumière industrielle chaude sur la cuve, blanche sur le sas, froide sur les mezzanines
	_light(Vector3(7.5, 3.0, 2.0), Color("ffe9cc"), 7.0, 2.0, 3.0, 0.3)
	_light(Vector3(7.5, 2.6, 11.2), Color("fff1dd"), 5.5, 1.6, 2.6, 0.24)
	_light(Vector3(6.0, 2.8, 7.0), Color("e8eef5"), 6.0, 1.2, 2.4, 0.2) # plafonnier central
	_pool(Vector3(2.2, 1.03, 2.5), Color("39d9ef"), 1.6, 0.12)
	_pool(Vector3(13.2, 1.03, 2.5), Color("39d9ef"), 1.6, 0.12)
	_light(Vector3(13.2, 2.8, 2.4), Color("8fe8ff"), 4.5, 0.8)
	# contamination violette pulsée (ouest)
	var vio := _light(Vector3(2.8, 1.3, 6.8), Color("9863f5"), 5.0, 1.9, 2.4, 0.3)
	var tw := create_tween().set_loops()
	tw.tween_property(vio, "light_energy", 0.7, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(vio, "light_energy", 1.9, 1.4).set_trans(Tween.TRANS_SINE)
	# néon qui grésille au-dessus de la zone centrale
	var flick := _light(Vector3(10.5, 2.6, 6.5), Color("dff4ff"), 4.5, 1.3, 2.0, 0.2)
	flick.set_meta("flicker", true)
	ambient_fx.append(flick)
	# alarme d'extraction : éteinte jusqu'à la prise de l'artefact
	for at in [Vector3(1.4, 2.3, 10.5), Vector3(14.6, 2.3, 10.5), Vector3(7.5, 2.5, 0.8)]:
		var r := _light(at, Color("ff3b3b"), 6.0, 0.0)
		emergency.append(r)
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.09; s.height = 0.12; s.radial_segments = 8; s.rings = 4
		b.mesh = s
		b.material_override = AbyssKit.mat("led_red")
		b.position = at
		b.visible = false
		add_child(b)
		beacons.append(b)

## Alarme rouge tournante pendant l'extraction (déclenchée par l'événement « alarm »).
func set_alarm(on: bool) -> void:
	for i in emergency.size():
		var r := emergency[i]
		beacons[i].visible = on
		if on:
			var tw := create_tween().set_loops()
			tw.tween_interval(i * 0.25)
			tw.tween_property(r, "light_energy", 2.4, 0.25)
			tw.tween_property(r, "light_energy", 0.2, 0.5)
		else:
			r.light_energy = 0.0

func _particles(nem: bool, steam_spots: Array[Vector3]) -> void:
	var g: AbyssGrid = main.battle.grid
	# poussière en suspension, visible dans les flaques de lumière
	var dust := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	dust.mesh = q
	dust.material_override = AbyssFx.mat("flash", true)
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(g.w / 2.0, 1.2, g.h / 2.0)
	dust.position = Vector3(g.w / 2.0, 1.4, g.h / 2.0)
	dust.gravity = Vector3(0, -0.01, 0)
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	dust.spread = 180.0
	dust.color = Color(0.75, 0.85, 0.95, 0.35)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	ambient_fx.append(dust)
	# vapeur des machines et conduites
	for at in steam_spots:
		var st := CPUParticles3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(0.5, 0.5)
		st.mesh = sq
		st.material_override = AbyssFx.mat("smoke", false)
		st.amount = 10
		st.lifetime = 2.6
		st.preprocess = 2.6
		st.direction = Vector3(0, 1, 0)
		st.spread = 18.0
		st.initial_velocity_min = 0.25
		st.initial_velocity_max = 0.45
		st.gravity = Vector3(0.05, 0.05, 0)
		var c := Curve.new()
		c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(1, 1.6))
		st.scale_amount_curve = c
		st.color_ramp = AbyssFx._fade(Color(0.78, 0.82, 0.86, 0.22), 0.3)
		st.position = at
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(st)
		ambient_fx.append(st)
	if not nem:
		return
	# fuite d'eau sous un hublot (est) : gouttes + flaque luisante
	var drip := CPUParticles3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.03, 0.12)
	drip.mesh = dq
	drip.material_override = AbyssFx.mat("spark", true)
	drip.amount = 14
	drip.lifetime = 0.9
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drip.emission_box_extents = Vector3(0.25, 0.02, 0.05)
	drip.direction = Vector3(0, -1, 0)
	drip.spread = 2.0
	drip.gravity = Vector3(0, -9.8, 0)
	drip.initial_velocity_min = 0.0
	drip.initial_velocity_max = 0.2
	drip.color = Color(0.6, 0.85, 1.0, 0.5)
	drip.position = Vector3(14.45, 2.2, 8.5)
	drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drip)
	ambient_fx.append(drip)
	AbyssFx.puddle(self, Vector3(14.2, 0.0, 8.5), Color(0.35, 0.6, 0.8, 0.45), 1.1, 1e9)
	# console cassée qui crache des étincelles (est du sas)
	var wreck: Sprite3D = AbyssKit.prop("k010_4", 1.0, true)
	wreck.position = Vector3(13.5, 0, 12.4)
	add_child(wreck)
	decor.append([wreck, Vector3(0, 0, 1)])
	spark_at = Vector3(13.5, 0.85, 12.3)

func set_quality(q: String) -> void:
	for f in ambient_fx:
		if f is CPUParticles3D:
			(f as CPUParticles3D).emitting = q != "basse"
			(f as CPUParticles3D).visible = q != "basse"

func _process(delta: float) -> void:
	_t += delta
	for f in ambient_fx:
		if f is OmniLight3D and f.has_meta("flicker"):
			var o := f as OmniLight3D
			o.light_energy = 1.1 if fmod(_t * 7.3, 5.0) > 0.35 and fmod(_t * 2.1, 9.0) > 0.5 else randf_range(0.05, 0.4)
	if spark_at != Vector3.ZERO and _t > _next_spark and main.quality != "basse":
		_next_spark = _t + randf_range(2.5, 6.0)
		AbyssFx.burst(self, spark_at, "spark", Color(1.0, 0.8, 0.45), 10, 3.0, 0.45, 0.22, true, Vector3(0, -9.8, 0), 1.0, 60.0, Vector3.UP, true)
		AbyssFx.flash(self, spark_at, Color(1.0, 0.85, 0.6), 0.5, 0.08)
