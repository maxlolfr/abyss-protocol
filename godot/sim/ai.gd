class_name AbyssAI
extends RefCounted
## EnemyAI à règles et à score (portage de src/sim/ai.ts).
## Néréide = cherche le flanc, Carapace = met la pression, Spectre = harcèle à distance depuis la hauteur.

const SHIELD := [1.0, 0.45, 0.12]

static func run(b: AbyssBattle, human_side: bool, ev: Array) -> void:
	var actors := b.living(human_side)
	actors.sort_custom(func(x, y): return x.id < y.id)
	for a in actors:
		if b.outcome != "ongoing":
			return
		if a.alive:
			_act(b, a, ev)
		b._check_outcome(ev)

static func _exposure(b: AbyssBattle, p: Vector2i, foes: Array[AbyssUnit]) -> float:
	var e := 0.0
	for f in foes:
		if b.grid.can_see(f, p):
			e += SHIELD[b.grid.cover_against(p, f.cell)]
	return e

static func _best_attack(b: AbyssBattle, a: AbyssUnit, from: Vector2i, tu: int, foes: Array[AbyssUnit]) -> Dictionary:
	var best := {}
	var w: Dictionary = AbyssData.WEAPONS[a.weapon]
	for t in foes:
		if Vector2(from).distance_to(Vector2(t.cell)) > w["range"]:
			continue
		for mode in ["snap", "aimed"]:
			var cost := b.shot_cost(a, mode)
			if cost > tu:
				continue
			var info := b.shot_info(a, t, mode, from)
			if info["error"] != "" and info["error"] != "UT insuffisantes":
				continue
			var shots := mini(2, tu / cost)
			var dmg := maxf(1.0, w["damage"] - t.armor) + (10.0 if w.has("drain") else 0.0)
			var value: float = info["chance"] / 100.0 * dmg * shots * (1.4 if t.hp <= w["damage"] else 1.0)
			if best.is_empty() or value > best["value"]:
				best = {"target": t, "mode": mode, "value": value, "chance": info["chance"]}
	return best

static func _score(b: AbyssBattle, a: AbyssUnit, p: Vector2i, cost: float, foes: Array[AbyssUnit]) -> float:
	var role: String = a.tpl()["role"]
	var atk := _best_attack(b, a, p, a.tu - int(cost), foes)
	var s: float = atk.get("value", 0.0)
	var exp := _exposure(b, p, foes)
	var nearest := INF
	for f in foes:
		nearest = minf(nearest, Vector2(p).distance_to(Vector2(f.cell)))
	match role:
		"flanker":
			if not atk.is_empty() and b.grid.cover_against(atk["target"].cell, p) == 0:
				s += 8.0
			s -= exp * 7.0
		"brute":
			s -= nearest * 1.2 + exp * 2.5
		"psychic":
			s -= absf(nearest - 7.0) * 1.5 + exp * 9.0
			s += b.grid.z(p) * 4.0 # aime la hauteur
		_:
			s -= exp * 6.0
	return s - cost * 0.04

static func _cell(b: AbyssBattle, i: int) -> Vector2i:
	return Vector2i(i % b.grid.w, i / b.grid.w)

static func _walk_toward(b: AbyssBattle, a: AbyssUnit, goal: Vector2i, reserve: int, ev: Array) -> bool:
	var r := b.reach(a, maxi(0, a.tu - reserve))
	var best := -1
	var bd := Vector2(a.cell).distance_to(Vector2(goal))
	for i in r["cost"]:
		var d := Vector2(_cell(b, i)).distance_to(Vector2(goal))
		if d < bd - 0.01:
			bd = d
			best = i
	if best < 0:
		return false
	return b.do_move(a, b.grid.path_to(r, _cell(b, best)), ev)

static func _act(b: AbyssBattle, a: AbyssUnit, ev: Array) -> void:
	var snap := b.shot_cost(a, "snap")
	for _iter in 4:
		if not a.alive or b.outcome != "ongoing":
			return
		b._awareness()
		var foes := b.spotted_by(a.human)
		if foes.is_empty():
			if a.human:
				_walk_toward(b, a, Vector2i(8, 11), snap * 2, ev)
				return
			if not b.alert:
				var goal := a.cell + Vector2i(b.rng.randi_range(-3, 3), b.rng.randi_range(-3, 3))
				_walk_toward(b, a, goal, a.tu / 2, ev)
				return
			var target := Vector2i(-1, -1)
			var bd := 30.0
			for id in b.last_known:
				var s := b.unit(id)
				if s and s.alive and Vector2(a.cell).distance_to(Vector2(b.last_known[id])) <= bd:
					bd = Vector2(a.cell).distance_to(Vector2(b.last_known[id]))
					target = b.last_known[id]
			if target.x < 0:
				return
			if Vector2(a.cell).distance_to(Vector2(target)) <= 1.5:
				for id in b.last_known.keys():
					if b.last_known[id] == target:
						b.last_known.erase(id)
				continue
			if not _walk_toward(b, a, target, AbyssData.WATCH_TU if a.tpl()["role"] != "brute" else 0, ev):
				_overwatch(b, a)
				return
			continue
		# 1) meilleure position
		var r := b.reach(a, a.tu - snap)
		var best_i := b.grid.idx(a.cell)
		var best_s := _score(b, a, a.cell, 0.0, foes)
		for i in r["cost"]:
			if r["cost"][i] == 0:
				continue
			var s: float = _score(b, a, _cell(b, i), float(r["cost"][i]), foes)
			if s > best_s + 0.01:
				best_s = s
				best_i = i
		if best_i != b.grid.idx(a.cell):
			if b.do_move(a, b.grid.path_to(r, _cell(b, best_i)), ev):
				b._check_outcome(ev)
				continue
		# 2) tirer tant que c'est rentable
		for _n in 3:
			if not a.alive:
				break
			var atk := _best_attack(b, a, a.cell, a.tu, b.spotted_by(a.human))
			if atk.is_empty() or atk["chance"] < 8:
				break
			a.tu -= b.shot_cost(a, atk["mode"])
			b._resolve_shot(a, atk["target"], atk["mode"], ev)
			b._check_outcome(ev)
			if b.outcome != "ongoing":
				return
		# 3) se mettre à l'abri
		var left := b.spotted_by(a.human)
		if a.alive and not left.is_empty() and _exposure(b, a.cell, left) > 0.2:
			var rr := b.reach(a)
			var safe_i := b.grid.idx(a.cell)
			var safe_v := _exposure(b, a.cell, left)
			for i in rr["cost"]:
				var v: float = _exposure(b, _cell(b, i), left) + float(rr["cost"][i]) * 0.005
				if v < safe_v - 0.05:
					safe_v = v
					safe_i = i
			if safe_i != b.grid.idx(a.cell):
				b.do_move(a, b.grid.path_to(rr, _cell(b, safe_i)), ev)
		_overwatch(b, a)
		return

## Les aliens qui gardent assez d'UT se mettent en surveillance (embuscade).
static func _overwatch(b: AbyssBattle, a: AbyssUnit) -> void:
	if not a.human and a.alive and a.tu >= AbyssData.WATCH_TU and not a.watching:
		a.tu -= AbyssData.WATCH_TU
		a.watching = true
