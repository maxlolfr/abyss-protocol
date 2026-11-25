class_name AbyssFx
extends RefCounted
## Effets de combat d'après les planches VFX-001 à 015 de Max (départ, montée, pic, dissipation) :
## flash de bouche étoilé, projectiles avec traînée, étincelles en traits, fumée qui monte et se dissipe,
## boule de feu, onde psychique, éclaboussure et flaque d'acide. Sprites : assets/textures/fx_*.png.
## Tout est en particules CPU et billboards additifs : compatible WebGL 2 (iPhone, Android, iPad).

const TEX := "res://assets/textures/fx_%s.png"
static var _mats := {}

static func mat(tex: String, add := true, billboard := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var key := "%s%s%d" % [tex, add, billboard]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = load(TEX % tex)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mats[key] = m
	return m

static func _fade(c: Color, mid := 0.25) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c, 0.0))
	g.add_point(mid * 0.4, Color(c, c.a))
	g.add_point(mid, Color(c, c.a * 0.85))
	g.set_color(g.get_point_count() - 1, Color(c.darkened(0.3), 0.0))
	return g

## Gerbe de particules ponctuelle (se détruit seule).
static func burst(parent: Node3D, at: Vector3, tex: String, col: Color, amount: int, vel: float, life: float, size: float,
		add := true, gravity := Vector3.ZERO, grow := 1.0, spread := 180.0, dir := Vector3.UP, align := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (0.18 if tex == "spark" else 1.0))
	p.mesh = q
	p.material_override = mat(tex, add, BaseMaterial3D.BILLBOARD_DISABLED if align else BaseMaterial3D.BILLBOARD_PARTICLES)
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel * 0.45
	p.initial_velocity_max = vel
	p.gravity = gravity
	p.damping_min = vel * 0.6
	p.damping_max = vel * 1.2
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.particle_flag_align_y = align
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	if grow != 1.0:
		var c := Curve.new()
		c.add_point(Vector2(0, 1.0 / grow))
		c.add_point(Vector2(1, 1.0))
		p.scale_amount_curve = c
	p.color_ramp = _fade(col)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p

## Flash étoilé bref (VFX-001), tourné au hasard.
static func flash(parent: Node3D, at: Vector3, col: Color, size: float, dur := 0.09) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := mat("flash", true, BaseMaterial3D.BILLBOARD_ENABLED).duplicate() as StandardMaterial3D
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	mi.rotation.z = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6, dur).from(Vector3.ONE * 0.4)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)

## Fumée qui monte et se dissipe (VFX-005, 011).
static func smoke(parent: Node3D, at: Vector3, amount: int, size: float, life := 1.6, col := Color(0.55, 0.6, 0.65, 0.5)) -> void:
	burst(parent, at, "smoke", col, amount, 0.8, life, size, false, Vector3(0, 0.35, 0), 2.6, 70.0)

## Projectile visible avec traînée, de a vers b ; attendre `await` le retour pour enchaîner l'impact.
static func projectile(parent: Node3D, a: Vector3, b: Vector3, col: Color, speed: float, size: float, arc := 0.0) -> void:
	var head := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	head.mesh = q
	var hm := mat("flash", true, BaseMaterial3D.BILLBOARD_ENABLED).duplicate() as StandardMaterial3D
	hm.albedo_color = col
	head.material_override = hm
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(head)
	head.global_position = a
	var trail := CPUParticles3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(size * 0.7, size * 0.7)
	trail.mesh = tq
	trail.material_override = mat("smoke", true)
	trail.amount = 48
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.05
	trail.color_ramp = _fade(Color(col, 0.7), 0.1)
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 0.1))
	trail.scale_amount_curve = sc
	head.add_child(trail)
	var dur := maxf(a.distance_to(b) / speed, 0.04)
	var tw := head.create_tween()
	tw.tween_method(func(t: float):
		head.global_position = a.lerp(b, t) + Vector3(0, arc * 4.0 * t * (1.0 - t), 0), 0.0, 1.0, dur)
	await tw.finished
	trail.emitting = false
	head.visible = false
	parent.get_tree().create_timer(0.3).timeout.connect(head.queue_free)

## Onde annulaire : au sol (à plat) ou face caméra (onde psychique VFX-008, EMP VFX-006).
static func ring(parent: Node3D, at: Vector3, col: Color, radius: float, dur: float, flat := true) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := mat("ring", true, BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED).duplicate() as StandardMaterial3D
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)

## Flaque qui reste quelques secondes (acide VFX-009, ichor alien).
static func puddle(parent: Node3D, at: Vector3, col: Color, size: float, life := 4.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := mat("splat", false, BaseMaterial3D.BILLBOARD_DISABLED).duplicate() as StandardMaterial3D
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.015, 0)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).from(Vector3.ONE * 0.2)
	tw.tween_interval(life)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(mi.queue_free)

## Explosion à fragmentation (VFX-005) : flash, boule de feu, éclats, fumée qui monte, onde au sol.
static func explosion(parent: Node3D, at: Vector3, scale := 1.0) -> void:
	flash(parent, at + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.6), 3.2 * scale, 0.16)
	burst(parent, at + Vector3(0, 0.4, 0), "smoke", Color(1.0, 0.55, 0.18, 1.0), 26, 3.4 * scale, 0.6, 1.7 * scale, true, Vector3(0, 1.2, 0), 2.4)
	burst(parent, at + Vector3(0, 0.5, 0), "flash", Color(1.0, 0.75, 0.4, 0.9), 6, 1.2 * scale, 0.35, 1.6 * scale, true, Vector3.ZERO, 1.8)
	burst(parent, at + Vector3(0, 0.3, 0), "spark", Color(1.0, 0.8, 0.45), 40, 9.0 * scale, 0.7, 0.5, true, Vector3(0, -9.8, 0), 1.0, 75.0, Vector3.UP, true)
	ring(parent, at + Vector3(0, 0.05, 0), Color(1.0, 0.7, 0.4, 0.8), 3.0 * scale, 0.45)
	smoke(parent, at + Vector3(0, 0.5, 0), 16, 1.4 * scale, 2.4, Color(0.32, 0.33, 0.35, 0.55))

## Impact selon la surface : métal (étincelles + fumée), chair humaine, chair alienne, acide, psi.
static func impact(parent: Node3D, at: Vector3, kind: String) -> void:
	match kind:
		"metal":
			flash(parent, at, Color(1.0, 0.85, 0.55), 0.6, 0.06)
			burst(parent, at, "spark", Color(1.0, 0.82, 0.5), 16, 5.0, 0.4, 0.28, true, Vector3(0, -9.8, 0), 1.0, 70.0, Vector3.UP, true)
			smoke(parent, at, 3, 0.4, 0.9, Color(0.6, 0.62, 0.65, 0.35))
		"human":
			flash(parent, at, Color(1.0, 0.6, 0.5), 0.45, 0.05)
			burst(parent, at, "smoke", Color(0.75, 0.08, 0.06, 0.9), 10, 2.2, 0.45, 0.16, false, Vector3(0, -6, 0))
		"alien":
			flash(parent, at, Color(0.7, 0.5, 1.0), 0.5, 0.06)
			burst(parent, at, "smoke", Color(0.55, 0.25, 0.95, 0.9), 12, 2.4, 0.5, 0.18, true, Vector3(0, -6, 0))
		"acid":
			burst(parent, at, "splat", Color(0.55, 1.0, 0.25, 0.9), 14, 3.0, 0.55, 0.22, true, Vector3(0, -7, 0))
			smoke(parent, at, 6, 0.6, 1.4, Color(0.5, 0.9, 0.3, 0.35))
		"psi":
			ring(parent, at, Color(0.75, 0.5, 1.0, 0.9), 1.6, 0.4, false)
			burst(parent, at, "spark", Color(0.8, 0.6, 1.0), 14, 2.5, 0.5, 0.35, true, Vector3.ZERO, 1.0, 180.0, Vector3.UP, true)
