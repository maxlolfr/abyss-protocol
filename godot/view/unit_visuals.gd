class_name UnitVisuals
extends RefCounted
## Point de remplacement des modèles : si `res://assets/units/<kind>.tscn` existe, il est utilisé ;
## sinon on construit le modèle provisoire ci-dessous. Convention pour les futurs modèles 3D :
## origine aux pieds, regard vers +Z, 1 unité = 1 m, nœud "Muzzle" (sortie du tir) optionnel,
## AnimationPlayer optionnel avec les animations "idle", "walk", "shoot", "hit", "death".

static func build(kind: String, mat: Callable) -> Node3D:
	var path := "res://assets/units/%s.tscn" % kind
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	var n := Node3D.new()
	match kind:
		"soldier": _soldier(n, mat)
		"nereide": _nereide(n, mat)
		"carapace": _carapace(n, mat)
		"spectre": _spectre(n, mat)
	return n

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = m
	parent.add_child(mi)
	return mi

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b

static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = h; c.radial_segments = 12; c.rings = 4; return c

static func _cyl(r1: float, r2: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r1; c.bottom_radius = r2; c.height = h; c.radial_segments = 10; return c

static func _sph(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = h; s.radial_segments = 14; s.rings = 7; return s

## Plongeur de combat : combinaison acier, plastron, épaulières, casque à visière cyan, bouteilles dorsales, fusil.
static func _soldier(n: Node3D, mat: Callable) -> void:
	var suit: Material = mat.call("suit", Color("2f4a60"), 0.55, 0.45)
	var armor: Material = mat.call("armor", Color("465766"), 0.8, 0.3)
	var dark: Material = mat.call("dark", Color("141c24"), 0.6, 0.6)
	var visor: Material = mat.call("visor", Color("39d9ef"), 0.0, 0.1, Color("39d9ef"))
	var amber: Material = mat.call("amberStrip", Color("ffb547"), 0.2, 0.5, Color("ff9a2a"))
	for s in [-1, 1]:
		_add(n, _cap(0.075, 0.62), Vector3(0.1 * s, 0.32, 0), suit) # jambes
		_add(n, _box(Vector3(0.13, 0.08, 0.2)), Vector3(0.1 * s, 0.04, 0.03), dark) # bottes
		_add(n, _cap(0.06, 0.48), Vector3(0.25 * s, 0.95, 0.06), suit, Vector3(-25, 0, 8 * s)) # bras
		_add(n, _sph(0.1, 0.12), Vector3(0.22 * s, 1.18, 0), armor) # épaulières
	_add(n, _box(Vector3(0.38, 0.5, 0.24)), Vector3(0, 0.95, 0), suit) # torse
	_add(n, _box(Vector3(0.4, 0.3, 0.06)), Vector3(0, 1.0, 0.13), armor) # plastron
	_add(n, _box(Vector3(0.4, 0.04, 0.27)), Vector3(0, 0.78, 0), amber) # ceinture ambre
	for s in [-1, 1]:
		_add(n, _cyl(0.06, 0.06, 0.42), Vector3(0.08 * s, 1.0, -0.17), dark) # bouteilles
	_add(n, _sph(0.17, 0.32), Vector3(0, 1.38, 0), armor) # casque
	_add(n, _box(Vector3(0.24, 0.09, 0.08)), Vector3(0, 1.39, 0.13), visor) # visière
	var gun := _add(n, _box(Vector3(0.06, 0.08, 0.6)), Vector3(0.17, 0.98, 0.3), dark)
	gun.name = "Gun"
	var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0.17, 0.98, 0.62)
	n.add_child(muzzle)

## Néréide : silhouette élancée, tête allongée, nageoires dorsales, fentes oculaires lumineuses.
static func _nereide(n: Node3D, mat: Callable) -> void:
	var skin: Material = mat.call("nerSkin", Color("1a6b62"), 0.25, 0.3)
	var belly: Material = mat.call("nerBelly", Color("4fae96"), 0.1, 0.4)
	var fin: Material = mat.call("nerFin", Color("52c99a"), 0.1, 0.3, Color("1d6e55"))
	var eye: Material = mat.call("nerEye", Color("e4fff3"), 0, 0.1, Color("8fffd2"))
	for s in [-1, 1]:
		_add(n, _cap(0.06, 0.55), Vector3(0.1 * s, 0.3, -0.04), skin, Vector3(-12, 0, 0)) # cuisses
		_add(n, _cap(0.05, 0.55), Vector3(0.22 * s, 0.95, 0.1), skin, Vector3(-40, 0, 10 * s)) # bras longs
		_add(n, _box(Vector3(0.04, 0.02, 0.18)), Vector3(0.28 * s, 0.72, 0.28), fin) # griffes
	_add(n, _cap(0.16, 0.75), Vector3(0, 0.88, 0), skin, Vector3(10, 0, 0)) # torse penché
	_add(n, _cap(0.12, 0.45), Vector3(0, 0.88, 0.05), belly, Vector3(10, 0, 0))
	_add(n, _cap(0.11, 0.42), Vector3(0, 1.36, 0.12), skin, Vector3(70, 0, 0)) # tête allongée
	_add(n, _box(Vector3(0.2, 0.03, 0.03)), Vector3(0, 1.39, 0.3), eye)
	var dorsal := PrismMesh.new(); dorsal.size = Vector3(0.04, 0.4, 0.45)
	_add(n, dorsal, Vector3(0, 1.25, -0.16), fin)
	var tail := PrismMesh.new(); tail.size = Vector3(0.03, 0.3, 0.3)
	_add(n, tail, Vector3(0, 0.55, -0.22), fin, Vector3(-30, 0, 0))
	var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0.24, 0.8, 0.4)
	n.add_child(muzzle)

static func _carapace(n: Node3D, mat: Callable) -> void:
	var shell: Material = mat.call("cara", Color("7a4a2a"), 0.5, 0.4)
	var plate: Material = mat.call("caraPlate", Color("a06a3a"), 0.6, 0.3)
	var leg: Material = mat.call("caraLeg", Color("3d2414"), 0.3, 0.7)
	var eye: Material = mat.call("caraEye", Color("ffb547"), 0, 0.2, Color("ff9a2a"))
	_add(n, _sph(0.55, 0.62), Vector3(0, 0.5, 0), shell)
	for i in 3:
		_add(n, _cyl(0.4 - i * 0.1, 0.45 - i * 0.1, 0.06), Vector3(0, 0.72 + i * 0.07, -0.05 * i), plate)
	for i in 6:
		var s := 1 if i < 3 else -1
		var a := (i % 3 - 1) * 0.6
		_add(n, _cyl(0.04, 0.025, 0.55), Vector3(0.45 * s, 0.22, sin(a) * 0.35), leg, Vector3(0, 0, -55 * s))
	for s in [-1, 1]:
		_add(n, _sph(0.11, 0.18), Vector3(0.32 * s, 0.45, 0.5), plate) # pinces
	_add(n, _box(Vector3(0.3, 0.05, 0.05)), Vector3(0, 0.6, 0.52), eye)
	var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0, 0.5, 0.6)
	n.add_child(muzzle)

static func _spectre(n: Node3D, mat: Callable) -> void:
	var dome := SphereMesh.new(); dome.radius = 0.38; dome.height = 0.5; dome.is_hemisphere = true
	_add(n, dome, Vector3(0, 1.35, 0), mat.call("spec", Color("9863f5"), 0, 0.2, Color("7a3cff"), 0.8))
	_add(n, _sph(0.14, 0.2), Vector3(0, 1.42, 0), mat.call("specCore", Color("f0e4ff"), 0, 0.1, Color("d9b8ff")))
	for i in 8:
		_add(n, _cyl(0.025, 0.006, 0.95), Vector3(cos(i * 0.8) * 0.22, 0.88, sin(i * 0.8) * 0.22), mat.call("tent", Color("c58bff"), 0, 0.3, Color("6a2adf"), 0.85), Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
	var o := OmniLight3D.new()
	o.position = Vector3(0, 1.3, 0)
	o.light_color = Color("b070ff")
	o.omni_range = 3.2
	o.light_energy = 1.5
	n.add_child(o)
	var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0, 1.3, 0.3)
	n.add_child(muzzle)
