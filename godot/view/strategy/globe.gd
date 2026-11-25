class_name AbyssGlobe
extends Node3D
## Globe 3D du géoscape : terre stylisée (tools/gen_globe.py), jour/nuit selon l'heure de la campagne,
## grille sonar, halo d'atmosphère, tracés (couverture sonar, routes, zones d'incertitude) sur la surface.
## Caméra en orbite : glisser pour tourner, pincer / molette pour zoomer.

const GLOBE_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D earth : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(0.0, 0.0, 1.0);
uniform float grid_strength = 0.35;
varying vec3 obj_n;
void vertex() { obj_n = normalize(VERTEX); }
void fragment() {
	vec3 n = normalize(obj_n);
	float lon = atan(n.x, n.z);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	vec2 uv = vec2(lon / 6.2831853 + 0.5, 0.5 - lat / 3.1415927);
	vec2 uv2 = vec2(fract(uv.x + 0.5), uv.y);
	vec2 dx = dFdx(uv), dy = dFdy(uv);
	vec2 dx2 = dFdx(uv2), dy2 = dFdy(uv2);
	if (dot(dx2, dx2) + dot(dy2, dy2) < dot(dx, dx) + dot(dy, dy)) { dx = dx2; dy = dy2; }
	vec3 col = textureGrad(earth, uv, dx, dy).rgb;
	// grille sonar : parallèles et méridiens tous les 15°
	vec2 deg = vec2(degrees(lon), degrees(lat)) / 15.0;
	vec2 g = abs(fract(deg - 0.5) - 0.5) / fwidth(deg);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	col += vec3(0.1, 0.55, 0.65) * line * grid_strength;
	// jour / nuit (terminateur doux), la nuit reste lisible
	float day = smoothstep(-0.12, 0.22, dot(n, normalize(sun_dir)));
	col *= mix(0.42, 1.08, day);
	// liseré froid vers le bord
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col += vec3(0.05, 0.35, 0.45) * pow(rim, 3.0) * 0.9;
	ALBEDO = col;
}
"""

const ATMO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
void fragment() {
	float f = pow(clamp(1.0 + dot(NORMAL, VIEW), 0.0, 1.0), 10.0);
	ALBEDO = vec3(0.12, 0.62, 0.78) * f * 0.4;
}
"""

var cam := Camera3D.new()
var view := Vector2(30, -30) # latitude, longitude regardées
var dist := 3.7
var globe := MeshInstance3D.new()
var lines := MeshInstance3D.new()
var _im := ImmediateMesh.new()
var _mat: ShaderMaterial
var _touches := {}
var _pinch := 0.0
var _dragged := 0.0
var _target_view = null # recentrage animé

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030a12")
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 96
	sm.rings = 48
	globe.mesh = sm
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLOBE_SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("earth", load("res://assets/strategy/earth.jpg"))
	globe.material_override = _mat
	add_child(globe)
	var atmo := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = 1.035
	am.height = 2.07
	am.radial_segments = 64
	am.rings = 32
	atmo.mesh = am
	var amat := ShaderMaterial.new()
	var ash := Shader.new()
	ash.code = ATMO_SHADER
	amat.shader = ash
	atmo.material_override = amat
	add_child(atmo)
	lines.mesh = _im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lines.material_override = lm
	add_child(lines)
	_stars()
	cam.fov = 40
	cam.h_offset = 0.32 # le globe se décale à gauche du panneau latéral
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	_place_cam()

func _stars() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	mm.mesh = q
	mm.instance_count = 500
	for i in 500:
		var v := Vector3(r.randfn(), r.randfn(), r.randfn()).normalized() * 30.0
		mm.set_instance_transform(i, Transform3D(Basis.looking_at(-v), v))
		var b := r.randf_range(0.2, 0.8)
		mm.set_instance_color(i, Color(b * 0.8, b * 0.95, b, 1))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	add_child(mi)

func _place_cam() -> void:
	view.x = clampf(view.x, -80, 80)
	view.y = wrapf(view.y, -180, 180)
	var d := AbyssGeo.to_vec(view)
	cam.position = d * dist
	cam.look_at(Vector3.ZERO, Vector3.UP)

## Soleil d'après la date de la campagne (longitude subsolaire = heure UTC, déclinaison = saison).
func set_time(c: AbyssCampaign) -> void:
	var d := c.date()
	var hour := float(d["hour"]) + float(d["minute"]) / 60.0
	var doy := float(c.minutes) / 1440.0 + 60.0
	var decl := 23.44 * sin(TAU * (doy - 80.0) / 365.0)
	_mat.set_shader_parameter("sun_dir", AbyssGeo.to_vec(Vector2(decl, (12.0 - hour) * 15.0)))

func focus(p: Vector2) -> void:
	_target_view = p

func _process(delta: float) -> void:
	if _target_view != null:
		var t: Vector2 = _target_view
		var dl := wrapf(t.y - view.y, -180, 180)
		view.x = lerpf(view.x, t.x, minf(1.0, delta * 5))
		view.y += dl * minf(1.0, delta * 5)
		if absf(t.x - view.x) < 0.2 and absf(dl) < 0.2:
			_target_view = null
		_place_cam()

## Renvoie vrai si l'événement a servi à tourner / zoomer (et n'est donc pas un tap).
func handle_input(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			_dragged = 0.0
		else:
			_touches.erase(e.index)
			_pinch = 0.0
		return false
	if e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var ks := _touches.keys()
			var dd: float = (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]])
			if _pinch > 0:
				dist = clampf(dist * _pinch / dd, 1.6, 5.0)
				_place_cam()
			_pinch = dd
			_dragged += 100
			return true
		_rotate_by(e.relative)
		return _dragged > 8
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and not DisplayServer.is_touchscreen_available():
		_rotate_by(e.relative)
		return _dragged > 8
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_dragged = 0.0
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.9, 1.6, 5.0); _place_cam(); return true
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.1, 1.6, 5.0); _place_cam(); return true
	return false

func was_drag() -> bool:
	return _dragged > 8

func _rotate_by(rel: Vector2) -> void:
	_target_view = null
	_dragged += rel.length()
	var k := 0.18 * (dist - 1.0) / 2.3
	view.y -= rel.x * k
	view.x += rel.y * k
	_place_cam()

## Position à l'écran d'un point du globe, ou null s'il est sur la face cachée.
func project(p: Vector2, lift := 1.01) -> Variant:
	var v := AbyssGeo.to_vec(p) * lift
	if v.normalized().dot((cam.position - v).normalized()) < 0.08:
		return null
	return cam.unproject_position(v)

## Point du globe sous un point de l'écran (null si on vise l'espace).
func pick(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var b := o.dot(d)
	var c := o.dot(o) - 1.0
	var disc := b * b - c
	if disc < 0:
		return null
	return AbyssGeo.from_vec(o + d * (-b - sqrt(disc)))

# ---------- tracés ----------

func begin_lines() -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	_im.surface_add_vertex(Vector3.ZERO) # surface jamais vide
	_im.surface_add_vertex(Vector3.ZERO)

func end_lines() -> void:
	_im.surface_end()

func circle(center: Vector2, km: float, col: Color, seg := 72) -> void:
	var prev := Vector3.ZERO
	for i in seg + 1:
		var p := AbyssGeo.to_vec(AbyssGeo.offset(center, i * 360.0 / seg, km)) * 1.004
		if i > 0:
			_im.surface_set_color(col)
			_im.surface_add_vertex(prev)
			_im.surface_set_color(col)
			_im.surface_add_vertex(p)
		prev = p

func arc(a: Vector2, b: Vector2, col: Color, dashed := false) -> void:
	var d := AbyssGeo.dist_km(a, b)
	var n := clampi(int(d / 120.0), 2, 120)
	var prev := AbyssGeo.to_vec(a) * 1.005
	for i in range(1, n + 1):
		var p := AbyssGeo.to_vec(AbyssGeo.step_toward(a, b, d * i / n)) * 1.005
		if not dashed or i % 2 == 0:
			_im.surface_set_color(col)
			_im.surface_add_vertex(prev)
			_im.surface_set_color(col)
			_im.surface_add_vertex(p)
		prev = p
