class_name AbyssGrid
extends RefCounted
## Carte tactique 3D : types de cases, hauteurs (0 / 0,5 / 1), murs destructibles,
## coûts de déplacement, zone atteignable, ligne de vue 3D et couverture.

enum T { FLOOR, HULL, WALL, LOW, PLATFORM, STAIRS, WATER, RUBBLE }

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var w := 0
var h := 0
var tiles: Array[int] = []
var heights: Array[float] = [] # hauteur du sol praticable de chaque case
var wall_hp := {} # index -> PV restants

func parse(rows: Array) -> Dictionary:
	h = rows.size()
	w = String(rows[0]).length()
	tiles.clear()
	heights.clear()
	var spawns := {"soldiers": [], "aliens": [], "evac": [], "artifact": Vector2i(-1, -1), "terminal": Vector2i(-1, -1)}
	for y in h:
		var row: String = rows[y]
		for x in w:
			var c := row[x]
			var t := T.FLOOR
			var z := 0.0
			match c:
				"X": t = T.HULL
				"#":
					t = T.WALL
					wall_hp[y * w + x] = AbyssData.WALL_HP
				"c": t = T.LOW
				"T":
					t = T.LOW
					z = 1.0
				"k":
					t = T.LOW
					z = 1.0
				"=", "P": z = 1.0
				"/":
					t = T.STAIRS
					z = 0.5
				"~": t = T.WATER
			tiles.append(t)
			heights.append(z)
			if c == "S":
				spawns["soldiers"].append(Vector2i(x, y))
			if c == "S" or c == "E":
				spawns["evac"].append(Vector2i(x, y))
			if c == "D":
				spawns["artifact"] = Vector2i(x, y)
			if c == "T":
				spawns["terminal"] = Vector2i(x, y)
			elif c in "NCP":
				spawns["aliens"].append([{"N": "nereide", "C": "carapace", "P": "spectre"}[c], Vector2i(x, y)])
	return spawns

func idx(p: Vector2i) -> int:
	return p.y * w + p.x

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h

func tile(p: Vector2i) -> int:
	return tiles[idx(p)] if inside(p) else T.HULL

func z(p: Vector2i) -> float:
	return heights[idx(p)] if inside(p) else 0.0

## Case « pleine » au niveau de son sol (cloison, coque, caisse).
func solid(p: Vector2i) -> bool:
	var t := tile(p)
	return t == T.HULL or t == T.WALL or t == T.LOW

func standable(p: Vector2i, hover := false) -> bool:
	var t := tile(p)
	if t == T.HULL or t == T.WALL:
		return false
	if t == T.LOW:
		return hover
	return true

## Coût en UT d'un pas, INF si interdit (occupation, angle, dénivelé > 0,5).
func step_cost(from: Vector2i, to: Vector2i, u: AbyssUnit, occupied: Dictionary) -> float:
	var tpl := u.tpl()
	var hover: bool = tpl.get("hover", false)
	if not standable(to, hover) or occupied.has(idx(to)):
		return INF
	if absf(z(to) - z(from)) > 0.5:
		return INF
	var diag := from.x != to.x and from.y != to.y
	if diag:
		var a := Vector2i(to.x, from.y)
		var b := Vector2i(from.x, to.y)
		if not standable(a, hover) or not standable(b, hover) or absf(z(a) - z(from)) > 0.5 or absf(z(b) - z(from)) > 0.5:
			return INF
	var c := AbyssData.MOVE_DIAG if diag else AbyssData.MOVE_ORTHO
	var t := tile(to)
	if t == T.WATER and not tpl.get("amphibious", false) and not hover:
		c += AbyssData.WATER_EXTRA
	if t == T.RUBBLE and not hover:
		c += AbyssData.RUBBLE_EXTRA
	return c

## Dijkstra borné : {"cost": {idx: UT}, "prev": {idx: idx}}.
func reach(u: AbyssUnit, budget: int, occupied: Dictionary) -> Dictionary:
	var start := idx(u.cell)
	var cost := {start: 0.0}
	var prev := {}
	var open: Array[int] = [start]
	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var cur: int = open[bi]
		open.remove_at(bi)
		var cp := Vector2i(cur % w, cur / w)
		for d in DIRS:
			var np: Vector2i = cp + d
			var sc := step_cost(cp, np, u, occupied)
			if sc == INF:
				continue
			var nc: float = cost[cur] + sc
			var ni := idx(np)
			if nc > budget or nc >= cost.get(ni, INF):
				continue
			cost[ni] = nc
			prev[ni] = cur
			open.append(ni)
	return {"cost": cost, "prev": prev}

func path_to(r: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := idx(to)
	if not r["cost"].has(k):
		return out
	while r["prev"].has(k):
		out.push_front(Vector2i(k % w, k / w))
		k = r["prev"][k]
	return out

## Ligne de vue 3D entre deux points (cases + hauteur au-dessus de leur sol).
## Bloquée par les cloisons/coque (jusqu'à 2,5 m au-dessus de leur sol) et par le volume plein
## sous les passerelles et escaliers. Les caisses et les unités ne bloquent pas.
func line_clear(a: Vector2i, a_up: float, b: Vector2i, b_up: float) -> bool:
	var p0 := Vector3(a.x + 0.5, z(a) + a_up, a.y + 0.5)
	var p1 := Vector3(b.x + 0.5, z(b) + b_up, b.y + 0.5)
	var n := int(ceil(Vector2(p1.x - p0.x, p1.z - p0.z).length() * 8.0))
	for i in range(1, n):
		var p := p0.lerp(p1, float(i) / n)
		var c := Vector2i(int(floor(p.x)), int(floor(p.z)))
		if c == a or c == b:
			continue
		var t := tile(c)
		if (t == T.WALL or t == T.HULL) and p.y < z(c) + AbyssData.WALL_H:
			return false
		if p.y < z(c) - 0.02: # sous le plancher d'une passerelle ou d'un escalier
			return false
	return true

func can_see(viewer: AbyssUnit, target: Vector2i, target_up := AbyssData.BODY) -> bool:
	if Vector2(viewer.cell).distance_to(Vector2(target)) > viewer.vision():
		return false
	var eye := AbyssData.EYE * (0.7 if viewer.kneeling else 1.0)
	return line_clear(viewer.cell, eye, target, target_up)

## Couverture d'une cible face à un tireur : 0 aucune, 1 partielle, 2 totale.
## Tir plongeant (tireur ≥ 1 m plus haut) : couverture réduite d'un cran.
func cover_against(target: Vector2i, from: Vector2i, kneeling := false) -> int:
	var d := from - target
	if maxi(absi(d.x), absi(d.y)) <= 1:
		return 0
	var best := 0
	if d.x != 0 and absi(d.x) * 2 >= absi(d.y):
		best = maxi(best, _cover_level(target, Vector2i(target.x + signi(d.x), target.y)))
	if d.y != 0 and absi(d.y) * 2 >= absi(d.x):
		best = maxi(best, _cover_level(target, Vector2i(target.x, target.y + signi(d.y))))
	if kneeling and best == 1:
		best = 2
	if z(from) - z(target) >= 1.0:
		best = maxi(0, best - 1)
	return best

func _cover_level(target: Vector2i, n: Vector2i) -> int:
	var t := tile(n)
	if t == T.WALL or t == T.HULL:
		return 2
	if t == T.LOW and z(n) >= z(target) - 0.01:
		return 1
	if z(n) - z(target) >= 1.0: # bord de passerelle au-dessus de la cible
		return 1
	return 0

## Endommage une cloison ; renvoie vrai si elle s'effondre (devient décombres).
func damage_wall(p: Vector2i, amount: int) -> bool:
	if tile(p) != T.WALL:
		return false
	var k := idx(p)
	wall_hp[k] = int(wall_hp.get(k, AbyssData.WALL_HP)) - amount
	if wall_hp[k] > 0:
		return false
	tiles[k] = T.RUBBLE
	wall_hp.erase(k)
	return true

func smash_low(p: Vector2i) -> bool:
	if tile(p) != T.LOW:
		return false
	tiles[idx(p)] = T.RUBBLE
	return true
