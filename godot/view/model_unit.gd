class_name ModelUnit
extends Node3D
## Personnage en vrai modèle 3D (Tripo, versions allégées : tools/lighten_glb.py), voir ModelRegistry.
## Les modèles livrés n'ont pas encore de squelette : les animations (mêmes noms que les autres corps :
## idle, walk, shoot, hit, kneel, death) bougent le modèle entier. Un modèle riggé avec ses propres
## animations pourra remplacer ce fichier sans toucher au reste.

## modèle par soldat (id) ou par espèce : [fichier, hauteur en mètres]
const MODELS := {
	"s1": ["walker", 1.85],
	"s2": ["okafor", 1.88],
	"s3": ["lind", 1.82],
	"s4": ["moreau", 1.8],
	"nereide": ["nereide", 1.95],
	"carapace": ["carapace", 1.7],
	"spectre": ["spectre", 1.9],
	"brute": ["brute", 2.3],
}
## Arme du jeu -> [modèle (weapons/), longueur en m]. Les créatures gardent leurs armes naturelles.
const WEAPON_MODELS := {
	"rifle": ["fusil_assaut", 0.95], "pistol": ["pistolet", 0.32], "harpoon": ["arme_lourde", 1.15],
	"harpoon_ap": ["arme_lourde", 1.15], "cavitation": ["arme_energie", 1.0],
}
## Animations d'un modèle riggé (Tripo auto-rig) : nom du jeu -> mots cherchés dans les noms livrés.
const RIG_ANIMS := {
	"idle": ["idle", "stand", "breath"], "walk": ["walk", "run", "move"], "shoot": ["shoot", "fire", "attack", "aim"],
	"hit": ["hit", "hurt", "damage", "react"], "death": ["death", "die", "dead", "fall"], "kneel": ["kneel", "crouch"],
}
var rig: AnimationPlayer = null # animations livrées avec le modèle (squelette), jouées en plus des mouvements d'ensemble
var hand: Node3D = null # point d'attache de l'arme

var pivot := Node3D.new()
var height := 1.8
var _mats: Array[StandardMaterial3D] = []

static func key(kind: String, id: String) -> String:
	var k := id if kind == "soldier" else kind
	return k if MODELS.has(k) and ModelRegistry.has("units", MODELS[k][0]) else ""

static func build(k: String) -> ModelUnit:
	var n := ModelUnit.new()
	n._setup(MODELS[k][0], MODELS[k][1])
	return n

func _setup(file: String, h: float) -> void:
	height = h
	pivot.name = "Pivot"
	add_child(pivot)
	var m: Node3D = ModelRegistry.instance("units", file, h)
	pivot.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var src := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if src:
			var mat := src.duplicate() as StandardMaterial3D # copie : l'éclair rouge d'impact ne touche qu'une unité
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mat.emission_enabled = true
			mat.emission = Color.BLACK
			(mi as MeshInstance3D).material_override = mat
			_mats.append(mat)
	_find_rig(m)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, h * 0.9, 0.05)
	add_child(head)
	var mz := Node3D.new()
	mz.name = "Muzzle"
	mz.position = Vector3(-0.2, h * 0.55, 0.4)
	add_child(mz)
	_anims()

## Éclair d'impact (piste d'animation) : teinte émissive de toutes les surfaces.
func flash(v: float) -> void:
	for m in _mats:
		m.emission = Color(1.0, 0.25, 0.2) * v

func _anims() -> void:
	var lib := AnimationLibrary.new()
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
	var o := Vector3.ZERO
	var one := Vector3.ONE
	add.call("idle", 2.4, true, [
		["Pivot:scale", [[0.0, one], [1.2, Vector3(1.0, 1.012, 1.0)], [2.4, one]]],
		["Pivot:rotation", [[0.0, o], [1.2, Vector3(0, 0, 0.012)], [2.4, o]]]])
	add.call("walk", 0.5, true, [
		["Pivot:position", [[0.0, o], [0.125, Vector3(0, 0.045, 0)], [0.25, o], [0.375, Vector3(0, 0.045, 0)], [0.5, o]]],
		["Pivot:rotation", [[0.0, Vector3(0.1, 0, 0.05)], [0.25, Vector3(0.1, 0, -0.05)], [0.5, Vector3(0.1, 0, 0.05)]]]])
	add.call("shoot", 0.35, false, [
		["Pivot:position", [[0.0, o], [0.04, Vector3(0, 0, -0.08)], [0.35, o]]],
		["Pivot:rotation", [[0.0, o], [0.04, Vector3(-0.07, 0, 0)], [0.35, o]]]])
	var hit := add.call("hit", 0.45, false, [
		["Pivot:position", [[0.0, o], [0.06, Vector3(0.04, -0.02, -0.12)], [0.45, o]]],
		["Pivot:rotation", [[0.0, o], [0.06, Vector3(-0.18, 0, 0.06)], [0.45, o]]]]) as Animation
	_flash_track(hit, [[0.0, 0.0], [0.05, 1.0], [0.3, 0.0]])
	add.call("kneel", 0.25, false, [
		["Pivot:scale", [[0.0, one], [0.25, Vector3(1.0, 0.8, 1.0)]]],
		["Pivot:rotation", [[0.0, o], [0.25, Vector3(0.12, 0, 0)]]]])
	var death := add.call("death", 0.9, false, [
		["Pivot:rotation", [[0.0, o], [0.1, Vector3(-0.15, 0, 0)], [0.55, Vector3(-PI / 2, 0, 0.1)]]],
		["Pivot:position", [[0.0, o], [0.55, Vector3(0, 0.12, -0.1)]]]]) as Animation
	_flash_track(death, [[0.0, 0.0], [0.06, 1.0], [0.3, 0.0]])
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	add_child(ap)
	ap.add_animation_library("", lib)
	ap.autoplay = "idle"

func _flash_track(an: Animation, keys: Array) -> void:
	var t := an.add_track(Animation.TYPE_METHOD)
	an.track_set_path(t, NodePath("."))
	for k in keys:
		an.track_insert_key(t, k[0], {"method": "flash", "args": [k[1]]})

## Squelette et animations livrés (Tripo auto-rig) : main droite pour l'arme, correspondance des animations.
func _find_rig(m: Node3D) -> void:
	var players := m.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0 and (players[0] as AnimationPlayer).get_animation_list().size() > 0:
		rig = players[0]
	for sk in m.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for b in skel.get_bone_count():
			var n := skel.get_bone_name(b).to_lower()
			if "hand" in n and ("right" in n or n.ends_with("_r") or n.ends_with(".r") or n.begins_with("r_")):
				var att := BoneAttachment3D.new()
				att.bone_name = skel.get_bone_name(b)
				skel.add_child(att)
				hand = att
				return

## Nom de l'animation livrée qui correspond à une animation du jeu, ou "".
func rig_anim(game: String) -> String:
	if rig == null:
		return ""
	for want in RIG_ANIMS.get(game, [game]):
		for a in rig.get_animation_list():
			if want in String(a).to_lower():
				return a
	return ""

func _ready() -> void:
	var ap := get_node_or_null("Anim") as AnimationPlayer
	if ap and rig:
		ap.animation_started.connect(func(n: StringName):
			var r := rig_anim(String(n))
			if r != "":
				rig.play(r, 0.15))
		var r0 := rig_anim("idle")
		if r0 != "":
			rig.play(r0)

## Arme tenue (modèle weapons/<nom>.glb s'il a été livré) : dans la main du squelette, sinon à hauteur de hanche ;
## la sortie du tir (Muzzle) passe au bout du canon.
func equip(weapon: String) -> void:
	if not WEAPON_MODELS.has(weapon):
		return
	var spec: Array = WEAPON_MODELS[weapon]
	var w := ModelKit.weapon(spec[0], spec[1])
	if w == null:
		return
	if hand:
		hand.add_child(w)
	else:
		w.position = Vector3(-0.2, height * 0.55, 0.12)
		pivot.add_child(w)
	var mz := get_node_or_null("Muzzle") as Node3D
	if mz and not hand:
		mz.position = w.position + Vector3(0, 0, spec[1] * 0.55)
