class_name AbyssUnit
extends RefCounted
## Unité de combat (état pur, sérialisable via to_dict).

var id := ""
var name := ""
var kind := ""
var human := true
var cell := Vector2i.ZERO
var hp := 0
var max_hp := 0
var tu := 0
var max_tu := 0
var acc := 0
var react := 0
var armor := 0
var weapon := ""
var wounds := 0
var drain := 0
var grenades := 0
var ammo := 0
var medkit := 0
var carrying := false
var evacuated := false
var kneeling := false
var watching := false
var alive := true
var kills := 0
var facing := Vector2i(1, 1)
var visual := "" # jeu de sprites / modèle (campagne : un soldat garde son apparence quel que soit son rang)
var psi := false # casque psi : immunisé contre l'épuisement

func tpl() -> Dictionary:
	return AbyssData.UNITS[kind]

func vision() -> int:
	return tpl()["vision"]

func to_dict() -> Dictionary:
	var d := {}
	for p in ["id", "name", "kind", "human", "hp", "max_hp", "tu", "max_tu", "acc", "react", "armor", "weapon", "wounds", "drain", "grenades", "ammo", "medkit", "carrying", "evacuated", "kneeling", "watching", "alive", "kills", "visual", "psi"]:
		d[p] = get(p)
	d["cell"] = [cell.x, cell.y]
	d["facing"] = [facing.x, facing.y]
	return d

static func from_dict(d: Dictionary) -> AbyssUnit:
	var u := AbyssUnit.new()
	for k in d:
		if k != "cell" and k != "facing":
			u.set(k, d[k])
	u.cell = Vector2i(int(d["cell"][0]), int(d["cell"][1]))
	u.facing = Vector2i(int(d["facing"][0]), int(d["facing"][1]))
	for k in ["hp", "max_hp", "tu", "max_tu", "acc", "react", "armor", "wounds", "drain", "grenades", "ammo", "medkit", "kills"]:
		u.set(k, int(d[k]))
	return u
