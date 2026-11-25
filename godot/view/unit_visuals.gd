class_name UnitVisuals
extends RefCounted
## Point de remplacement des modèles : si `res://assets/units/<kind>.tscn` existe, il est utilisé ;
## sinon on construit le modèle provisoire ci-dessous. Convention pour les futurs modèles 3D :
## origine aux pieds, regard vers +Z, 1 unité = 1 m, nœud "Muzzle" (sortie du tir) optionnel,
## AnimationPlayer optionnel avec les animations "idle", "walk", "shoot", "hit", "death".

static func build(kind: String, _mat: Callable = Callable(), variant := "") -> Node3D:
	var path := "res://assets/units/%s.tscn" % kind
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	return AbyssRig.build(kind, variant) # modèles articulés V3.1 (view/rigs.gd)
