class_name StratPanels
extends RefCounted
## Onglets plein écran : Base (salles, personnel, énergie, hangar, budget, stocks), Escouade (soldats,
## équipement, recrutement, mémorial), Recherche (laboratoire et atelier). Lecture de l'état de la campagne,
## modifications uniquement par `view.cmd(...)`.

const U := preload("res://view/strategy/ui.gd")
const CELL := Vector2(84, 58)

var view: AbyssStrategy
var soldier_sel := ""
var build_at := Vector2i(-1, -1)

func _init(v: AbyssStrategy) -> void:
	view = v

func build(tab: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 62
	root.offset_bottom = -60
	root.offset_left = 8
	root.offset_right = -8
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", U.box(Color(0.012, 0.03, 0.05, 0.94), Color(0.22, 0.85, 0.94, 0.3), 10))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var h := U.hbox(bg, 14)
	match tab:
		"base":
			_base(h)
		"escouade":
			_squad(h)
		"recherche":
			_research(h)
	return root

func _c() -> AbyssCampaign:
	return view.c

# ---------- Base ----------

func _base(h: HBoxContainer) -> void:
	var c := _c()
	var left := U.vbox(h, 6)
	U.label(left, "BASE NEPTUNE  ·  PLAN", 16, U.CYAN)
	U.label(left, "Touchez une case libre voisine d'une salle pour construire.", 12, U.DIM)
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(CELL.x * StratData.BASE_W + 6, CELL.y * StratData.BASE_H + 6)
	left.add_child(grid)
	for y in StratData.BASE_H:
		for x in StratData.BASE_W:
			var i := c._room_at(x, y)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.position = Vector2(x * CELL.x, y * CELL.y)
			b.size = CELL - Vector2(4, 4)
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 12)
			if i >= 0:
				var r: Dictionary = c.rooms[i]
				var t: Dictionary = StratData.ROOMS[r["type"]]
				var building: bool = int(r["ready_at"]) > c.minutes
				b.text = t["name"].replace(" ", "\n") if t["name"].length() > 12 else t["name"]
				if building:
					b.text += "\n" + U.duration(int(r["ready_at"]) - c.minutes)
				b.add_theme_stylebox_override("normal", U.box(Color(0.05, 0.16, 0.22, 0.95) if not building else Color(0.18, 0.13, 0.03, 0.9), U.CYAN if not building else U.AMBER, 4))
				b.add_theme_color_override("font_color", U.TEXT)
			else:
				b.text = "+" if c.build_error(x, y, "stockage") != "doit toucher une salle existante" else ""
				b.add_theme_stylebox_override("normal", U.box(Color(0.02, 0.05, 0.07, 0.8), Color(1, 1, 1, 0.12) if Vector2i(x, y) != build_at else U.AMBER, 4))
				b.add_theme_color_override("font_color", U.DIM)
				b.pressed.connect(func(): build_at = Vector2i(x, y); view.refresh_page())
			for st in ["hover", "pressed"]:
				b.add_theme_stylebox_override(st, b.get_theme_stylebox("normal"))
			grid.add_child(b)
	if build_at.x >= 0:
		_build_menu(left)
	var right := U.scroll(h)
	var v := U.vbox(right, 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	U.label(v, "PERSONNEL", 15, U.CYAN)
	for key in ["scientists", "engineers"]:
		var row := U.hbox(v, 8)
		var cap := c.capacity(key)
		var busy := c.busy_scientists() if key == "scientists" else c.busy_engineers()
		U.label(row, "%s : %d / %d  (%d affectés)" % [StratData.STAFF[key]["name"], c.staff[key], cap, busy], 14, U.TEXT).custom_minimum_size = Vector2(190, 0)
		var b := U.button(row, "Embaucher  %s" % U.k(StratData.STAFF[key]["hire"]), func(): view.cmd({"type": "hire", "staff": key}); view.refresh_page(), "secondary", 0, 13)
		b.disabled = int(c.staff[key]) >= cap
	var pw := c.power()
	U.label(v, "ÉNERGIE : %+d" % pw, 15, U.GREEN if pw >= 0 else U.RED)
	if pw < 0:
		U.label(v, "Déficit : le sonar perd 40 % de portée. Construisez un réacteur.", 12, U.RED, true)
	U.label(v, "Lits : %d / %d  ·  Hangars : %d engins / %d" % [c.soldiers.filter(func(s): return s["status"] != "dead").size(), c.capacity("beds"), c.crafts.size(), c.capacity("crafts")], 13, U.TEXT)
	U.label(v, "HANGAR", 15, U.CYAN)
	for cr in c.crafts:
		var st: String = {"base": "à quai", "outbound": "en mission", "patrol": "en patrouille", "returning": "retour", "site": "sur zone", "repair": "réparation", "refuel": "ravitaillement"}[cr["state"]]
		var extra := ""
		if cr["state"] in ["repair", "refuel"]:
			extra = " (%s)" % U.duration(int(cr["ready_at"]) - c.minutes)
		U.label(v, "%s · %s · %s%s · coque %d/%d%s" % [cr["name"], StratData.CRAFTS[cr["type"]]["role"], st, extra, cr["hull"], cr["max_hull"], "  · haute pression" if cr.get("deep", false) else ""], 13, U.TEXT, true)
	U.label(v, "BUDGET MENSUEL", 15, U.CYAN)
	var costs := c.monthly_costs()
	var total := int(costs["personnel"]) + int(costs["salles"]) + int(costs["engins"])
	var inc := c.monthly_income()
	U.label(v, "Financement prévu : %s\nPersonnel %s · Salles %s · Engins %s\nSolde prévu : %s" % [U.k(inc), U.k(costs["personnel"]), U.k(costs["salles"]), U.k(costs["engins"]), U.k(inc - total)], 13, U.GREEN if inc >= total else U.AMBER, true)
	U.label(v, "STOCKS", 15, U.CYAN)
	for k in c.items:
		var n := int(c.items[k])
		if n <= 0:
			continue
		var row := U.hbox(v, 8)
		U.label(row, "%s × %d" % [StratData.ITEMS[k]["name"], n], 13, U.VIOLET if StratData.ITEMS[k]["kind"] == "alien" else U.TEXT).custom_minimum_size = Vector2(190, 0)
		if int(StratData.ITEMS[k].get("sell", 0)) > 0:
			U.button(row, "Vendre 1  +%s" % U.k(StratData.ITEMS[k]["sell"]), func(): view.cmd({"type": "sell", "item": k, "n": 1}); view.refresh_page(), "secondary", 0, 12)

func _build_menu(parent: VBoxContainer) -> void:
	var c := _c()
	U.label(parent, "CONSTRUIRE EN %d,%d" % [build_at.x + 1, build_at.y + 1], 14, U.AMBER)
	var sc := U.scroll(parent)
	sc.custom_minimum_size = Vector2(0, 110)
	var v := U.vbox(sc, 4)
	for type in StratData.ROOMS:
		var t: Dictionary = StratData.ROOMS[type]
		if t.get("unique", false):
			continue
		var err := c.build_error(build_at.x, build_at.y, type)
		var row := U.hbox(v, 6)
		var b := U.button(row, "%s  ·  %s  ·  %d j" % [t["name"], U.k(t["cost"]), t["days"]], func():
			view.cmd({"type": "build", "x": build_at.x, "y": build_at.y, "room": type})
			build_at = Vector2i(-1, -1)
			view.refresh_page(), "secondary", 330, 13)
		b.disabled = err != ""
		var info := "énergie %+d" % t["power"]
		for k in t["cap"]:
			info += " · %s %d" % [k, t["cap"][k]]
		U.label(row, err if err != "" else info, 11, U.RED if err != "" else U.DIM)

# ---------- Escouade ----------

func _squad(h: HBoxContainer) -> void:
	var c := _c()
	var alive := c.soldiers.filter(func(s): return s["status"] != "dead")
	if soldier_sel == "" or c.soldier(soldier_sel).is_empty() or c.soldier(soldier_sel)["status"] == "dead":
		soldier_sel = alive[0]["id"] if not alive.is_empty() else ""
	var left := U.scroll(h)
	left.custom_minimum_size = Vector2(390, 0)
	left.size_flags_horizontal = Control.SIZE_FILL
	var lv := U.vbox(left, 6)
	U.label(lv, "SOLDATS  ·  Triton : %d / %d places" % [c.squad().size(), StratData.CRAFTS["triton"]["seats"]], 15, U.CYAN)
	for s in alive:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", U.box(Color(0.04, 0.1, 0.14, 0.95) if s["id"] == soldier_sel else Color(0.02, 0.05, 0.08, 0.9), U.CYAN if s["id"] == soldier_sel else Color(1, 1, 1, 0.1), 6))
		lv.add_child(card)
		var row := U.hbox(card, 8)
		U.portrait(row, s.get("visual", ""), 44)
		var info := U.vbox(row, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		U.label(info, "%s  ·  %s" % [s["name"], c.rank_name(s)], 15, U.TEXT)
		var st := "prêt" if s["status"] == "ready" else "blessé · %s" % U.duration(int(s["wound_until"]) - c.minutes)
		U.label(info, "%s · %s · %s" % [s.get("role", ""), StratData.ITEMS[s["weapon"]]["name"], st], 12, U.GREEN if s["status"] == "ready" else U.AMBER)
		var pick := U.button(row, "Fiche", func(): soldier_sel = s["id"]; view.refresh_page(), "secondary", 0, 12)
		var dep := U.button(row, "À bord" if s.get("deploy", true) else "À quai", func(): view.cmd({"type": "deploy", "id": s["id"], "on": not s.get("deploy", true)}); view.refresh_page(), "green" if s.get("deploy", true) else "secondary", 84, 12)
		dep.disabled = s["status"] != "ready"
		pick.custom_minimum_size.x = 60
	var dead := c.soldiers.filter(func(s): return s["status"] == "dead")
	if not dead.is_empty():
		U.label(lv, "MÉMORIAL", 14, U.DIM)
		for s in dead:
			U.label(lv, "%s · %s · %d missions · tombé(e) le %s" % [s["name"], c.rank_name(s), s["missions"], String(s.get("died", "?")).split("  ")[0]], 12, U.DIM, true)
	var right := U.scroll(h)
	var v := U.vbox(right, 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := c.soldier(soldier_sel)
	if not s.is_empty():
		_soldier_sheet(v, s)
	U.label(v, "RECRUES DISPONIBLES  ·  %s chacune" % U.k(StratData.RECRUIT_COST), 15, U.CYAN)
	for i in c.recruits.size():
		var r: Dictionary = c.recruits[i]
		var row := U.hbox(v, 8)
		U.label(row, "%s · %s\nvisée %d · réac. %d · UT %d · PV %d" % [r["name"], r["role"], r["acc"], r["react"], r["tu"], r["hp"]], 13, U.TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		U.button(row, "Recruter", func(): view.cmd({"type": "recruit", "index": i}); view.refresh_page(), "secondary", 0, 12)

func _soldier_sheet(v: VBoxContainer, s: Dictionary) -> void:
	var c := _c()
	var rk := int(s["rank"])
	U.label(v, "%s  ·  %s" % [s["name"], c.rank_name(s)], 18, U.TEXT)
	var nxt := "grade maximal" if rk + 1 >= StratData.RANKS.size() else "%d / %d XP vers %s" % [s["xp"], StratData.RANKS[rk + 1]["xp"], StratData.RANKS[rk + 1]["name"]]
	U.label(v, "Visée %d · Réactions %d · UT %d · PV %d · %d missions · %d éliminations · %s" % [s["acc"], s["react"], s["tu"], s["hp"], s["missions"], s["kills"], nxt], 13, U.DIM, true)
	U.label(v, "ÉQUIPEMENT", 14, U.CYAN)
	_cycle(v, s, "weapon", "Arme", ["rifle", "pistol", "harpoon", "harpoon_ap", "cavitation"])
	_cycle(v, s, "armor", "Armure", ["combinaison", "scaphandre"])
	for slot in [["grenades", "Grenades", "grenade"], ["medkit", "Trousses", "medkit"]]:
		var row := U.hbox(v, 6)
		U.label(row, "%s : %d  (stock %d)" % [slot[1], s[slot[0]], c.items.get(slot[2], 0)], 13, U.TEXT).custom_minimum_size = Vector2(200, 0)
		U.button(row, "−", func(): view.cmd({"type": "equip", "id": s["id"], "slot": slot[0], "n": int(s[slot[0]]) - 1}); view.refresh_page(), "secondary", 44, 15)
		U.button(row, "+", func(): view.cmd({"type": "equip", "id": s["id"], "slot": slot[0], "n": int(s[slot[0]]) + 1}); view.refresh_page(), "secondary", 44, 15)
	if c.has_research("autopsie_spectre") or s.get("psi", false):
		var row := U.hbox(v, 6)
		U.label(row, "Casque psi : %s (stock %d)" % ["porté" if s.get("psi", false) else "non", c.items.get("casque_psi", 0)], 13, U.TEXT).custom_minimum_size = Vector2(200, 0)
		U.button(row, "Retirer" if s.get("psi", false) else "Équiper", func(): view.cmd({"type": "equip", "id": s["id"], "slot": "psi", "on": not s.get("psi", false)}); view.refresh_page(), "secondary", 0, 12)

func _cycle(v: VBoxContainer, s: Dictionary, slot: String, label: String, options: Array) -> void:
	var c := _c()
	var row := U.hbox(v, 6)
	var cur: String = s[slot]
	var extra := ""
	if slot == "armor":
		extra = "  (armure %d)" % int(StratData.ITEMS[cur].get("armor", 0))
	elif AbyssData.WEAPONS.has(cur):
		var w: Dictionary = AbyssData.WEAPONS[cur]
		extra = "  (%d dégâts, portée %d%s)" % [w["damage"], w["range"], ", perce %d" % w["pierce"] if w.has("pierce") else ""]
	U.label(row, "%s : %s%s" % [label, StratData.ITEMS[cur]["name"], extra], 13, U.TEXT)
	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 6)
	v.add_child(opts)
	for o in options:
		if o != cur and int(c.items.get(o, 0)) > 0:
			U.button(opts, StratData.ITEMS[o]["name"] + " (%d)" % c.items[o], func(): view.cmd({"type": "equip", "id": s["id"], "slot": slot, "item": o}); view.refresh_page(), "secondary", 0, 12)

# ---------- Recherche et fabrication ----------

func _research(h: HBoxContainer) -> void:
	var c := _c()
	var left := U.scroll(h)
	var lv := U.vbox(left, 6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	U.label(lv, "LABORATOIRE  ·  scientifiques libres %d / %d" % [int(c.staff["scientists"]) - c.busy_scientists(), c.staff["scientists"]], 15, U.CYAN)
	for id in StratData.RESEARCH:
		var r: Dictionary = StratData.RESEARCH[id]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", U.box(Color(0.02, 0.05, 0.08, 0.9), Color(1, 1, 1, 0.08), 6))
		lv.add_child(box)
		var bv := U.vbox(box, 2)
		if c.has_research(id):
			U.label(bv, "TERMINÉ  ·  " + r["name"], 13, U.GREEN)
			U.label(bv, r["desc"], 11, U.DIM, true)
		elif c.research.has(id):
			var p: Dictionary = c.research[id]
			var row := U.hbox(bv, 6)
			U.label(row, r["name"], 14, U.VIOLET).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			U.button(row, "−", func(): view.cmd({"type": "assign", "id": id, "sci": int(p["sci"]) - 1}); view.refresh_page(), "secondary", 40, 14)
			U.label(row, "%d sci." % p["sci"], 13, U.TEXT)
			U.button(row, "+", func(): view.cmd({"type": "assign", "id": id, "sci": int(p["sci"]) + 1}); view.refresh_page(), "secondary", 40, 14)
			var row2 := U.hbox(bv, 6)
			U.bar(row2, float(p["progress"]) / float(r["cost"]), U.VIOLET, 220, 6)
			var left_days := (float(r["cost"]) - float(p["progress"])) / maxf(0.01, float(p["sci"]))
			U.label(row2, "≈ %d j" % ceili(left_days) if int(p["sci"]) > 0 else "en attente", 12, U.DIM)
		else:
			var err := c.can_research(id)
			var row := U.hbox(bv, 6)
			U.label(row, r["name"], 14, U.TEXT if err == "" else U.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var b := U.button(row, "Lancer", func(): view.cmd({"type": "research", "id": id}); view.refresh_page(), "primary", 0, 13)
			b.disabled = err != ""
			U.label(bv, err if err != "" else "%d jours-scientifiques%s" % [r["cost"], "  ·  consomme : " + ", ".join(r["needs"].keys().map(func(k): return StratData.ITEMS[k]["name"])) if not r["needs"].is_empty() else ""], 11, U.AMBER if err != "" else U.DIM, true)
	var right := U.scroll(h)
	var rv := U.vbox(right, 6)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	U.label(rv, "ATELIER  ·  ingénieurs libres %d / %d" % [int(c.staff["engineers"]) - c.busy_engineers(), c.staff["engineers"]], 15, U.CYAN)
	for i in c.production.size():
		var p: Dictionary = c.production[i]
		var m: Dictionary = StratData.MANUFACTURE[p["item"]]
		var row := U.hbox(rv, 6)
		U.label(row, m["name"], 13, U.AMBER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		U.button(row, "−", func(): view.cmd({"type": "assign_eng", "index": i, "eng": int(p["eng"]) - 1}); view.refresh_page(), "secondary", 40, 14)
		U.label(row, "%d ing." % p["eng"], 13, U.TEXT)
		U.button(row, "+", func(): view.cmd({"type": "assign_eng", "index": i, "eng": int(p["eng"]) + 1}); view.refresh_page(), "secondary", 40, 14)
		var row2 := U.hbox(rv, 6)
		U.bar(row2, float(p["progress"]) / float(m["hours"]), U.AMBER, 200, 6)
		U.label(row2, "≈ %s" % U.duration(int((float(m["hours"]) - float(p["progress"])) / maxf(0.01, float(p["eng"])) * 60)) if int(p["eng"]) > 0 else "en attente", 12, U.DIM)
	for id in StratData.MANUFACTURE:
		var m: Dictionary = StratData.MANUFACTURE[id]
		if m["after"] != "" and not c.has_research(m["after"]):
			continue
		var err := c.can_manufacture(id)
		var row := U.hbox(rv, 6)
		var mats := ""
		for k in m["mats"]:
			mats += " + %d %s" % [m["mats"][k], StratData.ITEMS[k]["name"]]
		U.label(row, "%s\n%s · %d h-ing.%s · stock %d" % [m["name"], U.k(m["cost"]), m["hours"], mats, c.items.get(id, 0)], 12, U.TEXT if err == "" else U.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := U.button(row, "Fabriquer", func(): view.cmd({"type": "manufacture", "id": id}); view.refresh_page(), "secondary", 0, 12)
		b.disabled = err != ""
	var locked := StratData.MANUFACTURE.keys().filter(func(k): return StratData.MANUFACTURE[k]["after"] != "" and not c.has_research(StratData.MANUFACTURE[k]["after"])).size()
	if locked > 0:
		U.label(rv, "%d plans de fabrication attendent une recherche." % locked, 12, U.DIM, true)
