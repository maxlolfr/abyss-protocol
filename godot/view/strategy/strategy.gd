class_name AbyssStrategy
extends Node3D
## Écran stratégique : géoscape (globe, temps, contacts, missions, engins) et quatre onglets permanents
## (Monde, Base, Escouade, Recherche — GDD §11). Le moteur est AbyssCampaign ; cette vue n'écrit jamais
## dans son état autrement que par `apply` et `advance`.

const SPEEDS := [0, 5, 60, 360, 1440] # minutes de campagne par seconde réelle
const SPEED_TEXT := ["Pause", "5 min/s", "1 h/s", "6 h/s", "1 j/s"]
const U := preload("res://view/strategy/ui.gd")

var c: AbyssCampaign
var globe := AbyssGlobe.new()
var ui := CanvasLayer.new()
var marks := Control.new()
var top: HBoxContainer
var date_l: Label
var funds_l: Label
var threat_bar: Control
var threat_l: Label
var speed_btns: Array[Button] = []
var tab_btns := {}
var side: PanelContainer
var page: Control # onglet plein écran (Base, Escouade, Recherche)
var toasts: VBoxContainer
var modal: Control
var speed := 0
var tab := "monde"
var sel := {} # {"kind": "base"|"craft"|"contact"|"site"|"point", "id": ..., "pos": ...}
var _acc := 0.0
var _markers := {}
var _dirty := true
var _day := -1
var panels: StratPanels
var title_shown := false
var show_title := true # désactivé par les captures

func _ready() -> void:
	add_child(globe)
	add_child(ui)
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(marks)
	panels = StratPanels.new(self)
	if OS.has_feature("web") and (_query_has("map") or _query_has("autoplay")):
		AbyssSession.skirmish = true # anciennes adresses de test : mission seule directe
		get_tree().change_scene_to_file.call_deferred(AbyssSession.BATTLE_SCENE)
		return
	c = AbyssSession.load_campaign()
	if not AbyssSession.result.is_empty() and c and not AbyssSession.mission.is_empty():
		_return_from_battle()
	elif show_title:
		_title()
	else:
		if c == null:
			c = AbyssCampaign.new("capture")
		_build_ui()

func _query_has(key: String) -> bool:
	return bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('%s')" % key))

# ---------- titre ----------

func _title() -> void:
	title_shown = true
	var root := Control.new()
	root.name = "Title"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/screens/title.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.position = Vector2(48, -300)
	root.add_child(v)
	U.label(v, "ABYSS PROTOCOL", 58, U.TEXT)
	U.label(v, "PROGRAMME NEPTUNE  ·  CAMPAGNE", 18, U.CYAN)
	if c and c.outcome == "ongoing":
		U.button(v, "Continuer la campagne  ·  " + c.date_text(), func(): root.queue_free(); _build_ui(), "primary", 340, 18)
		U.button(v, "Nouvelle campagne", func(): _confirm_new(root), "secondary", 340)
	else:
		U.button(v, "Nouvelle campagne", func(): root.queue_free(); _new_campaign(), "primary", 340, 18)
	U.button(v, "Mission Némésis seule", func():
		AbyssSession.skirmish = true
		AbyssSession.mission = {}
		get_tree().change_scene_to_file(AbyssSession.BATTLE_SCENE), "secondary", 340)

func _confirm_new(root: Control) -> void:
	_modal("Nouvelle campagne", "La campagne en cours sera effacée.", [["Effacer et recommencer", func(): root.queue_free(); _new_campaign(), "red"], ["Annuler", func(): pass, "secondary"]])

func _new_campaign() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	c = AbyssCampaign.new("neptune-%d" % (int(Time.get_unix_time_from_system()) % 1000000))
	AbyssSession.save_campaign(c)
	_build_ui()
	_modal("Programme Neptune", "Mars 2031. Des installations sous-marines disparaissent sans un appel. Le conseil international vous confie Neptune, une base sur le plateau des Açores, deux engins et quatre plongeurs.\n\nPremière urgence : la station Némésis ne répond plus. Touchez-la sur le globe, puis envoyez le Triton.\n\nGardez la menace basse, la confiance des régions haute, et trouvez d'où vient le signal.", [["Prendre le commandement", func(): _select({"kind": "site", "id": c.site_of_kind("nemesis")["id"]}), "primary"]])

# ---------- interface ----------

func _build_ui() -> void:
	globe.set_time(c)
	globe.view = StratData.BASE_POS + Vector2(-8, -10)
	globe._place_cam()
	var tb := PanelContainer.new()
	tb.add_theme_stylebox_override("panel", U.box(Color(0.015, 0.035, 0.06, 0.88), Color(0.22, 0.85, 0.94, 0.3), 6))
	tb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tb.offset_left = 8; tb.offset_right = -8; tb.offset_top = 6
	ui.add_child(tb)
	top = U.hbox(tb, 10)
	date_l = U.label(top, "", 17, U.TEXT)
	date_l.custom_minimum_size = Vector2(170, 0)
	var sp := U.hbox(top, 2)
	for i in SPEEDS.size():
		var b := U.button(sp, ["II", "▸", "▸▸", "▸▸▸", "▸▸▸▸"][i], _set_speed.bind(i), "secondary", 46, 15)
		speed_btns.append(b)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	funds_l = U.label(top, "", 17, U.GREEN)
	var tv := U.vbox(top, 2)
	threat_l = U.label(tv, "", 12, U.AMBER)
	threat_bar = U.bar(tv, 0.0, U.RED, 110, 5)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tabs.position = Vector2(-300, -54)
	tabs.custom_minimum_size = Vector2(600, 0)
	ui.add_child(tabs)
	for t in [["monde", "Monde"], ["base", "Base"], ["escouade", "Escouade"], ["recherche", "Recherche"]]:
		var b := U.button(tabs, t[1], _set_tab.bind(t[0]), "secondary", 146, 16)
		tab_btns[t[0]] = b
	side = PanelContainer.new()
	side.add_theme_stylebox_override("panel", AbyssHud.frame())
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -300; side.offset_right = -8; side.offset_top = 64; side.offset_bottom = -62
	ui.add_child(side)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toasts.position = Vector2(12, 64)
	toasts.custom_minimum_size = Vector2(380, 0)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toasts)
	_set_tab("monde")
	_set_speed(0)
	_refresh()

func _set_speed(i: int) -> void:
	speed = i
	for j in speed_btns.size():
		var on := j == i
		speed_btns[j].add_theme_stylebox_override("normal", AbyssHud.tex_box("btn_orange" if on else "btn_secondary", Vector4(14, 12, 14, 12), Vector4(12, 6, 12, 6)))
		speed_btns[j].add_theme_color_override("font_color", U.AMBER if on else U.TEXT)

func _set_tab(t: String) -> void:
	tab = t
	for k in tab_btns:
		var on: bool = k == t
		tab_btns[k].add_theme_stylebox_override("normal", AbyssHud.tex_box("btn_primary" if on else "btn_secondary", Vector4(14, 12, 14, 12), Vector4(12, 6, 12, 6)))
		tab_btns[k].add_theme_color_override("font_color", U.CYAN if on else U.TEXT)
	if page:
		page.queue_free()
		page = null
	side.visible = t == "monde"
	marks.visible = t == "monde"
	if t != "monde":
		_set_speed(0)
		page = panels.build(t)
		ui.add_child(page)
		ui.move_child(page, toasts.get_index())
	_dirty = true

## Reconstruit l'onglet ouvert après une commande (les panneaux lisent l'état de la campagne).
func refresh_page() -> void:
	if tab != "monde":
		var keep := tab
		_set_tab(keep)
	_refresh()

func cmd(d: Dictionary) -> void:
	var ev := c.apply(d)
	_events(ev)
	AbyssSession.save_campaign(c)
	_dirty = true
	_refresh()

# ---------- boucle ----------

func _process(delta: float) -> void:
	if c == null or top == null:
		return
	if speed > 0 and modal == null and c.pending.is_empty() and c.outcome == "ongoing":
		_acc += SPEEDS[speed] * delta
		var n := int(_acc)
		if n >= 1:
			_acc -= n
			var ev := c.advance(n)
			_events(ev)
			_dirty = true
			if c.minutes / 1440 != _day:
				_day = c.minutes / 1440
				AbyssSession.save_campaign(c)
	if not c.pending.is_empty() and modal == null:
		_pending_modal()
	if _dirty:
		_dirty = false
		_refresh()
	_update_markers()

func _refresh() -> void:
	if top == null:
		return
	date_l.text = c.date_text()
	funds_l.text = U.k(c.funds)
	threat_l.text = "MENACE %d %%" % int(c.threat)
	(threat_bar.get_child(0) as ColorRect).size.x = 110.0 * c.threat / 100.0
	globe.set_time(c)
	_draw_lines()
	if tab == "monde":
		_side_panel()

func _events(ev: Array) -> void:
	for e in ev:
		var t: String = e.get("t", "")
		if t == "error":
			toast(e["text"], U.RED)
		elif e.get("critical", false):
			_set_speed(0)
			match t:
				"report":
					_modal("Rapport mensuel du conseil", e["text"], [["Compris", func(): pass, "primary"]])
				"research":
					_modal("Recherche terminée", e["text"], [["Voir la recherche", func(): _set_tab("recherche"), "primary"], ["Plus tard", func(): pass, "secondary"]])
				"contact":
					toast(e["text"], U.AMBER)
					var k := c.contact(e["id"])
					if not k.is_empty():
						globe.focus(k["pos"])
						_select({"kind": "contact", "id": k["id"]})
				"site":
					toast(e["text"], U.AMBER)
					if e.has("id"):
						var s := c.site(e["id"])
						globe.focus(s["pos"])
						_select({"kind": "site", "id": s["id"]})
				"campaign_end":
					_end_screen()
				"intercept", "assault":
					pass # fenêtre de décision ouverte par _process
				_:
					toast(e["text"], U.AMBER)
		elif t == "intercept_result":
			_intercept_result(e)
		elif t in ["craft", "room", "made", "alien", "contact_lost", "expired"]:
			toast(e["text"], U.CYAN if t != "alien" else U.AMBER)
		elif t == "mission_result":
			pass

func toast(text: String, col := U.CYAN) -> void:
	if toasts == null:
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", U.box(Color(0.02, 0.05, 0.08, 0.88), Color(col, 0.6), 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := U.label(p, text, 14, col, true)
	l.custom_minimum_size = Vector2(360, 0)
	toasts.add_child(p)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

# ---------- globe : tracés et marqueurs ----------

func _draw_lines() -> void:
	globe.begin_lines()
	globe.circle(StratData.BASE_POS, c.sonar_range(), Color(0.22, 0.85, 0.94, 0.55))
	for cr in c.crafts:
		if cr["state"] in ["outbound", "patrol", "returning", "site"]:
			globe.circle(cr["pos"], float(StratData.CRAFTS[cr["type"]]["sonar"]), Color(0.22, 0.85, 0.94, 0.25), 40)
			var tp = c._target_pos(cr) if cr["state"] != "returning" else StratData.BASE_POS
			if tp != null:
				globe.arc(cr["pos"], tp, Color(0.4, 0.95, 1.0, 0.8), true)
	for k in c.contacts:
		if k["detected"]:
			globe.circle(k["pos"], float(k["error"]), Color(1.0, 0.7, 0.28, 0.6), 48)
	for s in c.sites:
		if s.get("deep", false):
			globe.circle(s["pos"], 300, Color(0.69, 0.42, 1.0, 0.6), 48)
	if sel.get("kind", "") == "point":
		globe.circle(sel["pos"], 120, Color(1, 1, 1, 0.6), 24)
	globe.end_lines()

func _marker_list() -> Array:
	var out := [{"key": "base", "kind": "base", "id": "base", "pos": StratData.BASE_POS, "text": "NEPTUNE", "col": U.CYAN, "shape": "diamond"}]
	for cr in c.crafts:
		if cr["state"] != "base" and cr["state"] != "repair" and cr["state"] != "refuel":
			out.append({"key": cr["id"], "kind": "craft", "id": cr["id"], "pos": cr["pos"], "text": cr["name"], "col": Color("8fe8ff"), "shape": "tri"})
	for k in c.contacts:
		if k["detected"]:
			out.append({"key": k["id"], "kind": "contact", "id": k["id"], "pos": k["pos"], "text": StratData.ALIEN_SUBS[k["sub"]]["name"], "col": U.AMBER, "shape": "ring"})
	for s in c.sites:
		var left := ""
		if int(s["expires_at"]) > 0:
			left = "  " + U.duration(int(s["expires_at"]) - c.minutes)
		var col: Color = U.VIOLET if s["kind"] == "nid" else (U.RED if s["kind"] == "port" else U.AMBER)
		out.append({"key": s["id"], "kind": "site", "id": s["id"], "pos": s["pos"], "text": s["name"] + left, "col": col, "shape": "square"})
	return out

func _update_markers() -> void:
	if not marks.visible:
		return
	var seen := {}
	for m in _marker_list():
		seen[m["key"]] = true
		var mk: StratMarker = _markers.get(m["key"])
		if mk == null:
			mk = StratMarker.new()
			mk.pressed_cb = _select.bind({"kind": m["kind"], "id": m["id"]})
			marks.add_child(mk)
			_markers[m["key"]] = mk
		mk.setup(m["text"], m["col"], m["shape"], sel.get("id", "") == m["id"])
		var sp = globe.project(m["pos"])
		mk.visible = sp != null
		if sp != null:
			mk.position = (sp as Vector2) - Vector2(14, 14)
	for key in _markers.keys():
		if not seen.has(key):
			_markers[key].queue_free()
			_markers.erase(key)

func _unhandled_input(e: InputEvent) -> void:
	if c == null or top == null or modal != null or tab != "monde":
		return
	globe.handle_input(e)
	var released: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed # toucher émulé en souris
	if released and not globe.was_drag():
		var p = globe.pick(e.position)
		if p != null:
			_select({"kind": "point", "id": "point", "pos": p})
		else:
			_select({})

func _select(s: Dictionary) -> void:
	sel = s
	_dirty = true

# ---------- panneau latéral (onglet Monde) ----------

func _side_panel() -> void:
	for ch in side.get_children():
		ch.queue_free()
	var v := U.vbox(side, 6)
	match sel.get("kind", ""):
		"base":
			_side_base(v)
		"craft":
			var cr := c.craft(sel["id"])
			if cr.is_empty():
				_side_journal(v)
			else:
				_side_craft(v, cr)
		"contact":
			var k := c.contact(sel["id"])
			if k.is_empty() or not k["detected"]:
				_side_journal(v)
			else:
				_side_contact(v, k)
		"site":
			var s := c.site(sel["id"])
			if s.is_empty():
				_side_journal(v)
			else:
				_side_site(v, s)
		"point":
			_side_point(v, sel["pos"])
		_:
			_side_journal(v)

func _side_journal(v: VBoxContainer) -> void:
	U.label(v, "JOURNAL DES OPÉRATIONS", 15, U.CYAN)
	U.label(v, "Touchez Neptune, un contact ou une mission sur le globe.", 12, U.DIM, true)
	var sc := U.scroll(v)
	var lv := U.vbox(sc, 6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := 0
	for i in range(c.journal.size() - 1, -1, -1):
		var e: Dictionary = c.journal[i]
		var col := U.AMBER if e["kind"] in ["alien", "contact", "mission"] else (U.VIOLET if e["kind"] == "research" else U.DIM)
		U.label(lv, e["date"], 11, U.DIM)
		var l := U.label(lv, e["text"], 13, col if e["important"] else U.TEXT, true)
		l.custom_minimum_size = Vector2(250, 0)
		n += 1
		if n >= 14:
			break

func _side_base(v: VBoxContainer) -> void:
	U.label(v, "BASE NEPTUNE", 17, U.CYAN)
	U.label(v, "Plateau des Açores  ·  sonar %d km" % int(c.sonar_range()), 12, U.DIM)
	for cr in c.crafts:
		var h := U.hbox(v, 6)
		var st: String = {"base": "à quai", "outbound": "en route", "patrol": "en patrouille", "returning": "retour", "site": "sur zone", "repair": "réparation", "refuel": "ravitaillement"}[cr["state"]]
		U.label(h, "%s  ·  %s" % [cr["name"], st], 14, U.TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cr["state"] in ["outbound", "patrol", "site"]:
			U.button(h, "Rappeler", func(): cmd({"type": "recall", "craft": cr["id"]}), "secondary", 0, 13)
		var h2 := U.hbox(v, 6)
		U.label(h2, "coque", 11, U.DIM)
		U.bar(h2, float(cr["hull"]) / float(cr["max_hull"]), U.GREEN, 80, 5)
		U.label(h2, "carb.", 11, U.DIM)
		U.bar(h2, float(cr["fuel"]) / float(StratData.CRAFTS[cr["type"]]["fuel"]), U.CYAN, 80, 5)
		if cr.get("deep", false):
			U.label(v, "  coque haute pression installée", 11, U.VIOLET)
	U.label(v, "Escouade prête : %d / %d places" % [c.squad().size(), StratData.CRAFTS["triton"]["seats"]], 13, U.TEXT)
	U.button(v, "Gérer la base", func(): _set_tab("base"), "secondary")

func _side_craft(v: VBoxContainer, cr: Dictionary) -> void:
	U.label(v, cr["name"].to_upper(), 17, U.CYAN)
	U.label(v, StratData.CRAFTS[cr["type"]]["role"], 12, U.DIM)
	U.label(v, "Carburant : %d h  ·  coque %d/%d" % [int(cr["fuel"]), cr["hull"], cr["max_hull"]], 13, U.TEXT)
	U.button(v, "Rappeler à Neptune", func(): cmd({"type": "recall", "craft": cr["id"]}), "secondary")

func _side_contact(v: VBoxContainer, k: Dictionary) -> void:
	var a: Dictionary = StratData.ALIEN_SUBS[k["sub"]]
	U.label(v, "CONTACT SONAR", 13, U.AMBER)
	U.label(v, a["name"], 19, U.TEXT)
	U.label(v, "Activité : %s\nZone : %s\nPosition à ±%d km" % [StratData.ALIEN_OPS[k["op"]]["name"].to_lower(), StratData.REGIONS[c.region_of(k["pos"])]["name"], int(k["error"])], 13, U.DIM, true)
	var bar := c._craft_of_type("barracuda")
	if bar.is_empty():
		return
	if bar["state"] in ["repair", "refuel"]:
		U.label(v, "Barracuda indisponible (%s)." % ("réparation" if bar["state"] == "repair" else "ravitaillement"), 13, U.RED, true)
		return
	var odds := c.intercept_odds(bar["id"], k["id"])
	var eta := AbyssGeo.dist_km(bar["pos"], k["pos"]) / float(bar["speed"])
	U.label(v, "Barracuda : chances estimées %d %%\nTrajet ≈ %s  ·  torpilles %d dégâts" % [odds, U.duration(int(eta * 60)), StratData.CRAFTS["barracuda"]["weapon"]["damage"]], 13, U.GREEN if odds >= 60 else U.AMBER, true)
	if c.trench_at(k["pos"]) != "":
		U.label(v, "Au-dessus d'une fosse : une épave y coulerait hors de portée du Triton standard.", 12, U.VIOLET, true)
	U.button(v, "INTERCEPTER", func(): cmd({"type": "send", "craft": bar["id"], "contact": k["id"]}), "orange")

func _side_site(v: VBoxContainer, s: Dictionary) -> void:
	var m: Dictionary = StratData.MISSIONS[s["kind"]]
	U.label(v, "MISSION", 13, U.AMBER)
	U.label(v, s["name"], 19, U.TEXT, true)
	U.label(v, m["brief"], 13, U.DIM, true)
	if int(s["expires_at"]) > 0:
		U.label(v, "Expire dans %s" % U.duration(int(s["expires_at"]) - c.minutes), 13, U.RED)
	U.label(v, "Signatures : ≈ %d" % s["aliens"].size(), 13, U.TEXT)
	if s.get("deep", false):
		U.label(v, "Zone abyssale : coque haute pression requise.", 12, U.VIOLET, true)
	var tri := c._craft_of_type("triton")
	var squad := c.squad()
	U.label(v, "Escouade : " + (", ".join(squad.map(func(x): return x["name"])) if not squad.is_empty() else "aucun soldat prêt"), 12, U.TEXT, true)
	if tri["target"].get("site", "") == s["id"]:
		U.label(v, "Le Triton fait route.", 13, U.CYAN)
		return
	var eta := AbyssGeo.dist_km(tri["pos"], s["pos"]) / float(tri["speed"])
	U.label(v, "Triton : trajet ≈ %s" % U.duration(int(eta * 60)), 13, U.CYAN)
	var b := U.button(v, "ENVOYER LE TRITON", func(): cmd({"type": "send", "craft": tri["id"], "site": s["id"]}), "orange")
	b.disabled = tri["state"] != "base" or squad.is_empty() or (s.get("deep", false) and not tri.get("deep", false))

func _side_point(v: VBoxContainer, p: Vector2) -> void:
	U.label(v, "%.0f° %s  %.0f° %s" % [absf(p.x), "N" if p.x >= 0 else "S", absf(p.y), "E" if p.y >= 0 else "O"], 17, U.TEXT)
	U.label(v, StratData.REGIONS[c.region_of(p)]["name"] + (("  ·  " + StratData.TRENCHES[c.trench_at(p)]["name"]) if c.trench_at(p) != "" else ""), 13, U.DIM, true)
	var bar := c._craft_of_type("barracuda")
	U.label(v, "Une patrouille étend la couverture sonar (%d km autour de l'engin)." % int(StratData.CRAFTS["barracuda"]["sonar"]), 12, U.DIM, true)
	var b := U.button(v, "Patrouiller ici (Barracuda)", func(): cmd({"type": "send", "craft": bar["id"], "pos": p}), "secondary")
	b.disabled = bar.is_empty() or bar["state"] in ["repair", "refuel"]
	_side_regions(v)

func _side_regions(v: VBoxContainer) -> void:
	U.label(v, "CONFIANCE DES RÉGIONS", 13, U.CYAN)
	for id in StratData.REGIONS:
		var r: Dictionary = c.regions[id]
		var h := U.hbox(v, 6)
		var l := U.label(h, StratData.REGIONS[id]["name"], 12, U.RED if r["withdrawn"] else U.TEXT)
		l.custom_minimum_size = Vector2(120, 0)
		U.bar(h, float(r["trust"]) / 100.0, U.GREEN if r["trust"] >= 40 else (U.AMBER if r["trust"] >= 20 else U.RED), 100, 5)

# ---------- décisions ----------

func _pending_modal() -> void:
	var p := c.pending
	if p["type"] == "intercept":
		var k := c.contact(p["contact"])
		var cr := c.craft(p["craft"])
		var a: Dictionary = StratData.ALIEN_SUBS[k["sub"]]
		_modal("Interception", "%s au contact d'un %s.\nCoque alien estimée : %d  ·  armement %d par passe.\nBarracuda : coque %d/%d, torpilles %d (précision %d %%).\n\nChances estimées : %d %%" % [
			cr["name"], a["name"], int(k["hull"]), a["damage"], cr["hull"], cr["max_hull"], StratData.CRAFTS["barracuda"]["weapon"]["damage"], StratData.CRAFTS["barracuda"]["weapon"]["acc"], p["odds"]],
			[["ENGAGER", func(): cmd({"type": "engage"}), "orange"], ["Rompre", func(): cmd({"type": "disengage"}), "secondary"]])
	elif p["type"] == "assault":
		var s := c.site(p["site"])
		var names: Array = c.squad().map(func(x): return "%s (%s)" % [x["name"], c.rank_name(x)])
		_modal(s["name"], "%s\n\nEscouade : %s" % [StratData.MISSIONS[s["kind"]]["brief"], ", ".join(names)],
			[["LANCER L'ASSAUT", _launch.bind(s["id"]), "orange"], ["Annuler (retour)", func(): cmd({"type": "assault_cancel"}), "secondary"]])

func _intercept_result(e: Dictionary) -> void:
	var lines := []
	var i := 1
	for r in e.get("rounds", []):
		lines.append("Passe %d : torpille %s  ·  riposte %s" % [i, "TOUCHÉ" if r[0] else "manquée", "touché" if r[1] else "—"])
		i += 1
	_modal("Rapport d'interception", e["text"] + ("\n\n" + "\n".join(lines) if not lines.is_empty() else ""), [["Compris", func(): pass, "primary"]])

func _launch(site_id: String) -> void:
	var cfg := c.mission_config(site_id)
	AbyssSession.save_campaign(c)
	AbyssSession.mission = cfg
	AbyssSession.result = {}
	AbyssSession.skirmish = false
	get_tree().change_scene_to_file(AbyssSession.BATTLE_SCENE)

func _return_from_battle() -> void:
	var site_id: String = AbyssSession.mission["site"]
	var ev := c.apply_result(site_id, AbyssSession.result)
	AbyssSession.result = {}
	AbyssSession.mission = {}
	AbyssSession.save_campaign(c)
	_build_ui()
	for e in ev:
		if e["t"] == "mission_result":
			_modal("Débriefing", e["text"], [["Retour au géoscape", func(): _events(ev.filter(func(x): return x["t"] != "mission_result")), "primary"]])

func _end_screen() -> void:
	var win := c.outcome == "victory"
	var st: Dictionary = c.stats
	_modal("VICTOIRE" if win else "CAMPAGNE PERDUE", "%s\n\nMissions : %d (%d réussies)  ·  aliens neutralisés : %d\nInterceptions : %d  ·  soldats tombés : %d\nScore : %d" % [
		c.reason, st["missions"], st["won"], st["kills"], st["intercepts"], st["dead"], c.score],
		[["Nouvelle campagne", func(): _new_campaign_from_end(), "primary"]])

func _new_campaign_from_end() -> void:
	AbyssSession.clear_campaign()
	get_tree().reload_current_scene()

func _modal(title: String, text: String, buttons: Array) -> void:
	if modal:
		modal.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(root)
	modal = root
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AbyssHud.frame())
	p.custom_minimum_size = Vector2(560, 0)
	root.add_child(p)
	var v := U.vbox(p, 10)
	U.label(v, title.to_upper(), 22, U.CYAN)
	var l := U.label(v, text, 15, U.TEXT, true)
	l.custom_minimum_size = Vector2(520, 0)
	var h := U.hbox(v, 10)
	for b in buttons:
		var cb: Callable = b[1]
		U.button(h, b[0], func():
			root.queue_free()
			if modal == root:
				modal = null
			cb.call(), b[2], 180, 16)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	await get_tree().process_frame
	if is_instance_valid(p):
		p.reset_size()
		p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
