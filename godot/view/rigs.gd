class_name AbyssRig
extends RefCounted
## Modèles articulés des unités (V3.1) : hiérarchie d'articulations (Hips, Torso, Head, bras, jambes…),
## pièces chanfreinées et matériaux PBR du kit, et un AnimationPlayer « Anim » avec
## idle, walk, shoot, hit, death (+ kneel pour les soldats). Respecte la convention de unit_visuals.gd :
## origine aux pieds, regard +Z, 1 u = 1 m, nœud « Muzzle » attaché à l'arme (il suit les animations).

var root: Node3D
var joints := {}
var paths := {}
var base := {}
var lib := AnimationLibrary.new()

func _init(r: Node3D) -> void:
	root = r

func joint(name: String, parent: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	j.rotation_degrees = rot
	(root if parent == "" else joints[parent] as Node3D).add_child(j)
	joints[name] = j
	paths[name] = name if parent == "" else "%s/%s" % [paths[parent], name]
	base[name] = j.rotation
	return j

func part(j: String, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.material_override = m
	(joints[j] as Node3D).add_child(mi)
	return mi

func box(j: String, s: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return part(j, AbyssKit.bevel_box(s, minf(0.03, minf(s.x, minf(s.y, s.z)) * 0.3)), pos, m, rot)

func muzzle(j: String, pos: Vector3) -> void:
	var m := Node3D.new()
	m.name = "Muzzle"
	m.position = pos
	(joints[j] as Node3D).add_child(m)

## IK à deux os : place l'épaule et le coude pour que la main atteigne `target` (repère du parent de l'épaule).
## `pole` indique de quel côté plie le coude. Sert de pose de base (ex. mains sur le fusil).
func reach(arm: String, elbow: String, upper: float, fore: float, target: Vector3, pole: Vector3) -> void:
	var S: Vector3 = (joints[arm] as Node3D).position
	var to := target - S
	var d := clampf(to.length(), 0.05, upper + fore - 0.001)
	var dir := to.normalized()
	var n := dir.cross(pole).normalized()
	var alpha := acos(clampf((upper * upper + d * d - fore * fore) / (2.0 * upper * d), -1.0, 1.0))
	var u := dir.rotated(n, -alpha)
	if u.dot(pole) < dir.dot(pole):
		u = dir.rotated(n, alpha)
	var E := S + u * upper
	var y := -u
	var x := y.cross(pole).normalized()
	var B := Basis(x, y, x.cross(y)).orthonormalized()
	(joints[arm] as Node3D).basis = B
	var lf := B.inverse() * (target - E).normalized()
	(joints[elbow] as Node3D).rotation = Vector3(atan2(-lf.z, -lf.y), 0, 0)
	base[arm] = (joints[arm] as Node3D).rotation
	base[elbow] = (joints[elbow] as Node3D).rotation

## Clés en décalage par rapport à la pose de base : "Joint" = rotation (degrés), "@Joint" = position, "%Joint" = échelle.
func anim(name: String, length: float, loop: bool, keys: Dictionary) -> void:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for k: String in keys:
		var kind := k[0] if k[0] in ["@", "%"] else ""
		var jn := k.substr(1) if kind != "" else k
		var j: Node3D = joints[jn]
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath("%s:%s" % [paths[jn], {"@": "position", "%": "scale", "": "rotation"}[kind]]))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		for kv in keys[k]:
			var v: Vector3 = kv[1]
			var val: Vector3 = j.position + v if kind == "@" else (Vector3.ONE + v if kind == "%" else base[jn] + v * PI / 180.0)
			a.track_insert_key(t, kv[0], val)
	lib.add_animation(name, a)

## Ajoute l'AnimationPlayer ; chaque animation reçoit une piste constante pour toute propriété animée ailleurs,
## pour que les fondus d'une animation à l'autre reviennent toujours à la pose de base.
func finish() -> void:
	var used := {}
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		for t in a.get_track_count():
			used[a.track_get_path(t)] = a.track_get_key_value(t, 0)
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		var have := {}
		for t in a.get_track_count():
			have[a.track_get_path(t)] = true
		for p: NodePath in used:
			if not have.has(p):
				var t := a.add_track(Animation.TYPE_VALUE)
				a.track_set_path(t, p)
				var prop := String(p.get_concatenated_subnames())
				var jn := String(p.get_name(p.get_name_count() - 1))
				var j: Node3D = joints[jn]
				a.track_insert_key(t, 0.0, j.position if prop == "position" else (j.scale if prop == "scale" else j.rotation))
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.add_animation_library("", lib)
	ap.autoplay = "idle"

static func build(kind: String, variant := "") -> Node3D:
	var n := Node3D.new()
	var r := AbyssRig.new(n)
	match kind:
		"soldier": r._soldier(variant)
		"nereide": r._nereide()
		"carapace": r._carapace()
		"spectre": r._spectre()
	r.finish()
	return n

static func _caps(rad: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = rad; c.height = maxf(h, rad * 2.0); c.radial_segments = 12; c.rings = 3
	return c

static func _sph(rad: float, h: float, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rad; s.height = h; s.radial_segments = 16; s.rings = 8; s.is_hemisphere = hemi
	return s

# ---------- squelette humanoïde commun (plongeur, Néréide) ----------

func _humanoid(hip_h: float, thigh: float, shin: float, upper: float, fore: float, skin: Material, limb_r: float) -> void:
	joint("Hips", "", Vector3(0, hip_h, 0))
	joint("Torso", "Hips", Vector3(0, 0.08, 0))
	for s in [1, -1]:
		var L := "L" if s == 1 else "R"
		joint("Leg" + L, "Hips", Vector3(0.11 * s, -0.06, 0))
		part("Leg" + L, _caps(limb_r * 1.15, thigh + 0.04), Vector3(0, -thigh / 2, 0), skin)
		joint("Knee" + L, "Leg" + L, Vector3(0, -thigh, 0))
		part("Knee" + L, _caps(limb_r, shin + 0.02), Vector3(0, -shin / 2, 0), skin)
		joint("Foot" + L, "Knee" + L, Vector3(0, -shin, 0))
		joint("Arm" + L, "Torso", Vector3(0.25 * s, 0.5, 0))
		part("Arm" + L, _caps(limb_r * 0.85, upper), Vector3(0, -upper / 2, 0), skin)
		joint("Elbow" + L, "Arm" + L, Vector3(0, -upper, 0))
		part("Elbow" + L, _caps(limb_r * 0.75, fore), Vector3(0, -fore / 2, 0), skin)
	joint("Head", "Torso", Vector3(0, 0.6, 0))

func _human_anims(lean := 0.0) -> void:
	anim("idle", 2.4, true, {"Torso": [[0, Vector3.ZERO], [1.2, Vector3(2.5, 0, 0)], [2.4, Vector3.ZERO]],
		"Head": [[0, Vector3.ZERO], [0.8, Vector3(0, 10, 0)], [1.6, Vector3(0, -6, 0)], [2.4, Vector3.ZERO]],
		"@Hips": [[0, Vector3.ZERO], [1.2, Vector3(0, -0.012, 0)], [2.4, Vector3.ZERO]]})
	var sw := 26.0
	anim("walk", 0.64, true, {
		"LegL": [[0, Vector3(-sw, 0, 0)], [0.32, Vector3(sw, 0, 0)], [0.64, Vector3(-sw, 0, 0)]],
		"LegR": [[0, Vector3(sw, 0, 0)], [0.32, Vector3(-sw, 0, 0)], [0.64, Vector3(sw, 0, 0)]],
		"KneeL": [[0, Vector3(6, 0, 0)], [0.16, Vector3(12, 0, 0)], [0.32, Vector3(18, 0, 0)], [0.48, Vector3(55, 0, 0)], [0.64, Vector3(6, 0, 0)]],
		"KneeR": [[0, Vector3(18, 0, 0)], [0.16, Vector3(55, 0, 0)], [0.32, Vector3(6, 0, 0)], [0.48, Vector3(12, 0, 0)], [0.64, Vector3(18, 0, 0)]],
		"@Hips": [[0, Vector3.ZERO], [0.16, Vector3(0, 0.035, 0)], [0.32, Vector3.ZERO], [0.48, Vector3(0, 0.035, 0)], [0.64, Vector3.ZERO]],
		"Torso": [[0, Vector3(6 + lean, 4, 0)], [0.32, Vector3(6 + lean, -4, 0)], [0.64, Vector3(6 + lean, 4, 0)]]})
	anim("shoot", 0.4, false, {"Torso": [[0, Vector3.ZERO], [0.05, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]],
		"Head": [[0, Vector3.ZERO], [0.05, Vector3(-4, 0, 0)], [0.4, Vector3.ZERO]],
		"@Hips": [[0, Vector3.ZERO], [0.05, Vector3(0, 0, -0.04)], [0.4, Vector3.ZERO]]})
	anim("hit", 0.5, false, {"Torso": [[0, Vector3.ZERO], [0.08, Vector3(-22, 0, 10)], [0.5, Vector3.ZERO]],
		"Head": [[0, Vector3.ZERO], [0.08, Vector3(-18, 0, 0)], [0.5, Vector3.ZERO]],
		"@Hips": [[0, Vector3.ZERO], [0.08, Vector3(0, -0.03, -0.1)], [0.5, Vector3.ZERO]]})
	var h: float = (joints["Hips"] as Node3D).position.y
	anim("death", 1.1, false, {"@Hips": [[0, Vector3.ZERO], [0.35, Vector3(0, -0.25, -0.15)], [0.8, Vector3(0, 0.16 - h, -0.4)], [1.1, Vector3(0, 0.16 - h, -0.4)]],
		"Hips": [[0, Vector3.ZERO], [0.35, Vector3(-20, 0, 0)], [0.8, Vector3(-88, 0, 8)], [1.1, Vector3(-88, 0, 8)]],
		"KneeL": [[0, Vector3.ZERO], [0.5, Vector3(60, 0, 0)], [1.1, Vector3(25, 0, 0)]],
		"KneeR": [[0, Vector3.ZERO], [0.6, Vector3(40, 0, 0)], [1.1, Vector3(10, 0, 0)]],
		"Head": [[0, Vector3.ZERO], [0.9, Vector3(-25, 30, 0)], [1.1, Vector3(-25, 30, 0)]]})

# ---------- plongeur de combat ----------

## Planches CHAR-HUM-001 Walker et HUM-002 Okafor : combinaison marine, plaques acier canon de fusil,
## ceinturon à poches cuir, accents cyan ; Okafor (lourd, harpon) a des épaulières et un sac ambre.
func _soldier(variant: String) -> void:
	var suit := AbyssKit.tinted("suit", "fabric", Color(0.5, 0.6, 0.85), 0.05)
	var armor := AbyssKit.mat("armor")
	var heavy := variant == "s2"
	var accent := AbyssKit.tinted("armor_amber", "plate", Color(0.85, 0.62, 0.22), 0.6) if heavy else armor
	var leather := AbyssKit.tinted("leather", "fabric", Color(1.25, 0.85, 0.55), 0.0)
	var dark := AbyssKit.mat("dark")
	var steel := AbyssKit.mat("steel")
	var rubber := AbyssKit.mat("rubber")
	_humanoid(0.95, 0.44, 0.43, 0.3, 0.29, suit, 0.075)
	box("Hips", Vector3(0.36, 0.18, 0.24), Vector3(0, 0, 0), armor)
	box("Hips", Vector3(0.39, 0.06, 0.27), Vector3(0, 0.08, 0), AbyssKit.mat("rubber"))
	box("Hips", Vector3(0.08, 0.03, 0.01), Vector3(0.1, 0.08, 0.14), AbyssKit.mat("led_amber"))
	for s in [1, -1]:
		var L := "L" if s == 1 else "R"
		box("Leg" + L, Vector3(0.15, 0.24, 0.07), Vector3(0, -0.2, 0.07), armor)
		box("Knee" + L, Vector3(0.14, 0.12, 0.09), Vector3(0, 0, 0.07), armor)
		box("Knee" + L, Vector3(0.12, 0.26, 0.06), Vector3(0, -0.21, 0.06), armor)
		box("Foot" + L, Vector3(0.14, 0.11, 0.28), Vector3(0, -0.035, 0.05), rubber)
		box("Arm" + L, Vector3(0.2 if heavy else 0.18, 0.14, 0.23), Vector3(0.03 * s, 0.01, 0), accent, Vector3(0, 0, -15 * s))
		box("Elbow" + L, Vector3(0.025, 0.1, 0.03), Vector3(0.055 * s, -0.14, 0.03), AbyssKit.mat("led_cyan"))
		box("Elbow" + L, Vector3(0.11, 0.17, 0.11), Vector3(0, -0.14, 0), armor)
		part("Elbow" + L, _sph(0.055, 0.1), Vector3(0, -0.3, 0), dark)
	# torse : combinaison, plastron, sangles, sac dorsal à deux bouteilles, collerette
	box("Torso", Vector3(0.4, 0.46, 0.26), Vector3(0, 0.3, 0), suit)
	box("Torso", Vector3(0.43, 0.33, 0.09), Vector3(0, 0.35, 0.13), armor)
	box("Torso", Vector3(0.3, 0.1, 0.07), Vector3(0, 0.12, 0.12), armor)
	for s in [1, -1]:
		box("Torso", Vector3(0.07, 0.12, 0.05), Vector3(0.12 * s, 0.22, 0.18), dark) # poches
		box("Hips", Vector3(0.08, 0.1, 0.07), Vector3(0.15 * s, 0.03, 0.13), leather) # poches du ceinturon
		part("Torso", AbyssKit.cyl(0.075, 0.075, 0.52, 14), Vector3(0.095 * s, 0.33, -0.27), steel)
		part("Torso", _sph(0.075, 0.07, true), Vector3(0.095 * s, 0.59, -0.27), steel)
	box("Torso", Vector3(0.34, 0.44, 0.1), Vector3(0, 0.32, -0.17), accent if heavy else dark)
	box("Torso", Vector3(0.12, 0.03, 0.01), Vector3(0, 0.36, -0.225), AbyssKit.mat("led_cyan"))
	box("Torso", Vector3(0.05, 0.04, 0.02), Vector3(0.1, 0.48, 0.18), AbyssKit.mat("led_cyan"))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.1; collar.outer_radius = 0.17; collar.rings = 16; collar.ring_segments = 8
	part("Torso", collar, Vector3(0, 0.56, 0), steel)
	# casque de scaphandre : coque, visière cyan, phare, tuyau
	part("Head", _sph(0.165, 0.32), Vector3(0, 0.12, 0), armor)
	part("Head", _sph(0.1, 0.18), Vector3(0, 0.1, 0.06), AbyssKit.tinted("face", "flesh", Color(0.55, 0.38, 0.3) if heavy else Color(0.85, 0.66, 0.55), 0.0))
	part("Head", _sph(0.14, 0.22), Vector3(0, 0.12, 0.07), AbyssKit.mat("glass"), Vector3.ZERO, Vector3(1.05, 0.75, 0.95))
	box("Head", Vector3(0.26, 0.02, 0.05), Vector3(0, 0.205, 0.1), AbyssKit.mat("led_cyan"))
	box("Head", Vector3(0.05, 0.05, 0.06), Vector3(0.15, 0.17, 0.05), steel)
	box("Head", Vector3(0.035, 0.035, 0.01), Vector3(0.15, 0.17, 0.085), AbyssKit.mat("led_cyan"))
	box("Head", Vector3(0.04, 0.06, 0.2), Vector3(0, 0.29, -0.02), steel)
	# fusil tenu à deux mains (sur le torse : il suit le recul)
	joint("Gun", "Torso", Vector3(-0.12, 0.36, 0.24))
	box("Gun", Vector3(0.07, 0.11, 0.44), Vector3.ZERO, dark)
	part("Gun", AbyssKit.cyl(0.02, 0.02, 0.3, 8), Vector3(0, 0.02, 0.35), steel, Vector3(90, 0, 0))
	box("Gun", Vector3(0.05, 0.1, 0.18), Vector3(0, -0.02, -0.29), rubber)
	box("Gun", Vector3(0.05, 0.15, 0.07), Vector3(0, -0.11, 0.06), dark, Vector3(15, 0, 0))
	part("Gun", AbyssKit.cyl(0.025, 0.025, 0.14, 8), Vector3(0, 0.09, 0.02), steel, Vector3(90, 0, 0))
	box("Gun", Vector3(0.01, 0.025, 0.1), Vector3(0.04, 0.01, 0.1), AbyssKit.mat("led_cyan"))
	muzzle("Gun", Vector3(0, 0.02, 0.52))
	# fusil épaulé : main droite sur la poignée, main gauche sur le garde-main (IK)
	var g: Vector3 = (joints["Gun"] as Node3D).position
	reach("ArmR", "ElbowR", 0.3, 0.29, g + Vector3(0, -0.08, -0.06), Vector3(-0.6, -1, -0.2))
	reach("ArmL", "ElbowL", 0.3, 0.29, g + Vector3(0.01, -0.05, 0.2), Vector3(0.7, -1, 0))
	_human_anims()
	anim("kneel", 0.3, false, {"@Hips": [[0, Vector3.ZERO], [0.3, Vector3(0, -0.45, 0)]],
		"LegL": [[0, Vector3.ZERO], [0.3, Vector3(-82, 0, 0)]], "KneeL": [[0, Vector3.ZERO], [0.3, Vector3(82, 0, 0)]],
		"LegR": [[0, Vector3.ZERO], [0.3, Vector3(8, 0, 0)]], "KneeR": [[0, Vector3.ZERO], [0.3, Vector3(84, 0, 0)]],
		"Torso": [[0, Vector3.ZERO], [0.3, Vector3(6, 0, 0)]]})

# ---------- Néréide : amphibie élancée, voûtée, griffes, nageoires ----------

func _nereide() -> void:
	## Planche ALIEN-001 Nereid Scout : peau bleu nuit luisante, crête, lignes bioluminescentes cyan.
	var skin := AbyssKit.tinted("ner_skin", "flesh", Color(0.2, 0.3, 0.42), 0.35, Color.BLACK, 0.45)
	var belly := AbyssKit.tinted("ner_belly", "flesh", Color(0.28, 0.4, 0.52), 0.3)
	var fin := AbyssKit.tinted("ner_fin", "flesh", Color(0.18, 0.32, 0.45), 0.2, Color("0a3a4a"), 0.8)
	var eye := AbyssKit.mat("led_cyan")
	_humanoid(0.92, 0.42, 0.46, 0.36, 0.4, skin, 0.06)
	(joints["Torso"] as Node3D).rotation_degrees.x = 24
	base["Torso"] = (joints["Torso"] as Node3D).rotation
	part("Hips", _caps(0.13, 0.3), Vector3.ZERO, skin, Vector3(0, 0, 90))
	part("Torso", _caps(0.14, 0.62), Vector3(0, 0.3, 0), skin, Vector3.ZERO, Vector3(1.15, 1, 0.9))
	part("Torso", _caps(0.12, 0.42), Vector3(0, 0.26, 0.07), belly)
	for i in 5: # ligne bioluminescente de la colonne
		part("Torso", AbyssKit.bevel_box(Vector3(0.03, 0.06, 0.02), 0.008), Vector3(0, 0.12 + i * 0.1, -0.135), eye)
	for i in 4: # côtes
		part("Torso", AbyssKit.bevel_box(Vector3(0.3, 0.025, 0.06), 0.01), Vector3(0, 0.18 + i * 0.08, 0.15), belly)
	var dorsal := PrismMesh.new()
	dorsal.size = Vector3(0.5, 0.3, 0.025)
	part("Torso", dorsal, Vector3(0, 0.5, -0.15), fin, Vector3(0, 90, 15))
	part("Head", _caps(0.09, 0.36), Vector3(0, 0.1, 0.07), skin, Vector3(55, 0, 0))
	part("Head", _caps(0.06, 0.2), Vector3(0, 0.02, 0.14), belly, Vector3(80, 0, 0)) # mâchoire
	for s in [1, -1]:
		part("Head", AbyssKit.bevel_box(Vector3(0.07, 0.022, 0.03), 0.008), Vector3(0.055 * s, 0.13, 0.22), eye, Vector3(0, 20 * s, -15 * s))
		var gill := PrismMesh.new()
		gill.size = Vector3(0.2, 0.14, 0.02)
		part("Head", gill, Vector3(0.09 * s, 0.1, -0.02), fin, Vector3(0, 90, 30 * s))
		var L := "L" if s == 1 else "R"
		for c in 3: # griffes
			part("Elbow" + L, AbyssKit.cyl(0.0, 0.016, 0.16, 6), Vector3((c - 1) * 0.025, -fore_len() - 0.06, 0.02), AbyssKit.mat("dark"), Vector3(12, 0, (c - 1) * 12))
		part("Foot" + L, AbyssKit.bevel_box(Vector3(0.1, 0.05, 0.22), 0.015), Vector3(0, -0.02, 0.06), skin)
		(joints["Arm" + L] as Node3D).rotation_degrees = Vector3(-30, 0, 12 * s)
		base["Arm" + L] = (joints["Arm" + L] as Node3D).rotation
		(joints["Elbow" + L] as Node3D).rotation_degrees = Vector3(-35, 0, 0)
		base["Elbow" + L] = (joints["Elbow" + L] as Node3D).rotation
	var tail := PrismMesh.new()
	tail.size = Vector3(0.36, 0.42, 0.025)
	part("Hips", tail, Vector3(0, -0.15, -0.2), fin, Vector3(-35, 90, 0))
	muzzle("Head", Vector3(0, 0.1, 0.32))
	_human_anims(8.0)

func fore_len() -> float:
	return 0.4

# ---------- Carapace : crustacé lourd à six pattes et deux pinces ----------

func _carapace() -> void:
	var shell := AbyssKit.tinted("cara_shell", "flesh", Color(0.3, 0.22, 0.2), 0.55, Color.BLACK, 0.35)
	var plate := AbyssKit.tinted("cara_plate", "flesh", Color(0.42, 0.3, 0.26), 0.6)
	var leg := AbyssKit.tinted("cara_leg", "flesh", Color(0.18, 0.13, 0.12), 0.4)
	joint("Body", "", Vector3(0, 0.62, 0))
	part("Body", _sph(0.55, 0.6), Vector3.ZERO, shell, Vector3.ZERO, Vector3(1.0, 1.0, 1.2))
	part("Body", _sph(0.45, 0.3), Vector3(0, -0.14, 0.05), leg, Vector3.ZERO, Vector3(1, 1, 1.2))
	for i in 4: # plaques dorsales segmentées
		part("Body", AbyssKit.bevel_box(Vector3(0.75 - i * 0.12, 0.08, 0.2), 0.03), Vector3(0, 0.27 - i * 0.02, 0.28 - i * 0.2), plate, Vector3(8 - i * 10, 0, 0))
	for i in 3: # épines
		part("Body", AbyssKit.cyl(0.0, 0.05, 0.2, 6), Vector3(0, 0.34, 0.12 - i * 0.22), AbyssKit.mat("dark"), Vector3(-20, 0, 0))
	joint("Head", "Body", Vector3(0, -0.02, 0.58))
	box("Head", Vector3(0.36, 0.2, 0.2), Vector3.ZERO, plate)
	box("Head", Vector3(0.28, 0.035, 0.02), Vector3(0, 0.04, 0.105), AbyssKit.mat("led_amber"))
	for s in [1, -1]:
		part("Head", AbyssKit.cyl(0.0, 0.025, 0.18, 6), Vector3(0.07 * s, -0.1, 0.12), leg, Vector3(60, 0, 0))
	muzzle("Head", Vector3(0, -0.02, 0.2))
	var legs := []
	for s in [1, -1]:
		var L := "L" if s == 1 else "R"
		for k in 3:
			var name := "Leg%s%d" % [L, k]
			joint(name, "Body", Vector3(0.4 * s, -0.08, 0.3 - k * 0.3), Vector3(0, (k - 1) * -30 * s, 22 * s))
			part(name, AbyssKit.cyl(0.05, 0.04, 0.42, 8), Vector3(0.21 * s, 0, 0), leg, Vector3(0, 0, 90))
			joint(name + "k", name, Vector3(0.42 * s, 0, 0), Vector3(0, 0, -78 * s))
			part(name + "k", AbyssKit.cyl(0.04, 0.012, 0.58, 8), Vector3(0.29 * s, 0, 0), leg, Vector3(0, 0, 90))
			legs.append([name, s, k])
		var C := "Claw" + L
		joint(C, "Body", Vector3(0.32 * s, -0.12, 0.5), Vector3(-10, -20 * s, 0))
		part(C, AbyssKit.cyl(0.06, 0.07, 0.4, 8), Vector3(0, 0, 0.2), leg, Vector3(90, 0, 0))
		joint(C + "p", C, Vector3(0, 0, 0.42))
		part(C + "p", _sph(0.12, 0.2), Vector3(0, 0, 0.1), plate, Vector3.ZERO, Vector3(0.8, 0.7, 1.4))
		joint(C + "j", C + "p", Vector3(0, -0.05, 0.08))
		part(C + "j", AbyssKit.bevel_box(Vector3(0.06, 0.05, 0.24), 0.015), Vector3(0, 0, 0.12), plate)
	var idle := {"@Body": [[0, Vector3.ZERO], [1.0, Vector3(0, -0.025, 0)], [2.0, Vector3.ZERO]],
		"ClawLj": [[0, Vector3.ZERO], [0.6, Vector3(25, 0, 0)], [0.9, Vector3.ZERO], [2.0, Vector3.ZERO]],
		"ClawRj": [[0, Vector3.ZERO], [1.2, Vector3.ZERO], [1.5, Vector3(25, 0, 0)], [2.0, Vector3.ZERO]],
		"Head": [[0, Vector3.ZERO], [1.0, Vector3(0, 8, 0)], [2.0, Vector3.ZERO]]}
	anim("idle", 2.0, true, idle)
	var walk := {"@Body": [[0, Vector3.ZERO], [0.125, Vector3(0, 0.03, 0)], [0.25, Vector3.ZERO], [0.375, Vector3(0, 0.03, 0)], [0.5, Vector3.ZERO]]}
	for l in legs: # trépied alterné
		var ph: bool = (l[2] + (0 if l[1] == 1 else 1)) % 2 == 0
		var a := 18.0 if ph else -18.0
		var up := Vector3(0, 0, 14 * l[1])
		walk[l[0]] = [[0, Vector3(0, a, 0)], [0.125, Vector3(0, 0, 0) + (up if ph else Vector3.ZERO)], [0.25, Vector3(0, -a, 0)], [0.375, Vector3.ZERO + (Vector3.ZERO if ph else up)], [0.5, Vector3(0, a, 0)]]
	anim("walk", 0.5, true, walk)
	anim("shoot", 0.6, false, {"Head": [[0, Vector3.ZERO], [0.15, Vector3(-25, 0, 0)], [0.25, Vector3(10, 0, 0)], [0.6, Vector3.ZERO]],
		"@Body": [[0, Vector3.ZERO], [0.15, Vector3(0, 0.05, -0.08)], [0.25, Vector3(0, 0, 0.06)], [0.6, Vector3.ZERO]]})
	anim("hit", 0.45, false, {"Body": [[0, Vector3.ZERO], [0.08, Vector3(-10, 0, 8)], [0.45, Vector3.ZERO]],
		"ClawLp": [[0, Vector3.ZERO], [0.08, Vector3(-30, 0, 0)], [0.45, Vector3.ZERO]], "ClawRp": [[0, Vector3.ZERO], [0.08, Vector3(-30, 0, 0)], [0.45, Vector3.ZERO]]})
	var death := {"@Body": [[0, Vector3.ZERO], [0.6, Vector3(0, -0.4, 0)], [1.0, Vector3(0, -0.4, 0)]],
		"Body": [[0, Vector3.ZERO], [0.6, Vector3(6, 0, 18)], [1.0, Vector3(6, 0, 18)]]}
	for l in legs:
		death[l[0] + "k"] = [[0, Vector3.ZERO], [0.6, Vector3(0, 0, 40 * l[1])], [1.0, Vector3(0, 0, 40 * l[1])]]
	anim("death", 1.0, false, death)

# ---------- Spectre : méduse psionique bioluminescente ----------

func _spectre() -> void:
	## Planches ALIEN-002 / CHAR-003 : cloche gris fumé translucide, cœur violet, longs tentacules sombres.
	var bell := AbyssKit.tinted("spec_bell", "flesh", Color(0.55, 0.55, 0.62, 0.55), 0.3, Color("1a1030"), 0.9)
	(bell as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tent := AbyssKit.tinted("spec_tent", "flesh", Color(0.38, 0.38, 0.45, 0.8), 0.2, Color("20123a"), 0.6)
	(tent as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	joint("Bell", "", Vector3(0, 1.35, 0))
	part("Bell", _sph(0.4, 0.62, true), Vector3.ZERO, bell, Vector3.ZERO, Vector3(1, 1.25, 1))
	part("Bell", _sph(0.17, 0.3), Vector3(0, 0.14, 0), AbyssKit.tinted("spec_core", "flesh", Color(0.35, 0.12, 0.6), 0.0, Color("5a1ab8")))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.34; rim.outer_radius = 0.41; rim.rings = 20; rim.ring_segments = 6
	part("Bell", rim, Vector3(0, 0.0, 0), tent)
	for i in 8:
		var a := TAU * i / 8.0
		part("Bell", _sph(0.035, 0.07), Vector3(cos(a) * 0.38, 0.03, sin(a) * 0.38), AbyssKit.mat("led_violet"))
	var tents := []
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var rr := 0.22 if i % 2 else 0.3
		var prev := "Bell"
		var pos := Vector3(cos(a) * rr, -0.03, sin(a) * rr)
		for sgm in 3:
			var nm := "T%d_%d" % [i, sgm]
			joint(nm, prev, pos)
			var ln := 0.34 - sgm * 0.05
			part(nm, AbyssKit.cyl(0.03 - sgm * 0.008, 0.022 - sgm * 0.007, ln, 6), Vector3(0, -ln / 2, 0), tent)
			tents.append([nm, i, sgm])
			prev = nm
			pos = Vector3(0, -ln, 0)
	var o := OmniLight3D.new()
	o.light_color = Color("b070ff"); o.omni_range = 3.2; o.light_energy = 1.5
	(joints["Bell"] as Node3D).add_child(o)
	muzzle("Bell", Vector3(0, -0.05, 0.3))
	for spec in [["idle", 2.2, 9.0, 0.08], ["walk", 1.1, 18.0, 0.05]]:
		var k := {"@Bell": [[0, Vector3.ZERO], [spec[1] / 2, Vector3(0, spec[3], 0)], [spec[1], Vector3.ZERO]],
			"%Bell": [[0, Vector3.ZERO], [spec[1] / 2, Vector3(0.06, -0.08, 0.06)], [spec[1], Vector3.ZERO]],
			"Bell": [[0, Vector3(0, 0, 0)], [spec[1], Vector3(0, 40, 0)]]}
		for t in tents:
			var ph: float = t[1] * 0.12 + t[2] * 0.18
			var amp: float = spec[2] * (1 + t[2] * 0.5)
			var L: float = spec[1]
			k[t[0]] = [[0, Vector3(amp * sin(ph * TAU), 0, 0)], [L / 4, Vector3(amp * sin((ph + 0.25) * TAU), 0, 0)],
				[L / 2, Vector3(amp * sin((ph + 0.5) * TAU), 0, 0)], [L * 3 / 4, Vector3(amp * sin((ph + 0.75) * TAU), 0, 0)], [L, Vector3(amp * sin(ph * TAU), 0, 0)]]
		anim(spec[0], spec[1], true, k)
	anim("shoot", 0.5, false, {"%Bell": [[0, Vector3.ZERO], [0.12, Vector3(0.25, 0.15, 0.25)], [0.5, Vector3.ZERO]],
		"@Bell": [[0, Vector3.ZERO], [0.12, Vector3(0, 0.12, 0)], [0.5, Vector3.ZERO]]})
	anim("hit", 0.45, false, {"Bell": [[0, Vector3.ZERO], [0.08, Vector3(-25, 0, 10)], [0.45, Vector3.ZERO]]})
	var death := {"@Bell": [[0, Vector3.ZERO], [0.9, Vector3(0, -1.15, 0)], [1.2, Vector3(0, -1.15, 0)]],
		"Bell": [[0, Vector3.ZERO], [0.9, Vector3(-70, 0, 15)], [1.2, Vector3(-70, 0, 15)]],
		"%Bell": [[0, Vector3.ZERO], [0.9, Vector3(0.1, -0.4, 0.1)], [1.2, Vector3(0.1, -0.4, 0.1)]]}
	anim("death", 1.2, false, death)
