class_name AbyssBattle
extends RefCounted
## Moteur tactique (TacticalEngine + TurnManager + ActionPointSystem + CombatResolver).
## Aucune dépendance au rendu : le rendu envoie des commandes et rejoue les événements renvoyés.
## Référence fonctionnelle : prototype TypeScript (games/abyss-protocol/src/sim).

var grid := AbyssGrid.new()
var units: Array[AbyssUnit] = []
var rng := RandomNumberGenerator.new()
var seed_text := ""
var turn := 1
var side := "human"
var outcome := "ongoing"
var alert := false
var last_known := {} # id soldat -> Vector2i
var artifact := Vector2i(-1, -1) # au sol ; (-1,-1) si porté
var terminal := Vector2i(-1, -1)
var logs_done := false
var evac: Array[Vector2i] = []
var explored := PackedByteArray() # brouillard de guerre côté joueur (1 = déjà vu)

func _init(seed_value := "abyss") -> void:
	seed_text = seed_value
	rng.seed = hash(seed_value)
	var spawns := grid.parse(AbyssData.LAB)
	artifact = spawns["artifact"]
	terminal = spawns["terminal"]
	for p in spawns["evac"]:
		evac.append(p)
	explored.resize(grid.w * grid.h)
	for i in AbyssData.SQUAD.size():
		var q: Dictionary = AbyssData.SQUAD[i]
		var u := _make(q["id"], q["name"], "soldier", spawns["soldiers"][i])
		u.weapon = q["weapon"]; u.acc = q["acc"]; u.react = q["react"]
		u.max_tu = q["tu"]; u.tu = q["tu"]; u.max_hp = q["hp"]; u.hp = q["hp"]; u.grenades = q["grenades"]
		u.medkit = q["medkit"]
		u.ammo = AbyssData.WEAPONS[u.weapon]["mag"]
		units.append(u)
	var n := 0
	for a in spawns["aliens"]:
		n += 1
		var u := _make("a%d" % n, AbyssData.UNITS[a[0]]["name"], a[0], a[1])
		u.facing = Vector2i(-1, -1)
		units.append(u)
	# Les aliens ont capté l'arrivée de l'escouade : ils convergent vers le sas dès le départ.
	alert = true
	last_known["s1"] = spawns["soldiers"][0]
	update_explored()

func _make(id: String, nm: String, kind: String, at: Vector2i) -> AbyssUnit:
	var t: Dictionary = AbyssData.UNITS[kind]
	var u := AbyssUnit.new()
	u.id = id; u.name = nm; u.kind = kind; u.human = kind == "soldier"; u.cell = at
	u.hp = t["hp"]; u.max_hp = t["hp"]; u.tu = t["tu"]; u.max_tu = t["tu"]
	u.acc = t["acc"]; u.react = t["react"]; u.armor = t["armor"]; u.weapon = t["weapon"]
	return u

# ---------- requêtes ----------

func unit(id: String) -> AbyssUnit:
	for u in units:
		if u.id == id:
			return u
	return null

func living(human_side = null) -> Array[AbyssUnit]:
	var out: Array[AbyssUnit] = []
	for u in units:
		if u.alive and not u.evacuated and (human_side == null or u.human == human_side):
			out.append(u)
	return out

func unit_at(p: Vector2i) -> AbyssUnit:
	for u in units:
		if u.alive and not u.evacuated and u.cell == p:
			return u
	return null

func occupied(except: AbyssUnit) -> Dictionary:
	var o := {}
	for u in units:
		if u.alive and not u.evacuated and u != except:
			o[grid.idx(u.cell)] = true
	return o

func reach(u: AbyssUnit, budget := -1) -> Dictionary:
	return grid.reach(u, u.tu if budget < 0 else budget, occupied(u))

func sees(viewer: AbyssUnit, target: AbyssUnit) -> bool:
	var up := AbyssData.BODY * (0.65 if target.kneeling else 1.0)
	return grid.can_see(viewer, target.cell, up)

## Ennemis vus par au moins une unité du camp.
func spotted_by(human_side: bool) -> Array[AbyssUnit]:
	var out: Array[AbyssUnit] = []
	var mine := living(human_side)
	for e in living(not human_side):
		for m in mine:
			if sees(m, e):
				out.append(e)
				break
	return out

func seen_by_humans(u: AbyssUnit) -> bool:
	if u.human:
		return true
	for h in living(true):
		if sees(h, u):
			return true
	return false

# ---------- combat ----------

func mode_def(u: AbyssUnit, mode: String) -> Array:
	return AbyssData.WEAPONS[u.weapon].get(mode, [])

func shot_cost(u: AbyssUnit, mode: String) -> int:
	var m := mode_def(u, mode)
	return m[0] if m.size() == 2 else 9999

## Aperçu de tir : chance, couverture, coût, erreur éventuelle.
func shot_info(u: AbyssUnit, t: AbyssUnit, mode: String, from := Vector2i(-1, -1)) -> Dictionary:
	var src := u.cell if from == Vector2i(-1, -1) else from
	var w: Dictionary = AbyssData.WEAPONS[u.weapon]
	var m := mode_def(u, mode)
	var dist := Vector2(src).distance_to(Vector2(t.cell))
	var cover := 0 if w.get("ignores_cover", false) else grid.cover_against(t.cell, src, t.kneeling)
	var info := {"chance": 0, "cover": cover, "cost": shot_cost(u, mode), "error": ""}
	if m.size() != 2:
		info["error"] = "Mode indisponible"; return info
	if w.get("mag", 0) > 0 and u.ammo <= 0:
		info["error"] = "Chargeur vide — rechargez"; return info
	var up := AbyssData.BODY * (0.65 if t.kneeling else 1.0)
	var eye := AbyssData.EYE * (0.7 if u.kneeling and src == u.cell else 1.0)
	if not grid.line_clear(src, eye, t.cell, up):
		info["error"] = "Pas de ligne de tir"; return info
	if dist > w["range"]:
		info["error"] = "Hors de portée"; return info
	var c: float = u.acc * m[1] / 100.0
	if u.kneeling and src == u.cell:
		c += AbyssData.KNEEL_ACC
	if grid.z(src) - grid.z(t.cell) >= 1.0:
		c += AbyssData.HEIGHT_BONUS
	c -= maxf(0.0, dist - AbyssData.RANGE_FROM) * (3.0 if mode == "snap" else 2.0)
	c -= mini(4, u.wounds) * AbyssData.WOUND_PENALTY
	c -= AbyssData.COVER_PENALTY[cover]
	info["chance"] = int(round(clampf(c, AbyssData.MIN_CHANCE, AbyssData.MAX_CHANCE)))
	if u.tu < info["cost"]:
		info["error"] = "UT insuffisantes"
	return info

func _damage(t: AbyssUnit, amount: int, ev: Array, by: AbyssUnit, drain := 0) -> void:
	if not t.alive:
		return
	t.hp -= amount
	var wounded := amount >= AbyssData.WOUND_THRESHOLD
	if wounded:
		t.wounds += 1
	t.drain += drain
	ev.append({"t": "damage", "unit": t.id, "amount": amount, "hp": maxi(0, t.hp), "wounded": wounded, "drained": drain})
	if not t.human:
		alert = true
	if t.hp <= 0:
		t.alive = false
		t.hp = 0
		if by:
			by.kills += 1
		ev.append({"t": "death", "unit": t.id})
		if t.carrying:
			t.carrying = false
			artifact = t.cell
			ev.append({"t": "drop", "at": t.cell})

func _resolve_shot(u: AbyssUnit, t: AbyssUnit, mode: String, ev: Array, reaction := false) -> void:
	var info := shot_info(u, t, mode)
	var w: Dictionary = AbyssData.WEAPONS[u.weapon]
	var hit := rng.randi_range(0, 99) < int(info["chance"])
	if w.get("mag", 0) > 0:
		u.ammo -= 1
	u.facing = _dir(t.cell - u.cell, u.facing)
	ev.append({"t": "shot", "unit": u.id, "from": u.cell, "to": t.cell, "target": t.id, "weapon": u.weapon, "mode": mode,
		"chance": info["chance"], "hit": hit, "reaction": reaction, "seen": seen_by_humans(u)})
	if u.human:
		alert = true
		last_known[u.id] = u.cell
	if hit:
		var raw := int(round(w["damage"] * (0.5 + rng.randf())))
		_damage(t, maxi(0, raw - t.armor), ev, u, w.get("drain", 0))

func _dir(d: Vector2i, fallback: Vector2i) -> Vector2i:
	return Vector2i(signi(d.x), signi(d.y)) if d != Vector2i.ZERO else fallback

func _reaction_score(u: AbyssUnit) -> float:
	return float(u.react) * u.tu / u.max_tu

## Tirs de réaction après chaque pas (règle X-COM + surveillance garantie et gratuite).
func _reactions(mover: AbyssUnit, ev: Array) -> void:
	for e in living(not mover.human):
		if not mover.alive or outcome != "ongoing":
			return
		var w: Dictionary = AbyssData.WEAPONS[e.weapon]
		if w.get("mag", 0) > 0 and e.ammo <= 0:
			continue
		if not sees(e, mover) or Vector2(e.cell).distance_to(Vector2(mover.cell)) > w["range"]:
			continue
		var cost := 0 if e.watching else shot_cost(e, "snap")
		if e.tu < cost:
			continue
		if not e.watching and _reaction_score(e) <= _reaction_score(mover):
			continue
		e.tu -= cost
		e.watching = false
		if not e.human:
			alert = true
			last_known[mover.id] = mover.cell
		_resolve_shot(e, mover, "snap", ev, true)

func _awareness() -> void:
	for h in spotted_by(false):
		alert = true
		last_known[h.id] = h.cell

## Déplacement pas à pas, interrompu par un nouveau contact ou un tir de réaction mortel.
func do_move(u: AbyssUnit, path: Array[Vector2i], ev: Array) -> bool:
	var known := {}
	for e in spotted_by(u.human):
		known[e.id] = true
	for p in path:
		var c := grid.step_cost(u.cell, p, u, occupied(u))
		if c == INF or c > u.tu:
			break
		var from := u.cell
		var was_seen := seen_by_humans(u)
		u.tu -= int(c)
		u.facing = _dir(p - from, u.facing)
		u.cell = p
		u.kneeling = false
		var now_seen := seen_by_humans(u)
		ev.append({"t": "move", "unit": u.id, "from": from, "to": p, "seen": was_seen or now_seen})
		if not u.human and not was_seen and now_seen:
			ev.append({"t": "spotted", "unit": u.id})
		if u.human:
			update_explored(u)
		_awareness()
		_reactions(u, ev)
		if not u.alive or outcome != "ongoing":
			return true
		var fresh := false
		for e in spotted_by(u.human):
			if not known.has(e.id):
				fresh = true
				if u.human:
					ev.append({"t": "spotted", "unit": e.id})
		if fresh:
			ev.append({"t": "interrupt", "unit": u.id})
			return true
	return false

func throw_error(u: AbyssUnit, at: Vector2i) -> String:
	if u.grenades <= 0: return "Plus de grenade"
	if u.tu < AbyssData.GRENADE_TU: return "UT insuffisantes"
	if maxi(absi(at.x - u.cell.x), absi(at.y - u.cell.y)) > AbyssData.GRENADE_RANGE: return "Trop loin"
	if not grid.line_clear(u.cell, AbyssData.EYE, at, 0.3): return "Point non visible"
	return ""

## Grenade : dégâts dégressifs, cloisons et caisses pulvérisées au contact (décor destructible).
func _explode(by: AbyssUnit, at: Vector2i, ev: Array) -> void:
	ev.append({"t": "explosion", "at": at, "radius": AbyssData.GRENADE_RADIUS})
	alert = true
	for u in living():
		var d := maxi(absi(u.cell.x - at.x), absi(u.cell.y - at.y))
		if d > AbyssData.GRENADE_RADIUS or not grid.line_clear(at, 0.4, u.cell, 0.6):
			continue
		var raw := int(round((AbyssData.GRENADE_DAMAGE - AbyssData.GRENADE_FALLOFF * d) * (0.8 + 0.4 * rng.randf())))
		_damage(u, maxi(0, raw - u.armor / 2), ev, by)
	for y in range(at.y - 1, at.y + 2):
		for x in range(at.x - 1, at.x + 2):
			var p := Vector2i(x, y)
			if grid.damage_wall(p, AbyssData.GRENADE_DAMAGE) or grid.smash_low(p):
				ev.append({"t": "destroy", "at": p})

func breach_info(u: AbyssUnit, wall: Vector2i) -> Dictionary:
	var info := {"cost": shot_cost(u, "aimed"), "error": ""}
	if not AbyssData.WEAPONS[u.weapon]["breach"]:
		info["error"] = "Seul le harpon lourd perce les cloisons"
	elif grid.tile(wall) != AbyssGrid.T.WALL:
		info["error"] = "Pas une cloison"
	elif Vector2(u.cell).distance_to(Vector2(wall)) > 6:
		info["error"] = "Trop loin (6 cases max)"
	elif u.tu < info["cost"]:
		info["error"] = "UT insuffisantes"
	return info

func _check_outcome(ev: Array) -> void:
	if outcome != "ongoing":
		return
	if living(true).is_empty():
		outcome = "defeat"
	elif living(false).is_empty():
		outcome = "victory"
	if outcome != "ongoing":
		ev.append({"t": "outcome", "outcome": outcome})

## Brouillard : mémorise les cases vues par l'escouade.
func update_explored(only: AbyssUnit = null) -> void:
	var who: Array[AbyssUnit] = living(true)
	if only:
		who = [only]
	for h in who:
		var r: int = h.vision()
		for y in range(maxi(0, h.cell.y - r), mini(grid.h, h.cell.y + r + 1)):
			for x in range(maxi(0, h.cell.x - r), mini(grid.w, h.cell.x + r + 1)):
				var p := Vector2i(x, y)
				var k := grid.idx(p)
				if explored[k] == 0 and grid.can_see(h, p, 0.3):
					explored[k] = 1

func in_evac(p: Vector2i) -> bool:
	return evac.has(p)

func _near(u: AbyssUnit, p: Vector2i) -> bool:
	return maxi(absi(u.cell.x - p.x), absi(u.cell.y - p.y)) <= 1 and absf(grid.z(u.cell) - grid.z(p)) <= 0.5

## Ce qu'« Interagir » ferait : "artifact", "terminal" ou "".
func interact_target(u: AbyssUnit) -> String:
	if artifact.x >= 0 and _near(u, artifact):
		return "artifact"
	if not logs_done and _near(u, terminal):
		return "terminal"
	return ""

func heal_error(u: AbyssUnit, t: AbyssUnit) -> String:
	if u.medkit <= 0: return "Kit médical vide"
	if t == null or not t.alive or not t.human: return "Cible invalide"
	if maxi(absi(u.cell.x - t.cell.x), absi(u.cell.y - t.cell.y)) > 1: return "Contact requis"
	if u.tu < AbyssData.MEDKIT_TU: return "UT insuffisantes"
	if t.hp >= t.max_hp and t.wounds == 0: return "Pas blessé"
	return ""

func reload_error(u: AbyssUnit) -> String:
	var mag: int = AbyssData.WEAPONS[u.weapon].get("mag", 0)
	if mag == 0 or u.ammo >= mag: return "Chargeur plein"
	if u.tu < AbyssData.RELOAD_TU: return "UT insuffisantes"
	return ""

## Soldats évacués / laissés sur place si on évacuait maintenant.
func evac_split() -> Dictionary:
	var leaving: Array[AbyssUnit] = []
	var staying: Array[AbyssUnit] = []
	for h in living(true):
		if in_evac(h.cell):
			leaving.append(h)
		else:
			staying.append(h)
	return {"leaving": leaving, "staying": staying}

# ---------- commandes du joueur ----------

## cmd = {"type": "move"|"shoot"|"breach"|"throw"|"kneel"|"watch"|"end_turn", ...}
func apply(cmd: Dictionary) -> Array:
	var ev: Array = []
	if outcome != "ongoing" or side != "human":
		return ev
	var u: AbyssUnit = unit(cmd.get("unit", ""))
	if not cmd["type"] in ["end_turn", "evacuate"] and (u == null or not u.alive or not u.human):
		return ev
	match cmd["type"]:
		"move":
			var r := reach(u)
			var path := grid.path_to(r, cmd["to"])
			if path.is_empty():
				return ev
			do_move(u, path, ev)
		"shoot":
			var t := unit(cmd["target"])
			if t == null or not t.alive or t.human or shot_info(u, t, cmd["mode"])["error"] != "":
				return ev
			u.tu -= shot_cost(u, cmd["mode"])
			_resolve_shot(u, t, cmd["mode"], ev)
		"breach":
			if breach_info(u, cmd["at"])["error"] != "":
				return ev
			u.tu -= shot_cost(u, "aimed")
			u.facing = _dir(cmd["at"] - u.cell, u.facing)
			ev.append({"t": "shot", "unit": u.id, "from": u.cell, "to": cmd["at"], "target": "", "weapon": u.weapon, "mode": "aimed", "chance": 100, "hit": true, "reaction": false, "seen": true})
			alert = true
			if grid.damage_wall(cmd["at"], AbyssData.WEAPONS[u.weapon]["damage"]):
				ev.append({"t": "destroy", "at": cmd["at"]})
			else:
				ev.append({"t": "wall_hit", "at": cmd["at"]})
		"throw":
			if throw_error(u, cmd["to"]) != "":
				return ev
			u.tu -= AbyssData.GRENADE_TU
			u.grenades -= 1
			_explode(u, cmd["to"], ev)
		"reload":
			if reload_error(u) != "":
				return ev
			u.tu -= AbyssData.RELOAD_TU
			u.ammo = AbyssData.WEAPONS[u.weapon]["mag"]
			ev.append({"t": "reload", "unit": u.id})
		"heal":
			var t := unit(cmd["target"])
			if heal_error(u, t) != "":
				return ev
			u.tu -= AbyssData.MEDKIT_TU
			u.medkit -= 1
			var amount := mini(AbyssData.MEDKIT_HEAL, t.max_hp - t.hp)
			t.hp += amount
			t.wounds = 0
			ev.append({"t": "heal", "unit": u.id, "target": t.id, "amount": amount})
		"interact":
			var what := interact_target(u)
			if what == "" or u.tu < AbyssData.INTERACT_TU:
				return ev
			u.tu -= AbyssData.INTERACT_TU
			if what == "artifact":
				u.carrying = true
				artifact = Vector2i(-1, -1)
				alert = true
				last_known[u.id] = u.cell # la pulsation révèle le porteur à tous les aliens
				ev.append({"t": "pickup", "unit": u.id})
				ev.append({"t": "alarm"})
			else:
				logs_done = true
				ev.append({"t": "logs", "unit": u.id})
		"evacuate":
			var split := evac_split()
			if split["leaving"].is_empty():
				return ev
			var ids := []
			var won := false
			for h in split["leaving"]:
				h.evacuated = true
				ids.append(h.id)
				won = won or h.carrying
			ev.append({"t": "evacuate", "units": ids})
			outcome = "victory" if won else "defeat"
			ev.append({"t": "outcome", "outcome": outcome})
		"kneel":
			if u.kneeling or u.tu < AbyssData.KNEEL_TU:
				return ev
			u.tu -= AbyssData.KNEEL_TU
			u.kneeling = true
			ev.append({"t": "kneel", "unit": u.id})
		"watch":
			if u.watching or u.tu < AbyssData.WATCH_TU:
				return ev
			u.tu -= AbyssData.WATCH_TU
			u.watching = true
			ev.append({"t": "watch", "unit": u.id})
		"end_turn":
			_start_side("alien", ev)
			if outcome == "ongoing":
				AbyssAI.run(self, false, ev)
			if outcome == "ongoing":
				turn += 1
				_start_side("human", ev)
				update_explored()
	_check_outcome(ev)
	return ev

func _start_side(s: String, ev: Array) -> void:
	side = s
	ev.append({"t": "turn", "side": s, "turn": turn})
	for u in living(s == "human"):
		u.tu = maxi(0, u.max_tu - u.drain)
		u.drain = 0
		u.watching = false
		if u.wounds > 0:
			u.hp -= u.wounds
			ev.append({"t": "bleed", "unit": u.id, "amount": u.wounds, "hp": maxi(0, u.hp)})
			if u.hp <= 0:
				u.alive = false
				u.hp = 0
				ev.append({"t": "death", "unit": u.id})
	_check_outcome(ev)

## Sauvegarde complète (JSON), RNG comprise : la partie reprend à l'identique.
func to_dict() -> Dictionary:
	var us := []
	for u in units:
		us.append(u.to_dict())
	var lk := {}
	for id in last_known:
		lk[id] = [last_known[id].x, last_known[id].y]
	var walls := {}
	for k in grid.wall_hp:
		walls[str(k)] = grid.wall_hp[k]
	return {"version": 1, "seed": seed_text, "rng": str(rng.state), "turn": turn, "side": side, "outcome": outcome, "alert": alert,
		"last_known": lk, "artifact": [artifact.x, artifact.y], "logs_done": logs_done, "tiles": Array(grid.tiles), "walls": walls,
		"explored": Array(explored), "units": us}

static func from_dict(d: Dictionary) -> AbyssBattle:
	if int(d.get("version", 0)) != 1:
		return null
	var b := AbyssBattle.new(String(d["seed"]))
	b.rng.state = int(String(d["rng"]))
	b.turn = int(d["turn"]); b.side = d["side"]; b.outcome = d["outcome"]; b.alert = d["alert"]; b.logs_done = d["logs_done"]
	b.artifact = Vector2i(int(d["artifact"][0]), int(d["artifact"][1]))
	b.last_known = {}
	for id in d["last_known"]:
		b.last_known[id] = Vector2i(int(d["last_known"][id][0]), int(d["last_known"][id][1]))
	for i in d["tiles"].size():
		b.grid.tiles[i] = int(d["tiles"][i])
	b.grid.wall_hp = {}
	for k in d["walls"]:
		b.grid.wall_hp[int(k)] = int(d["walls"][k])
	for i in d["explored"].size():
		b.explored[i] = int(d["explored"][i])
	b.units.clear()
	for ud in d["units"]:
		b.units.append(AbyssUnit.from_dict(ud))
	return b

## Empreinte de l'état complet (tests de déterminisme et de sauvegarde).
func snapshot() -> String:
	var us := []
	for u in units:
		us.append(u.to_dict())
	return JSON.stringify({"turn": turn, "side": side, "outcome": outcome, "units": us, "tiles": grid.tiles, "rng": rng.state})
