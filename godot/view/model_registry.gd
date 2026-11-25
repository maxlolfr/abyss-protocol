class_name ModelRegistry
## Registre des modèles 3D définitifs (GLB Tripo de Max, versions allégées par tools/lighten_glb.py).
## Convention : res://assets/models/<catégorie>/<clé>.glb — déposer le fichier suffit, aucun code à toucher :
##   units/    soldats (s1 walker, s2 okafor, s3 lind, s4 moreau… ou nom du soldat) et espèces (nereide, carapace, spectre, brute)
##   weapons/  armes tenues (rifle, pistol, harpoon, harpoon_ap, cavitation, dart, acid)
##   props/    objets de décor des cartes (console, capsule, armoire, reservoir, caisse…)
##   crafts/   engins (barracuda, triton) et sous-marins aliens (eclaireur, moissonneur, cuirasse)
##   rooms/    salles de la base Neptune (laboratoire, atelier, hangar…)
## Repères attendus : pieds (ou base) à y = 0, regard vers +Z, 1 unité = 1 m — sinon `scale` ci-dessous.
## Les modèles provisoires (sprites, primitives) restent utilisés tant que le fichier n'existe pas.

const ROOT := "res://assets/models/%s/%s.glb"
## Réglages par modèle quand le fichier ne respecte pas la convention : hauteur cible (m), rotation Y (degrés).
const TUNING := {
	"units/okafor": {"height": 1.88}, "units/lind": {"height": 1.82},
	"units/nereide": {"height": 1.95}, "units/brute": {"height": 2.3},
}

static func path(category: String, key: String) -> String:
	return ROOT % [category, key]

static func has(category: String, key: String) -> bool:
	return key != "" and ResourceLoader.exists(path(category, key))

## Instancie le modèle mis à l'échelle (hauteur cible), ou null s'il n'existe pas encore.
static func instance(category: String, key: String, height := 0.0) -> Node3D:
	if not has(category, key):
		return null
	var n: Node3D = (load(path(category, key)) as PackedScene).instantiate()
	var t: Dictionary = TUNING.get(category + "/" + key, {})
	var h: float = t.get("height", height)
	if h > 0.0:
		n.scale = Vector3.ONE * h # modèles Tripo normalisés : 1 unité de haut
	n.rotation_degrees.y = t.get("yaw", 0.0)
	return n
