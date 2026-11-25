class_name SpriteUnit
extends Node3D
## Personnage en sprites tirés des planches de Max (face, profil, dos, trois-quarts), dans la scène 3D.
## Le sprite reste vertical face à la caméra ; la vue affichée dépend de l'angle entre l'orientation de
## l'unité et la caméra (8 secteurs), avec miroir pour l'autre côté. Ombres portées, éclairage de la scène.
## Animations (AnimationPlayer « Anim », mêmes noms que les modèles 3D) : respiration, marche, tir, impact,
## génuflexion, mort (le corps bascule et reste au sol).

const DIR := "res://assets/units/sprites/%s_%s.png"
## jeu de sprites, hauteur en mètres, lévitation, translucide, teinte
const SETS := {
	"s1": ["walker", 1.85, 0.0, false, Color(1.3, 1.3, 1.3)],
	"s2": ["okafor", 1.88, 0.0, false, Color(1.3, 1.3, 1.3)],
	"s3": ["marine", 1.85, 0.0, false, Color(1.3, 1.38, 1.45)],
	"s4": ["marine", 1.82, 0.0, false, Color(1.45, 1.38, 1.25)],
	"nereide": ["nereide", 1.95, 0.0, false, Color(1.35, 1.35, 1.4)],
	"spectre": ["spectre", 2.0, 0.25, true, Color(0.95, 0.9, 1.05, 0.92)],
}

var tex := {}
var spr := Sprite3D.new()
var pivot := Node3D.new()
var dead := false
var _view := ""

static func has_set(kind: String, id: String) -> bool:
	return SETS.has(id) if kind == "soldier" else SETS.has(kind)

static func build(kind: String, id: String) -> SpriteUnit:
	var n := SpriteUnit.new()
	n._setup(SETS[id] if kind == "soldier" else SETS[kind], kind)
	return n

func _setup(s: Array, kind: String) -> void:
	for v in ["front", "side", "rear", "q34"]:
		tex[v] = load(DIR % [s[0], v])
	var h: float = s[1]
	pivot.name = "Pivot"
	pivot.position.y = s[2]
	add_child(pivot)
	spr.name = "Spr"
	spr.texture = tex["front"]
	spr.pixel_size = h / float((tex["front"] as Texture2D).get_height())
	spr.centered = true
	spr.offset = Vector2(0, (tex["front"] as Texture2D).get_height() / 2.0)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.shaded = true
	spr.double_sided = true
	spr.modulate = s[4]
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if s[3]: # créature translucide et lumineuse (Spectre) : elle émet sa propre lumière
		spr.shaded = false
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(spr)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, h * 0.84 + s[2], 0.05)
	add_child(head)
	var m := Node3D.new()
	m.name = "Muzzle"
	m.position = Vector3(-0.2, h * 0.62 + s[2], 0.45) if kind == "soldier" else Vector3(0, h * 0.7 + s[2], 0.35)
	add_child(m)
	_anims(s[2] > 0.0)

func _process(_delta: float) -> void:
	if dead:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := global_transform.basis.z
	var cb := cam.global_transform.basis
	var a := rad_to_deg(atan2(f.dot(cb.x), f.dot(cb.z))) # 0 : face caméra ; +90 : regarde vers la droite de l'écran
	var v := "front"
	var flip := false
	var aa := absf(a)
	if aa < 22.5:
		v = "front"
	elif aa < 67.5:
		v = "q34"
		flip = a > 0.0 # la vue 3/4 des planches regarde vers la gauche de l'écran
	elif aa < 135.0:
		v = "side"
		flip = a < 0.0 # le profil des planches regarde vers la droite de l'écran
	else:
		v = "rear"
	var key := v + str(flip)
	if key != _view:
		_view = key
		spr.texture = tex[v]
		spr.flip_h = flip

## Mort : le sprite cesse de suivre la caméra et bascule au sol, face visible vers le haut.
func _fall() -> void:
	dead = true
	var cam := get_viewport().get_camera_3d()
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	if cam:
		var to_cam := cam.global_position - global_position
		pivot.global_rotation = Vector3(0, atan2(to_cam.x, to_cam.z), 0)
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:x", -PI / 2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pivot, "position:y", 0.04, 0.45)
	tw.tween_property(spr, "modulate", spr.modulate.darkened(0.35), 0.4)

func _anims(hover: bool) -> void:
	var lib := AnimationLibrary.new()
	var y0 := pivot.position.y
	var add := func(name: String, length: float, loop: bool, tracks: Array) -> Animation:
		var an := Animation.new()
		an.length = length
		an.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		for tr in tracks:
			var t := an.add_track(Animation.TYPE_VALUE)
			an.track_set_path(t, NodePath(tr[0]))
			an.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
			for k in tr[1]:
				an.track_insert_key(t, k[0], k[1])
		lib.add_animation(name, an)
		return an
	var one := Vector3.ONE
	var b := 0.06 if hover else 0.012
	add.call("idle", 2.4 if not hover else 2.0, true, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [1.2 if not hover else 1.0, Vector3(0, y0 + b, 0)], [2.4 if not hover else 2.0, Vector3(0, y0, 0)]]],
		["Pivot:scale", [[0.0, one], [1.2 if not hover else 1.0, Vector3(1.0, 1.012, 1.0)], [2.4 if not hover else 2.0, one]]]])
	add.call("walk", 0.5, true, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.125, Vector3(0.02, y0 + 0.05, 0)], [0.25, Vector3(0, y0, 0)], [0.375, Vector3(-0.02, y0 + 0.05, 0)], [0.5, Vector3(0, y0, 0)]]],
		["Pivot:scale", [[0.0, Vector3(1.02, 0.98, 1)], [0.125, one], [0.25, Vector3(1.02, 0.98, 1)], [0.375, one], [0.5, Vector3(1.02, 0.98, 1)]]]])
	add.call("shoot", 0.35, false, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.04, Vector3(0, y0, -0.09)], [0.35, Vector3(0, y0, 0)]]],
		["Pivot:scale", [[0.0, one], [0.04, Vector3(0.97, 1.02, 1)], [0.35, one]]]])
	add.call("hit", 0.45, false, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.06, Vector3(0.05, y0 - 0.02, -0.12)], [0.45, Vector3(0, y0, 0)]]],
		["Spr:modulate", [[0.0, spr.modulate], [0.05, Color(1.8, 0.55, 0.5)], [0.3, spr.modulate]]]])
	add.call("kneel", 0.25, false, [
		["Pivot:scale", [[0.0, one], [0.25, Vector3(1.04, 0.8, 1)]]],
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.25, Vector3(0, y0, 0)]]]])
	var death := add.call("death", 0.9, false, [["Spr:modulate", [[0.0, spr.modulate], [0.06, Color(1.8, 0.5, 0.45)], [0.25, spr.modulate]]]]) as Animation
	var mt := death.add_track(Animation.TYPE_METHOD)
	death.track_set_path(mt, NodePath("."))
	death.track_insert_key(mt, 0.08, {"method": "_fall", "args": []})
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	add_child(ap)
	ap.add_animation_library("", lib)
	ap.autoplay = "idle"
