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
	"s1": ["walker", 1.85, 0.0, false, Color(1.55, 1.55, 1.55)],
	"s2": ["okafor", 1.88, 0.0, false, Color(1.55, 1.55, 1.55)],
	"s3": ["marine", 1.85, 0.0, false, Color(1.5, 1.6, 1.7)],
	"s4": ["marine", 1.82, 0.0, false, Color(1.7, 1.6, 1.45)],
	"nereide": ["nereide", 1.95, 0.0, false, Color(1.6, 1.6, 1.65)],
	"spectre": ["spectre", 2.0, 0.25, true, Color(0.95, 0.9, 1.05, 0.92)],
	"carapace": ["carapace", 1.55, 0.0, false, Color(1.5, 1.45, 1.5)], # planche BIO-109 (en attendant une planche Carapace dédiée)
}
## Arme tenue (planche WEAPONS-001) : [sprite, longueur réelle (m)]. Classes : fusil d'assaut, lanceur lourd, précision, arme de poing.
const WEAPONS := {"s1": ["ar9", 0.95], "s2": ["launcher", 1.1], "s3": ["sr9", 1.25], "s4": ["px3", 0.26]}
## Poses facultatives : si `<jeu>_<pose>_<vue>.png` existe (planche de poses détourée), elle remplace la vue neutre
## et contient l'arme. Liste attendue : docs/PLANCHES-MANQUANTES.md.
const POSES := ["aim", "fire", "kneel", "kneel_fire", "walk1", "walk2", "reload", "hit", "cover"]

var tex := {}
var wpn: Sprite3D
var wpn_len := 0.0
var pose := ""
var stance := ""
var height := 1.8
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
		for p in POSES:
			var path := DIR % [s[0], p + "_" + v]
			if ResourceLoader.exists(path):
				tex[p + "_" + v] = load(path)
	var h: float = s[1]
	height = h
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
	if kind == "soldier":
		var wid := ""
		for k in WEAPONS:
			if SETS[k] == s:
				wid = k
		if wid != "":
			var wt: Texture2D = load("res://assets/weapons/%s.png" % WEAPONS[wid][0])
			wpn = Sprite3D.new()
			wpn.name = "Weapon"
			wpn.texture = wt
			wpn_len = WEAPONS[wid][1]
			wpn.pixel_size = wpn_len / float(wt.get_width())
			wpn.shaded = true
			wpn.double_sided = true
			wpn.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			wpn.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			wpn.modulate = s[4]
			wpn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(wpn)
	_anims(s[2] > 0.0)

## Pose ponctuelle (tir, rechargement…) ; "" = revient à la posture (stance) ou à la vue neutre.
func set_pose(p: String) -> void:
	pose = p
	_view = ""

## Posture durable : "aim" en combat (arme levée), "" en exploration.
func set_stance(p: String) -> void:
	stance = p
	_view = ""

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
	var cur := pose if pose != "" else stance
	var tkey := v
	if cur != "" and tex.has(cur + "_" + v):
		tkey = cur + "_" + v
	var key := tkey + str(flip)
	if key != _view:
		_view = key
		spr.texture = tex[tkey]
		spr.flip_h = flip
	_place_weapon(v, flip, a, tkey != v, cam)

## Arme indépendante tenue en main, orientée selon la vue affichée ; la sortie du tir (Muzzle) suit sa bouche.
func _place_weapon(v: String, flip: bool, a: float, posed: bool, cam: Camera3D) -> void:
	if wpn == null:
		return
	wpn.visible = not posed and v != "rear" and not dead
	if not wpn.visible:
		return
	var cb := cam.global_transform.basis
	var R := cb.x
	var U := cb.y
	var B := cb.z
	var sc := pivot.scale.y
	var h := height * sc
	var dir := 1.0
	var ang := 0.0
	var sx := 1.0
	var fwd := 0.0
	var up := 0.55
	match v:
		"side":
			dir = -1.0 if flip else 1.0
			fwd = 0.16
		"q34":
			dir = 1.0 if flip else -1.0
			fwd = 0.1
			sx = 0.82
			ang = -6.0
		_:
			ang = 28.0 if pose != "fire" else 8.0
			sx = 0.72
			up = 0.6
			fwd = -0.02
	if pose == "fire":
		up += 0.03
	var basis := Basis(B, deg_to_rad(ang * dir)) * Basis(R * sx, U, B)
	var flatB := Vector3(B.x, 0, B.z).normalized()
	var center := pivot.global_position + Vector3.UP * h * up + R * dir * h * fwd + flatB * 0.32 # hauteur réelle (pas l'axe incliné de la caméra), devant le corps
	wpn.global_transform = Transform3D(basis, center)
	wpn.flip_h = dir < 0.0
	var m: Node3D = get_node_or_null("Muzzle")
	if m:
		m.global_position = center + (basis.x.normalized() * dir) * wpn_len * sx * 0.5

## Mort : le sprite cesse de suivre la caméra et bascule au sol, face visible vers le haut.
func _fall() -> void:
	dead = true
	if wpn:
		wpn.visible = false
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
	var shoot: Animation = add.call("shoot", 0.35, false, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.04, Vector3(0, y0, -0.09)], [0.35, Vector3(0, y0, 0)]]],
		["Pivot:scale", [[0.0, one], [0.04, Vector3(0.97, 1.02, 1)], [0.35, one]]]])
	for an in [[shoot, "fire", 0.33]]:
		var mt0 := (an[0] as Animation).add_track(Animation.TYPE_METHOD)
		(an[0] as Animation).track_set_path(mt0, NodePath("."))
		(an[0] as Animation).track_insert_key(mt0, 0.0, {"method": "set_pose", "args": [an[1]]})
		(an[0] as Animation).track_insert_key(mt0, an[2], {"method": "set_pose", "args": [""]})
	add.call("hit", 0.45, false, [
		["Pivot:position", [[0.0, Vector3(0, y0, 0)], [0.06, Vector3(0.05, y0 - 0.02, -0.12)], [0.45, Vector3(0, y0, 0)]]],
		["Spr:modulate", [[0.0, spr.modulate], [0.05, Color(1.8, 0.55, 0.5)], [0.3, spr.modulate]]]])
	add.call("kneel", 0.25, false, [
		["Pivot:scale", [[0.0, one], [0.25, Vector3(0.86, 0.86, 0.86)]]],
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
