class_name AbyssCampaign
extends RefCounted
## Moteur de campagne : géoscape (temps, détection, engins, interceptions, opérations aliens, menace,
## financement), base Neptune (salles, personnel, recherche, fabrication, stocks), soldats persistants.
## Aucune dépendance au rendu : l'interface envoie des commandes (`apply`) et fait avancer le temps
## (`advance`) ; les deux renvoient des événements. Même graine + mêmes commandes = même campagne.

const SAVE_VERSION := 1

var rng := RandomNumberGenerator.new()
var seed_text := ""
var minutes := 0
var funds := 0
var threat := 0.0
var alien_budget := 0.0
var regions := {}
var crafts: Array = []
var contacts: Array = []
var sites: Array = []
var rooms: Array = [] # {x, y, type, ready_at}
var staff := {}
var research := {} # id -> {progress, sci}
var research_done: Array = []
var production: Array = [] # {item, left, progress, eng}
var items := {}
var soldiers: Array = []
var recruits: Array = []
var journal: Array = []
var pending := {} # décision bloquante : {"type": "intercept"|"assault", ...}
var outcome := "ongoing"
var reason := ""
var score := 0
var month := 0
var debt_reports := 0
var stats := {"missions": 0, "won": 0, "lost": 0, "kills": 0, "intercepts": 0, "dead": 0}
var _next := 1

func _init(seed_value := "neptune") -> void:
	seed_text = seed_value
	rng.seed = hash(seed_value)
	funds = StratData.START_FUNDS
	threat = StratData.THREAT_START
	alien_budget = 35.0
	for id in StratData.REGIONS:
		regions[id] = {"trust": float(StratData.REGIONS[id]["trust"]), "withdrawn": false, "activity": 0}
	for r in StratData.START_ROOMS:
		rooms.append({"x": r[0], "y": r[1], "type": r[2], "ready_at": 0})
	for s in StratData.STAFF:
		staff[s] = StratData.STAFF[s]["start"]
	items = StratData.START_ITEMS.duplicate()
	_add_craft("barracuda")
	_add_craft("triton")
	for t in StratData.START_SOLDIERS:
		var s: Dictionary = t.duplicate()
		s["armor"] = "combinaison"
		s["status"] = "ready"
		s["wound_until"] = 0
		s["missions"] = 0
		s["kills"] = 0
		s["grenades"] = 1 if s["id"] == "s1" else 0
		s["medkit"] = int(t.get("medkit", 0))
		s["deploy"] = true
		soldiers.append(s)
	_refresh_recruits()
	# Première mission, scriptée : la station Némésis ne répond plus.
	_add_site("nemesis", Vector2(33.2, -41.5), StratData.MISSIONS["nemesis"]["hours"] * 60, ["spectre", "carapace", "nereide"])
	_note("Station Némésis : silence radio depuis 72 heures. Le Triton est prêt à appareiller.", "mission", true)

# ---------- requêtes ----------

func date() -> Dictionary:
	var t := Time.get_unix_time_from_datetime_dict({"year": StratData.START_DATE["year"], "month": StratData.START_DATE["month"], "day": StratData.START_DATE["day"], "hour": 0, "minute": 0, "second": 0})
	return Time.get_datetime_dict_from_unix_time(t + minutes * 60)

func date_text() -> String:
	const M := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
	var d := date()
	return "%d %s %d  %02d:%02d" % [d["day"], M[d["month"] - 1], d["year"], d["hour"], d["minute"]]

func region_of(p: Vector2) -> String:
	var best := ""
	var bd := INF
	for id in StratData.REGIONS:
		var dd := AbyssGeo.dist_km(p, StratData.REGIONS[id]["pos"])
		if dd < bd:
			bd = dd
			best = id
	return best

func trench_at(p: Vector2) -> String:
	for id in StratData.TRENCHES:
		if AbyssGeo.dist_km(p, StratData.TRENCHES[id]["pos"]) <= StratData.TRENCHES[id]["radius"]:
			return id
	return ""

func room_count(type: String, built_only := true) -> int:
	return rooms.filter(func(r): return r["type"] == type and (not built_only or r["ready_at"] <= minutes)).size()

func capacity(key: String) -> int:
	var c := 0
	for r in rooms:
		if r["ready_at"] <= minutes:
			c += int(StratData.ROOMS[r["type"]]["cap"].get(key, 0))
	return c

func power() -> int:
	var p := 0
	for r in rooms:
		if r["ready_at"] <= minutes:
			p += int(StratData.ROOMS[r["type"]]["power"])
	return p

## Portée sonar de la base : la meilleure salle sonar opérationnelle (la puissance manquante la réduit).
func sonar_range() -> float:
	var best := 0.0
	for r in rooms:
		if r["ready_at"] <= minutes:
			best = maxf(best, float(StratData.ROOMS[r["type"]]["cap"].get("sonar", 0)))
	return best * (0.6 if power() < 0 else 1.0)

func busy_scientists() -> int:
	var n := 0
	for id in research:
		n += int(research[id]["sci"])
	return n

func busy_engineers() -> int:
	var n := 0
	for p in production:
		n += int(p["eng"])
	return n

func craft(id: String) -> Dictionary:
	for c in crafts:
		if c["id"] == id:
			return c
	return {}

func contact(id: String) -> Dictionary:
	for c in contacts:
		if c["id"] == id:
			return c
	return {}

func site(id: String) -> Dictionary:
	for s in sites:
		if s["id"] == id:
			return s
	return {}

func soldier(id: String) -> Dictionary:
	for s in soldiers:
		if s["id"] == id:
			return s
	return {}

func has_research(id: String) -> bool:
	return id in research_done

func can_research(id: String) -> String:
	var r: Dictionary = StratData.RESEARCH[id]
	if has_research(id) or research.has(id):
		return "déjà fait"
	for a in r["after"]:
		if not has_research(a):
			return "requiert : " + StratData.RESEARCH[a]["name"]
	for k in r["needs"]:
		if int(items.get(k, 0)) < int(r["needs"][k]):
			return "requiert : " + StratData.ITEMS[k]["name"]
	return ""

func can_manufacture(id: String) -> String:
	var m: Dictionary = StratData.MANUFACTURE[id]
	if m["after"] != "" and not has_research(m["after"]):
		return "requiert : " + StratData.RESEARCH[m["after"]]["name"]
	if funds < int(m["cost"]):
		return "fonds insuffisants"
	for k in m["mats"]:
		if int(items.get(k, 0)) < int(m["mats"][k]):
			return "requiert : " + StratData.ITEMS[k]["name"]
	if m.has("craft_mod"):
		var c := _craft_of_type(m["craft_mod"][0])
		if c.is_empty():
			return "aucun " + StratData.CRAFTS[m["craft_mod"][0]]["name"]
		if m["craft_mod"][1] == "deep" and c.get("deep", false):
			return "déjà installée"
	return ""

func build_error(x: int, y: int, type: String) -> String:
	if x < 0 or y < 0 or x >= StratData.BASE_W or y >= StratData.BASE_H:
		return "hors de la base"
	if _room_at(x, y) != -1:
		return "emplacement occupé"
	var t: Dictionary = StratData.ROOMS[type]
	if t.get("unique", false):
		return "salle unique"
	if t.has("after") and not has_research(t["after"]):
		return "requiert : " + StratData.RESEARCH[t["after"]]["name"]
	if funds < int(t["cost"]):
		return "fonds insuffisants"
	var adj := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _room_at(x + d.x, y + d.y) != -1:
			adj = true
	return "" if adj else "doit toucher une salle existante"

func monthly_income() -> int:
	var inc := 0.0
	for id in regions:
		if not regions[id]["withdrawn"]:
			inc += float(StratData.REGIONS[id]["funding"]) * clampf(regions[id]["trust"] / 60.0, 0.2, 1.6)
	return int(round(inc))

func monthly_costs() -> Dictionary:
	var c := {"personnel": 0, "salles": 0, "engins": 0}
	for s in StratData.STAFF:
		c["personnel"] += int(staff[s]) * int(StratData.STAFF[s]["salary"])
	c["personnel"] += soldiers.filter(func(s): return s["status"] != "dead").size() * StratData.SOLDIER_SALARY
	for r in rooms:
		c["salles"] += int(StratData.ROOMS[r["type"]]["upkeep"])
	for cr in crafts:
		c["engins"] += int(StratData.CRAFTS[cr["type"]]["upkeep"])
	return c

func rank_name(s: Dictionary) -> String:
	return StratData.RANKS[int(s["rank"])]["name"]

func ready_soldiers() -> Array:
	return soldiers.filter(func(s): return s["status"] == "ready")

## Escouade embarquée : les soldats prêts marqués « déployer », dans la limite des places du Triton.
func squad() -> Array:
	var seats := int(StratData.CRAFTS["triton"]["seats"])
	var out := []
	for s in soldiers:
		if s["status"] == "ready" and s.get("deploy", true) and out.size() < seats:
			out.append(s)
	return out

## Chances estimées d'une interception (règles lisibles, simulées sur 200 combats à graine fixe).
func intercept_odds(craft_id: String, contact_id: String) -> int:
	var c := craft(craft_id)
	var k := contact(contact_id)
	if c.is_empty() or k.is_empty():
		return 0
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var wins := 0
	for i in 200:
		if _duel(c, k, r, false)["win"]:
			wins += 1
	return int(round(wins / 2.0))

# ---------- commandes ----------

func apply(cmd: Dictionary) -> Array:
	var ev: Array = []
	if outcome != "ongoing":
		return ev
	match String(cmd.get("type", "")):
		"send":
			_send(cmd, ev)
		"recall":
			var c := craft(cmd["craft"])
			if not c.is_empty() and c["state"] != "base":
				c["state"] = "returning"
				c["target"] = {}
		"engage":
			_resolve_intercept(true, ev)
		"disengage":
			_resolve_intercept(false, ev)
		"assault_cancel":
			if pending.get("type", "") == "assault":
				var c := craft(pending["craft"])
				c["state"] = "returning"
				pending = {}
		"build":
			var err := build_error(int(cmd["x"]), int(cmd["y"]), cmd["room"])
			if err == "":
				var t: Dictionary = StratData.ROOMS[cmd["room"]]
				funds -= int(t["cost"])
				rooms.append({"x": int(cmd["x"]), "y": int(cmd["y"]), "type": cmd["room"], "ready_at": minutes + int(t["days"]) * 1440})
				_note("Construction lancée : %s (%d jours)." % [t["name"], t["days"]], "base")
			else:
				ev.append({"t": "error", "text": err})
		"hire":
			var key: String = cmd["staff"]
			var cap := capacity("scientists" if key == "scientists" else "engineers")
			var cost := int(StratData.STAFF[key]["hire"])
			if int(staff[key]) >= cap:
				ev.append({"t": "error", "text": "capacité atteinte : construisez une salle de plus"})
			elif funds < cost:
				ev.append({"t": "error", "text": "fonds insuffisants"})
			else:
				funds -= cost
				staff[key] = int(staff[key]) + 1
		"research":
			var id: String = cmd["id"]
			var err := can_research(id)
			if err != "":
				ev.append({"t": "error", "text": err})
			else:
				for k in StratData.RESEARCH[id]["needs"]:
					items[k] = int(items[k]) - int(StratData.RESEARCH[id]["needs"][k])
				research[id] = {"progress": 0.0, "sci": maxi(0, int(staff["scientists"]) - busy_scientists())}
				_note("Recherche lancée : " + StratData.RESEARCH[id]["name"], "research")
		"assign":
			var id: String = cmd["id"]
			if research.has(id):
				var free := int(staff["scientists"]) - busy_scientists() + int(research[id]["sci"])
				research[id]["sci"] = clampi(int(cmd["sci"]), 0, free)
		"manufacture":
			var id: String = cmd["id"]
			var err := can_manufacture(id)
			if err != "":
				ev.append({"t": "error", "text": err})
			else:
				var m: Dictionary = StratData.MANUFACTURE[id]
				funds -= int(m["cost"])
				for k in m["mats"]:
					items[k] = int(items[k]) - int(m["mats"][k])
				production.append({"item": id, "progress": 0.0, "eng": maxi(0, int(staff["engineers"]) - busy_engineers())})
				_note("Fabrication lancée : " + m["name"], "base")
		"assign_eng":
			var i := int(cmd["index"])
			if i >= 0 and i < production.size():
				var free := int(staff["engineers"]) - busy_engineers() + int(production[i]["eng"])
				production[i]["eng"] = clampi(int(cmd["eng"]), 0, free)
		"recruit":
			var i := int(cmd["index"])
			if i < 0 or i >= recruits.size():
				pass
			elif funds < StratData.RECRUIT_COST:
				ev.append({"t": "error", "text": "fonds insuffisants"})
			elif soldiers.filter(func(s): return s["status"] != "dead").size() >= capacity("beds"):
				ev.append({"t": "error", "text": "dortoirs pleins"})
			else:
				funds -= StratData.RECRUIT_COST
				var s: Dictionary = recruits[i]
				recruits.remove_at(i)
				soldiers.append(s)
				_note("%s rejoint Neptune." % s["name"], "squad")
		"equip":
			_equip(cmd, ev)
		"deploy":
			var s := soldier(cmd["id"])
			if not s.is_empty():
				s["deploy"] = bool(cmd["on"])
		"sell":
			var k: String = cmd["item"]
			var n := mini(int(cmd.get("n", 1)), int(items.get(k, 0)))
			if n > 0 and int(StratData.ITEMS[k].get("sell", 0)) > 0:
				items[k] = int(items[k]) - n
				funds += n * int(StratData.ITEMS[k]["sell"])
	return ev

func _send(cmd: Dictionary, ev: Array) -> void:
	var c := craft(cmd["craft"])
	if c.is_empty() or c["state"] in ["repair", "refuel"]:
		ev.append({"t": "error", "text": "engin indisponible"})
		return
	if cmd.has("contact"):
		var k := contact(cmd["contact"])
		if k.is_empty() or not k["detected"]:
			ev.append({"t": "error", "text": "contact perdu"})
			return
		if c["type"] != "barracuda":
			ev.append({"t": "error", "text": "seul un intercepteur peut engager"})
			return
		c["target"] = {"contact": k["id"]}
	elif cmd.has("site"):
		var s := site(cmd["site"])
		if s.is_empty():
			return
		if c["type"] != "triton":
			ev.append({"t": "error", "text": "seul le Triton transporte l'escouade"})
			return
		if s.get("deep", false) and not c.get("deep", false):
			ev.append({"t": "error", "text": "zone abyssale : coque haute pression requise"})
			return
		if squad().is_empty():
			ev.append({"t": "error", "text": "aucun soldat prêt"})
			return
		c["target"] = {"site": s["id"]}
	else:
		c["target"] = {"pos": cmd["pos"]}
	var tp = _target_pos(c)
	if tp != null and not cmd.has("contact"):
		var need := (AbyssGeo.dist_km(c["pos"], tp) + AbyssGeo.dist_km(tp, StratData.BASE_POS)) / float(c["speed"])
		if need > float(c["fuel"]) * 0.95:
			c["target"] = {}
			ev.append({"t": "error", "text": "hors d'autonomie : aller-retour %d h, carburant %d h" % [int(need), int(c["fuel"])]})
			return
	c["state"] = "outbound"

func _equip(cmd: Dictionary, ev: Array) -> void:
	var s := soldier(cmd["id"])
	if s.is_empty() or s["status"] == "dead":
		return
	var slot: String = cmd["slot"]
	var item: String = cmd["item"]
	if slot == "weapon" or slot == "armor":
		if int(items.get(item, 0)) <= 0:
			ev.append({"t": "error", "text": "plus aucun exemplaire en stock"})
			return
		items[s[slot]] = int(items.get(s[slot], 0)) + 1
		items[item] = int(items[item]) - 1
		s[slot] = item
	elif slot in ["grenades", "medkit"]:
		var key := "grenade" if slot == "grenades" else "medkit"
		var want := clampi(int(cmd["n"]), 0, 3)
		var delta := want - int(s[slot])
		if delta > int(items.get(key, 0)):
			ev.append({"t": "error", "text": "stock insuffisant"})
			return
		items[key] = int(items.get(key, 0)) - delta
		s[slot] = want
	elif slot == "psi":
		if bool(cmd["on"]) and not s.get("psi", false):
			if int(items.get("casque_psi", 0)) <= 0:
				ev.append({"t": "error", "text": "aucun casque psi"})
				return
			items["casque_psi"] = int(items["casque_psi"]) - 1
			s["psi"] = true
		elif not bool(cmd["on"]) and s.get("psi", false):
			items["casque_psi"] = int(items.get("casque_psi", 0)) + 1
			s["psi"] = false

# ---------- temps ----------

## Fait avancer le temps ; s'arrête dès qu'une décision bloquante survient (interception, assaut, rapport).
func advance(mins: int) -> Array:
	var ev: Array = []
	var left := mins
	while left > 0 and pending.is_empty() and outcome == "ongoing":
		var dt := mini(StratData.TICK, left)
		left -= dt
		_tick(dt, ev)
		if ev.any(func(e): return e.get("critical", false)):
			break
	return ev

func _tick(dt: int, ev: Array) -> void:
	var day_before := minutes / 1440
	var month_before: int = date()["month"]
	minutes += dt
	var h := dt / 60.0
	_move_crafts(h, ev)
	_move_contacts(h, ev)
	_detect(ev)
	for s in sites.duplicate():
		if s["expires_at"] > 0 and minutes >= s["expires_at"]:
			_site_expired(s, ev)
	_progress(dt / 1440.0, ev)
	for r in rooms:
		if r["ready_at"] > minutes - dt and r["ready_at"] <= minutes and r["ready_at"] > 0:
			_note("Salle terminée : " + StratData.ROOMS[r["type"]]["name"], "base")
			ev.append({"t": "room", "text": "Salle terminée : " + StratData.ROOMS[r["type"]]["name"]})
	for s in soldiers:
		if s["status"] == "wounded" and minutes >= int(s["wound_until"]):
			s["status"] = "ready"
			_note("%s est rétabli(e)." % s["name"], "squad")
	if minutes / 1440 != day_before:
		_daily(ev)
	if date()["month"] != month_before:
		_monthly(ev)

func _daily(ev: Array) -> void:
	threat = minf(100.0, threat + StratData.THREAT_DAILY)
	alien_budget += StratData.ALIEN_BUDGET_DAILY + threat / 6.0
	_spawn_ops(ev)
	if threat >= 100.0:
		_lose("La menace abyssale a submergé les défenses humaines.", ev)

func _monthly(ev: Array) -> void:
	month += 1
	var inc := monthly_income()
	var c := monthly_costs()
	var cost := int(c["personnel"]) + int(c["salles"]) + int(c["engins"])
	funds += inc - cost
	var lines := ["Rapport du conseil (mois %d) : financement %+d k, dépenses -%d k." % [month, inc, cost]]
	for id in regions:
		var r: Dictionary = regions[id]
		if r["withdrawn"]:
			continue
		if int(r["activity"]) > 0:
			lines.append("%s : %d activité(s) alien sans réponse." % [StratData.REGIONS[id]["name"], r["activity"]])
		else:
			r["trust"] = minf(100.0, float(r["trust"]) + 5.0) # un mois calme rassure
		r["activity"] = 0
		if r["trust"] <= 10.0:
			r["withdrawn"] = true
			lines.append("%s retire son soutien au programme." % StratData.REGIONS[id]["name"])
	debt_reports = debt_reports + 1 if funds < 0 else 0
	_refresh_recruits()
	var text := "\n".join(lines)
	_note(text, "report", true)
	ev.append({"t": "report", "text": text, "critical": true, "income": inc, "costs": c})
	if regions.values().filter(func(r): return r["withdrawn"]).size() >= StratData.LOSE_REGIONS:
		_lose("Trop de conseils régionaux ont abandonné le programme.", ev)
	elif debt_reports >= 2:
		_lose("Deux rapports en déficit : le programme est dissous.", ev)

func _progress(days: float, ev: Array) -> void:
	for id in research.keys():
		var r: Dictionary = research[id]
		r["progress"] = float(r["progress"]) + float(r["sci"]) * days
		if r["progress"] >= float(StratData.RESEARCH[id]["cost"]):
			research.erase(id)
			research_done.append(id)
			_research_effects(id, ev)
			var t: String = "Recherche terminée : %s. %s" % [StratData.RESEARCH[id]["name"], StratData.RESEARCH[id]["desc"]]
			_note(t, "research", true)
			ev.append({"t": "research", "id": id, "text": t, "critical": true})
	var hours := days * 24.0
	for p in production.duplicate():
		p["progress"] = float(p["progress"]) + float(p["eng"]) * hours
		var m: Dictionary = StratData.MANUFACTURE[p["item"]]
		if p["progress"] >= float(m["hours"]):
			production.erase(p)
			if m.has("craft_mod"):
				var c := _craft_of_type(m["craft_mod"][0])
				if m["craft_mod"][1] == "deep":
					c["deep"] = true
				else:
					c["max_hull"] = int(c["max_hull"]) + int(m["craft_mod"][2])
					c["hull"] = int(c["max_hull"])
			else:
				items[p["item"]] = int(items.get(p["item"], 0)) + 1
			var t: String = "Fabrication terminée : " + m["name"]
			_note(t, "base")
			ev.append({"t": "made", "text": t})

func _research_effects(id: String, ev: Array) -> void:
	var e: Dictionary = StratData.RESEARCH[id].get("effect", {})
	if e.has("interceptor_speed"):
		for c in crafts:
			if c["type"] == "barracuda":
				c["speed"] = float(StratData.CRAFTS["barracuda"]["speed"]) * float(e["interceptor_speed"])
	if e.get("reveal_nest", false) and site_of_kind("nid").is_empty():
		var s := _add_site("nid", StratData.NEST, 0, ["spectre", "carapace", "nereide", "nereide"])
		s["deep"] = true
		ev.append({"t": "site", "id": s["id"], "text": "Le Nid est localisé : fosse des Mariannes.", "critical": true})

func site_of_kind(kind: String) -> Dictionary:
	for s in sites:
		if s["kind"] == kind:
			return s
	return {}

# ---------- engins ----------

func _add_craft(type: String) -> Dictionary:
	var t: Dictionary = StratData.CRAFTS[type]
	var c := {"id": "%s%d" % [type, _next], "type": type, "name": t["name"], "pos": StratData.BASE_POS, "state": "base", "target": {},
		"fuel": float(t["fuel"]), "hull": int(t["hull"]), "max_hull": int(t["hull"]), "speed": float(t["speed"]), "deep": false, "ready_at": 0}
	_next += 1
	crafts.append(c)
	return c

func _craft_of_type(type: String) -> Dictionary:
	for c in crafts:
		if c["type"] == type:
			return c
	return {}

func _target_pos(c: Dictionary) -> Variant:
	var t: Dictionary = c["target"]
	if t.has("contact"):
		var k := contact(t["contact"])
		return k["pos"] if not k.is_empty() and k["detected"] else null
	if t.has("site"):
		var s := site(t["site"])
		return s["pos"] if not s.is_empty() else null
	if t.has("pos"):
		return t["pos"]
	return null

func _move_crafts(h: float, ev: Array) -> void:
	for c in crafts:
		match c["state"]:
			"repair", "refuel":
				if minutes >= int(c["ready_at"]):
					c["state"] = "base"
					c["hull"] = int(c["max_hull"])
					c["fuel"] = float(StratData.CRAFTS[c["type"]]["fuel"])
					ev.append({"t": "craft", "text": "%s prêt." % c["name"]})
			"outbound", "patrol":
				c["fuel"] = float(c["fuel"]) - h
				var tp = _target_pos(c)
				var home := AbyssGeo.dist_km(c["pos"], StratData.BASE_POS)
				if tp == null:
					c["state"] = "returning"
					c["target"] = {}
					ev.append({"t": "craft", "text": "%s : cible perdue, retour à Neptune." % c["name"]})
				elif float(c["fuel"]) * float(c["speed"]) <= home * 1.05:
					c["state"] = "returning"
					c["target"] = {}
					_note("%s : réserve de carburant, retour à Neptune." % c["name"], "craft")
					ev.append({"t": "craft", "text": "%s : carburant bas, retour." % c["name"]})
				else:
					c["pos"] = AbyssGeo.step_toward(c["pos"], tp, float(c["speed"]) * h)
					if AbyssGeo.dist_km(c["pos"], tp) < 25.0:
						_arrive(c, ev)
			"returning":
				c["fuel"] = float(c["fuel"]) - h
				c["pos"] = AbyssGeo.step_toward(c["pos"], StratData.BASE_POS, float(c["speed"]) * h)
				if AbyssGeo.dist_km(c["pos"], StratData.BASE_POS) < 25.0:
					c["pos"] = StratData.BASE_POS
					var dmg := int(c["max_hull"]) - int(c["hull"])
					var fuel_h := float(StratData.CRAFTS[c["type"]]["fuel"]) - float(c["fuel"])
					c["state"] = "repair" if dmg > 0 else "refuel"
					c["ready_at"] = minutes + int(dmg * 30 + fuel_h * 6)
					ev.append({"t": "craft", "text": "%s rentré à Neptune." % c["name"]})

func _arrive(c: Dictionary, ev: Array) -> void:
	var t: Dictionary = c["target"]
	if t.has("contact"):
		var k := contact(t["contact"])
		pending = {"type": "intercept", "craft": c["id"], "contact": k["id"], "odds": intercept_odds(c["id"], k["id"])}
		ev.append({"t": "intercept", "text": "%s au contact de : %s." % [c["name"], StratData.ALIEN_SUBS[k["sub"]]["name"]], "critical": true})
	elif t.has("site"):
		c["state"] = "site"
		pending = {"type": "assault", "craft": c["id"], "site": t["site"]}
		ev.append({"t": "assault", "site": t["site"], "text": "Le Triton est sur zone : %s." % site(t["site"])["name"], "critical": true})
	else:
		c["state"] = "patrol"

## Une passe d'armes, règles simples : chaque round l'intercepteur tire (acc %, dégâts), puis l'alien.
## Huit rounds au plus : au-delà l'alien décroche.
func _duel(c: Dictionary, k: Dictionary, r: RandomNumberGenerator, record: bool) -> Dictionary:
	var w: Dictionary = StratData.CRAFTS["barracuda"]["weapon"]
	var a: Dictionary = StratData.ALIEN_SUBS[k["sub"]]
	var mine := int(c["hull"])
	var theirs := int(k["hull"])
	var rounds: Array = []
	for i in 8:
		var hit := r.randi_range(1, 100) <= int(w["acc"])
		if hit:
			theirs -= int(w["damage"])
		var back := false
		if theirs > 0:
			back = r.randi_range(1, 100) <= int(a["acc"])
			if back:
				mine -= int(a["damage"])
		if record:
			rounds.append([hit, back])
		if theirs <= 0 or mine <= 0:
			break
	return {"win": theirs <= 0, "lost": mine <= 0, "hull": maxi(0, mine), "alien_hull": maxi(0, theirs), "rounds": rounds}

func _resolve_intercept(engage: bool, ev: Array) -> void:
	if pending.get("type", "") != "intercept":
		return
	var c := craft(pending["craft"])
	var k := contact(pending["contact"])
	pending = {}
	c["target"] = {}
	c["state"] = "returning"
	if not engage or k.is_empty():
		ev.append({"t": "intercept_result", "text": "%s rompt le contact." % c["name"]})
		return
	var res := _duel(c, k, rng, true)
	c["hull"] = res["hull"]
	k["hull"] = res["alien_hull"]
	var name: String = StratData.ALIEN_SUBS[k["sub"]]["name"]
	var text := ""
	if res["lost"]:
		text = "%s détruit par le %s. L'équipage est récupéré, l'engin est perdu." % [c["name"], name]
		crafts.erase(c)
		_add_craft(c["type"]) # remplacement (coûteux)
		funds -= 300
		threat += 2
	elif res["win"]:
		stats["intercepts"] += 1
		contacts.erase(k)
		for id in regions:
			if not regions[id]["withdrawn"]:
				regions[id]["trust"] = minf(100.0, float(regions[id]["trust"]) + 1.0)
		threat = maxf(0.0, threat - 4)
		score += 15
		var deep := trench_at(k["pos"]) != ""
		var s := _add_site("epave", k["pos"], StratData.MISSIONS["epave"]["hours"] * 60, _crew(k["sub"]))
		s["deep"] = deep
		text = "%s abattu. Épave localisée%s." % [name, " dans une zone abyssale (coque haute pression requise)" if deep else ""]
		ev.append({"t": "site", "id": s["id"], "text": "Nouvelle mission : épave alien."})
	else:
		text = "Le %s décroche, endommagé (%d %%). %s regagne Neptune." % [name, int(100.0 * res["alien_hull"] / StratData.ALIEN_SUBS[k["sub"]]["hull"]), c["name"]]
	_note(text, "intercept", true)
	ev.append({"t": "intercept_result", "text": text, "rounds": res["rounds"], "win": res["win"], "lost": res["lost"]})

func _crew(sub: String) -> Array:
	match sub:
		"eclaireur":
			return ["nereide", "nereide"]
		"moissonneur":
			return ["nereide", "carapace", "nereide"]
		_:
			return ["carapace", "spectre", "nereide", "carapace"]

# ---------- aliens ----------

func _spawn_ops(ev: Array) -> void:
	var choices := ["reconnaissance", "moisson", "raid"]
	if threat < 20:
		choices = ["reconnaissance", "moisson", "reconnaissance"]
	for i in 3:
		var op: String = choices[rng.randi_range(0, choices.size() - 1)]
		var cost := float(StratData.ALIEN_OPS[op]["cost"])
		if alien_budget < cost or contacts.size() >= 4:
			return
		alien_budget -= cost
		_new_op(op)

func _new_op(op: String) -> Dictionary:
	var t: Dictionary = StratData.ALIEN_OPS[op]
	var tk: Array = StratData.TRENCHES.keys()
	var origin: Vector2 = StratData.TRENCHES[tk[rng.randi_range(0, tk.size() - 1)]]["pos"]
	var pk: Array = StratData.PORTS.keys()
	var port: String = pk[rng.randi_range(0, pk.size() - 1)]
	var dest: Vector2 = StratData.PORTS[port]["pos"]
	if op == "reconnaissance":
		dest = AbyssGeo.offset(StratData.BASE_POS if rng.randf() < 0.4 else origin, rng.randf_range(0, 360), rng.randf_range(600, 2200))
	var sub: String = t["sub"]
	if op != "reconnaissance" and threat >= 60 and rng.randf() < 0.4:
		sub = "cuirasse"
	var k := {"id": "c%d" % _next, "op": op, "sub": sub, "pos": origin, "dest": dest, "port": port,
		"hull": int(StratData.ALIEN_SUBS[sub]["hull"]), "detected": false, "error": 900.0,
		"ends_at": minutes + int(rng.randf_range(t["hours"][0], t["hours"][1]) * 60), "arrived": false}
	_next += 1
	contacts.append(k)
	return k

func _move_contacts(h: float, ev: Array) -> void:
	for k in contacts.duplicate():
		if pending.get("contact", "") == k["id"]:
			continue
		var sp := float(StratData.ALIEN_SUBS[k["sub"]]["speed"])
		if not k["arrived"]:
			k["pos"] = AbyssGeo.step_toward(k["pos"], k["dest"], sp * h)
			if AbyssGeo.dist_km(k["pos"], k["dest"]) < 20.0:
				k["arrived"] = true
				if k["op"] == "raid":
					_raid_lands(k, ev)
					continue
				if k["op"] == "reconnaissance":
					k["dest"] = AbyssGeo.offset(k["pos"], rng.randf_range(0, 360), rng.randf_range(500, 1500))
					k["arrived"] = false
		if minutes >= int(k["ends_at"]):
			_op_done(k, ev)

func _op_done(k: Dictionary, ev: Array) -> void:
	contacts.erase(k)
	var t: Dictionary = StratData.ALIEN_OPS[k["op"]]
	var reg := region_of(k["pos"])
	regions[reg]["trust"] = maxf(0.0, float(regions[reg]["trust"]) + float(t["trust"]) * (1.0 if k["detected"] else 0.5))
	regions[reg]["activity"] = int(regions[reg]["activity"]) + 1
	threat = minf(100.0, threat + float(t["threat"]))
	if k["detected"]:
		var text := "%s : %s achevée sans réponse (%s, confiance %+d)." % [StratData.ALIEN_SUBS[k["sub"]]["name"], t["name"], StratData.REGIONS[reg]["name"], int(t["trust"])]
		_note(text, "alien")
		ev.append({"t": "alien", "text": text})

func _raid_lands(k: Dictionary, ev: Array) -> void:
	contacts.erase(k)
	var port: Dictionary = StratData.PORTS[k["port"]]
	var crew := _crew(k["sub"])
	var s := _add_site("port", port["pos"], StratData.MISSIONS["port"]["hours"] * 60, crew)
	s["name"] = "Port attaqué : " + port["name"]
	var text := "ALERTE : des créatures attaquent le port de %s. Intervention requise sous %d h." % [port["name"], StratData.MISSIONS["port"]["hours"]]
	_note(text, "mission", true)
	ev.append({"t": "site", "id": s["id"], "text": text, "critical": true})

func _detect(ev: Array) -> void:
	var srange := sonar_range()
	for k in contacts:
		var seen := AbyssGeo.dist_km(k["pos"], StratData.BASE_POS) <= srange
		for c in crafts:
			if c["state"] in ["outbound", "patrol", "returning", "site"] and AbyssGeo.dist_km(k["pos"], c["pos"]) <= float(StratData.CRAFTS[c["type"]]["sonar"]):
				seen = true
		if seen:
			if not k["detected"] and rng.randf() < float(StratData.ALIEN_SUBS[k["sub"]]["detect"]):
				k["detected"] = true
				k["error"] = 900.0
				var text := "Contact sonar : %s (%s), %s." % [StratData.ALIEN_SUBS[k["sub"]]["name"], StratData.ALIEN_OPS[k["op"]]["name"].to_lower(), StratData.REGIONS[region_of(k["pos"])]["name"]]
				_note(text, "contact", true)
				ev.append({"t": "contact", "id": k["id"], "text": text, "critical": true})
			elif k["detected"]:
				k["error"] = maxf(40.0, float(k["error"]) * 0.8) # le relèvement s'affine
		elif k["detected"]:
			k["error"] = minf(1500.0, float(k["error"]) + 60.0)
			if k["error"] >= 1500.0:
				k["detected"] = false
				ev.append({"t": "contact_lost", "id": k["id"], "text": "Contact perdu."})

# ---------- missions ----------

func _add_site(kind: String, pos: Vector2, life_minutes: int, aliens: Array) -> Dictionary:
	var m: Dictionary = StratData.MISSIONS[kind]
	var s := {"id": "m%d" % _next, "kind": kind, "name": m["name"], "pos": pos, "region": region_of(pos),
		"expires_at": minutes + life_minutes if life_minutes > 0 else 0, "aliens": aliens, "deep": false}
	_next += 1
	sites.append(s)
	return s

func _site_expired(s: Dictionary, ev: Array) -> void:
	sites.erase(s)
	if pending.get("site", "") == s["id"]:
		pending = {}
	var m: Dictionary = StratData.MISSIONS[s["kind"]]
	var reg: String = s["region"]
	regions[reg]["trust"] = maxf(0.0, float(regions[reg]["trust"]) + float(m["lose_trust"]))
	threat = minf(100.0, threat + 3)
	for c in crafts:
		if c["target"].get("site", "") == s["id"]:
			c["target"] = {}
			c["state"] = "returning"
	var text := "Mission abandonnée : %s. %s perd confiance (%+d)." % [s["name"], StratData.REGIONS[reg]["name"], int(m["lose_trust"])]
	_note(text, "mission", true)
	ev.append({"t": "expired", "text": text, "critical": true})

## Ce que le combat tactique doit charger pour le site en attente d'assaut.
func mission_config(site_id: String) -> Dictionary:
	var s := site(site_id)
	if s.is_empty():
		return {}
	var squad_defs := []
	for sd in squad():
		squad_defs.append({"id": sd["id"], "name": sd["name"], "visual": sd.get("visual", ""), "weapon": sd["weapon"], "acc": sd["acc"],
			"react": sd["react"], "tu": sd["tu"], "hp": sd["hp"], "grenades": sd["grenades"], "medkit": sd["medkit"],
			"armor": int(StratData.ITEMS[sd["armor"]].get("armor", 0)), "psi": sd.get("psi", false), "role": sd.get("role", "")})
	var aliens: Array = s["aliens"].duplicate()
	if s["kind"] != "nemesis" and threat >= 45 and aliens.size() < 5:
		aliens.append("nereide" if threat < 70 else "carapace")
	var acc_vs := {}
	for id in research_done:
		var e: Dictionary = StratData.RESEARCH[id].get("effect", {})
		for k in e.get("acc_vs", {}):
			acc_vs[k] = int(acc_vs.get(k, 0)) + int(e["acc_vs"][k])
	return {"site": site_id, "kind": s["kind"], "name": s["name"], "map": StratData.MISSIONS[s["kind"]]["map"],
		"seed": "%s-%s-%d" % [seed_text, site_id, minutes], "squad": squad_defs, "aliens": aliens,
		"mods": {"acc_vs": acc_vs}, "brief": StratData.MISSIONS[s["kind"]]["brief"]}

## Conséquences d'un combat. res = AbyssBattle.result().
func apply_result(site_id: String, res: Dictionary) -> Array:
	var ev: Array = []
	var s := site(site_id)
	if s.is_empty():
		return ev
	var m: Dictionary = StratData.MISSIONS[s["kind"]]
	var won: bool = res["outcome"] == "victory"
	if won or s["kind"] != "nid":
		sites.erase(s) # le Nid reste en place après un assaut repoussé
	pending = {}
	for c in crafts:
		if c["target"].get("site", "") == site_id:
			c["target"] = {}
			c["state"] = "returning"
	stats["missions"] += 1
	var reg: String = s["region"]
	var lines := []
	if won:
		stats["won"] += 1
		score += int(m["score"])
		regions[reg]["trust"] = minf(100.0, float(regions[reg]["trust"]) + float(m["win_trust"]))
		threat = maxf(0.0, threat - (8.0 if s["kind"] != "nid" else 30.0))
		for id in regions:
			if id != reg and not regions[id]["withdrawn"]:
				regions[id]["trust"] = minf(100.0, float(regions[id]["trust"]) + 2.0)
		for k in m["loot"]:
			items[k] = int(items.get(k, 0)) + int(m["loot"][k])
			lines.append("+%d %s" % [m["loot"][k], StratData.ITEMS[k]["name"]])
		# campagne récupérable : sans l'artefact de Némésis, une autre cargaison alien en contient un
		if s["kind"] in ["epave", "port"] and int(items.get("artefact", 0)) == 0 and not has_research("artefact_nemesis") and not research.has("artefact_nemesis"):
			items["artefact"] = 1
			lines.append("+1 Artefact (émetteur identique à celui de Némésis)")
		for kind in res.get("kills", {}):
			if StratData.CORPSES.has(kind):
				var key: String = StratData.CORPSES[kind]
				items[key] = int(items.get(key, 0)) + int(res["kills"][kind])
				lines.append("+%d %s" % [res["kills"][kind], StratData.ITEMS[key]["name"]])
	else:
		stats["lost"] += 1
		regions[reg]["trust"] = maxf(0.0, float(regions[reg]["trust"]) + float(m["lose_trust"]))
		threat = minf(100.0, threat + 3.0)
	if res.get("artifact", false) and not won:
		items["artefact"] = int(items.get("artefact", 0)) + 1
	for r in res["soldiers"]:
		var sd := soldier(r["id"])
		if sd.is_empty():
			continue
		stats["kills"] += int(r["kills"])
		sd["kills"] = int(sd["kills"]) + int(r["kills"])
		if not r["alive"]:
			sd["status"] = "dead"
			sd["died"] = date_text()
			stats["dead"] += 1
			# équipement perdu avec le soldat
			lines.append("%s est tombé(e) au combat." % sd["name"])
			continue
		sd["missions"] = int(sd["missions"]) + 1
		var gain := 1 + 2 * int(r["kills"]) + (1 if won else 0)
		sd["xp"] = int(sd["xp"]) + gain
		var rk := int(sd["rank"])
		while rk + 1 < StratData.RANKS.size() and int(sd["xp"]) >= int(StratData.RANKS[rk + 1]["xp"]):
			rk += 1
			for st in StratData.PROMOTION_GAIN:
				sd[st] = int(sd[st]) + int(StratData.PROMOTION_GAIN[st])
			lines.append("%s promu(e) %s." % [sd["name"], StratData.RANKS[rk]["name"]])
		sd["rank"] = rk
		sd["grenades"] = mini(int(sd["grenades"]), int(r.get("grenades", sd["grenades"])))
		sd["medkit"] = mini(int(sd["medkit"]), int(r.get("medkit", sd["medkit"])))
		var lost := int(r["max_hp"]) - int(r["hp"]) + 4 * int(r.get("wounds", 0))
		if lost > 0:
			var days := ceili(lost * 0.6) if capacity("heal") == 0 else ceili(lost * 0.3)
			sd["status"] = "wounded"
			sd["wound_until"] = minutes + days * 1440
			lines.append("%s blessé(e) : %d jours d'infirmerie." % [sd["name"], days])
	var text := "%s : %s.\n%s" % [s["name"], "VICTOIRE" if won else "ÉCHEC", "\n".join(lines)]
	_note(text, "mission", true)
	ev.append({"t": "mission_result", "text": text, "won": won})
	if won and s["kind"] == "nid":
		outcome = "victory"
		reason = "Le cœur du Nid est détruit. Le signal s'éteint au fond des Mariannes."
		ev.append({"t": "campaign_end", "text": reason, "critical": true})
	elif soldiers.filter(func(x): return x["status"] != "dead").is_empty() and funds < StratData.RECRUIT_COST:
		_lose("Plus aucun soldat, plus de quoi recruter.", ev)
	return ev

# ---------- divers ----------

func _refresh_recruits() -> void:
	recruits.clear()
	for i in 3:
		var nm := "%s %s" % [StratData.FIRST_NAMES[rng.randi_range(0, StratData.FIRST_NAMES.size() - 1)], StratData.LAST_NAMES[rng.randi_range(0, StratData.LAST_NAMES.size() - 1)]]
		var roles := [["Fusilier", "rifle"], ["Précision", "rifle"], ["Lourd", "harpoon"], ["Médecin", "pistol"]]
		var ro: Array = roles[rng.randi_range(0, roles.size() - 1)]
		recruits.append({"id": "r%d" % _next, "name": nm, "visual": ["s3", "s4"][rng.randi_range(0, 1)], "weapon": ro[1] if int(items.get(ro[1], 0)) > 0 else "rifle",
			"acc": rng.randi_range(56, 70), "react": rng.randi_range(42, 64), "tu": rng.randi_range(54, 62), "hp": rng.randi_range(30, 38),
			"rank": 0, "xp": 0, "role": ro[0], "armor": "combinaison", "status": "ready", "wound_until": 0, "missions": 0, "kills": 0,
			"grenades": 0, "medkit": 1 if ro[0] == "Médecin" else 0, "deploy": true, "weapon_free": true})
		_next += 1

func _room_at(x: int, y: int) -> int:
	for i in rooms.size():
		if int(rooms[i]["x"]) == x and int(rooms[i]["y"]) == y:
			return i
	return -1

func _note(text: String, kind: String, important := false) -> void:
	journal.append({"at": minutes, "date": date_text(), "text": text, "kind": kind, "important": important})
	if journal.size() > 120:
		journal.pop_front()

func _lose(why: String, ev: Array) -> void:
	if outcome != "ongoing":
		return
	outcome = "defeat"
	reason = why
	_note(why, "end", true)
	ev.append({"t": "campaign_end", "text": why, "critical": true})

# ---------- sauvegarde ----------

const FIELDS := ["seed_text", "minutes", "funds", "threat", "alien_budget", "regions", "crafts", "contacts", "sites", "rooms", "staff",
	"research", "research_done", "production", "items", "soldiers", "recruits", "journal", "pending", "outcome", "reason", "score", "month",
	"debt_reports", "stats", "_next"]

func to_dict() -> Dictionary:
	var d := {"version": SAVE_VERSION, "rng_state": str(rng.state)}
	for f in FIELDS:
		d[f] = _enc(get(f))
	return d

static func from_dict(d: Dictionary) -> AbyssCampaign:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return null
	var c := AbyssCampaign.new(String(d["seed_text"]))
	for f in FIELDS:
		if d.has(f):
			c.set(f, _dec(d[f]))
	for f in ["minutes", "funds", "score", "month", "debt_reports", "_next"]:
		c.set(f, int(c.get(f)))
	c.rng.state = int(String(d["rng_state"]))
	return c

static func _enc(v: Variant) -> Variant:
	if v is Vector2:
		return {"__v2": [v.x, v.y]}
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _enc(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _enc(x))
	return v

static func _dec(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("__v2"):
			return Vector2(float(v["__v2"][0]), float(v["__v2"][1]))
		var o := {}
		for k in v:
			o[k] = _dec(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _dec(x))
	return v
