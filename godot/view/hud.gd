class_name AbyssHud
extends CanvasLayer
## Interface tactile compacte (version 2) : roster étroit, actions contextuelles, aperçu sur une ligne,
## objectifs en bandeau, réglages dans un panneau repliable. Aucune modale sauf le récapitulatif final.

signal action(mode: String)
signal confirm
signal cancel
signal select_unit(id: String)
signal rotate_cam(dir: int)
signal setting(key: String, value: Variant)
signal restart

const CYAN := Color("39d9ef")
const AMBER := Color("ffb547")
const RED := Color("e5484d")
const GREEN := Color("52c99a")
const TEXT := Color("e4edf5")
const PANEL := Color(0.027, 0.05, 0.086, 0.78)

var margin := 10.0
var objectives: Label
var info: Label
var preview: Label
var preview_box: PanelContainer
var confirm_btn: Button
var cancel_btn: Button
var toast: Label
var fps_lbl: Label
var actions := {}
var squad := {}
var bars := {} # id -> [barre PV, barre UT]
var menu: PanelContainer
var end_panel: PanelContainer
var _toast_t := 0.0
var _settings := {"sound": true, "speed": 1.0, "shadows": true, "cine": true, "fps": true, "quality": "haute"}
var quality_btn: Button
var badges := {} # id -> {nom d'icône: TextureRect}
var foe_panel: PanelContainer
var _foe_widgets := {}

## Rôles affichés sur les cartes de l'escouade.
const ROLES := {"s1": "Fusilier", "s2": "Lourd", "s3": "Précision", "s4": "Médecin"}
## Fiches des hostiles (bestiaire) : portrait, description courte.
const FOES := {
	"nereide": ["res://assets/ui/portraits/nereide.jpg", "Éclaireuse amphibie, rapide. Cherche le flanc et nage dans les bassins."],
	"spectre": ["res://assets/ui/portraits/spectre.jpg", "Entité psionique en lévitation. Son onde ignore les couverts et draine les UT."],
	"carapace": ["res://assets/units/sprites/carapace_q34.png", "Crustacé lourd très blindé. Jet d'acide à courte portée : gardez vos distances."],
}

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# marges de sécurité (encoche iPhone) lorsqu'elles sont connues
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x > 0 and scr.x > 0:
		margin = maxf(10.0, float(safe.position.x) * 960.0 / scr.x)
	# haut gauche : objectifs + tour (bandeau compact)
	var top := _panel(root)
	top.position = Vector2(margin, 8)
	objectives = _label(top, "", 13, TEXT)
	# gauche : escouade en colonne étroite
	var sq := VBoxContainer.new()
	sq.position = Vector2(margin, 58)
	sq.add_theme_constant_override("separation", 4)
	root.add_child(sq)
	for id in ["s1", "s2", "s3", "s4"]:
		var b := _button(sq, id, func(): select_unit.emit(id), 13)
		b.custom_minimum_size = Vector2(166, 74)
		b.add_theme_font_size_override("font_size", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# portrait tiré des planches de Max + barres PV (vert) et UT (cyan)
		b.icon = load("res://assets/ui/portraits/%s.jpg" % id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_constant_override("h_separation", 8)
		var pair := []
		for k in 2:
			var bg := ColorRect.new()
			bg.color = Color(0, 0, 0, 0.55)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.position = Vector2(60, 61 + k * 6)
			bg.size = Vector2(90, 4)
			b.add_child(bg)
			var fg := ColorRect.new()
			fg.color = GREEN if k == 0 else CYAN
			fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fg.size = Vector2(90, 4)
			bg.add_child(fg)
			pair.append(fg)
		bars[id] = pair
		squad[id] = b
		# badges d'état en haut à droite : artefact, genou, veille, saignement
		var bx := HBoxContainer.new()
		bx.position = Vector2(96, 5)
		bx.custom_minimum_size = Vector2(64, 16)
		bx.alignment = BoxContainer.ALIGNMENT_END
		bx.add_theme_constant_override("separation", 2)
		bx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bx)
		badges[id] = {}
		for ic in [["interact", CYAN], ["kneel", TEXT], ["watch", AMBER], ["heal", RED]]:
			var t := TextureRect.new()
			t.texture = load("res://assets/ui/icons/%s.png" % ic[0])
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(15, 15)
			t.modulate = ic[1]
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bx.add_child(t)
			badges[id][ic[0]] = t
	# haut droite : caméra + menu + i/s
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-250 - margin, 8)
	tr.custom_minimum_size = Vector2(250, 0)
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 4)
	root.add_child(tr)
	fps_lbl = _label(tr, "", 12, Color(0.6, 0.75, 0.8))
	_button(tr, "<", func(): rotate_cam.emit(-1)).custom_minimum_size = Vector2(46, 44)
	_button(tr, ">", func(): rotate_cam.emit(1)).custom_minimum_size = Vector2(46, 44)
	_button(tr, "Menu", func(): menu.visible = not menu.visible).custom_minimum_size = Vector2(64, 44)
	# panneau de réglages (latéral, non modal)
	menu = PanelContainer.new()
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.position = Vector2(-230 - margin, 58)
	menu.custom_minimum_size = Vector2(230, 0)
	menu.add_theme_stylebox_override("panel", frame())
	menu.visible = false
	root.add_child(menu)
	var mv := VBoxContainer.new()
	menu.add_child(mv)
	for s in [["sound", "Son et musique"], ["shadows", "Ombres dynamiques"], ["cine", "Caméra cinématique"], ["fps", "Afficher les i/s"]]:
		var c := CheckButton.new()
		c.text = s[1]
		c.button_pressed = _settings[s[0]]
		c.add_theme_font_size_override("font_size", 14)
		c.toggled.connect(func(on): _settings[s[0]] = on; setting.emit(s[0], on))
		mv.add_child(c)
	for vs in [["vol_Music", "Musique"], ["vol_SFX", "Effets"], ["vol_Ambience", "Ambiance"]]:
		var row := HBoxContainer.new()
		mv.add_child(row)
		var vl := _label(row, vs[1], 15, TEXT)
		vl.custom_minimum_size = Vector2(78, 0)
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05; sl.value = 1.0
		sl.custom_minimum_size = Vector2(130, 30)
		sl.value_changed.connect(func(val): setting.emit(vs[0], val))
		row.add_child(sl)
	quality_btn = _button(mv, "Qualité : haute", func(): pass, 14)
	quality_btn.pressed.connect(func():
		var q: String = {"haute": "moyenne", "moyenne": "basse", "basse": "allégée", "allégée": "haute"}[_settings["quality"]]
		set_quality(q)
		setting.emit("quality", q))
	var sp := _button(mv, "Vitesse ennemie : x1", func(): pass, 14)
	sp.pressed.connect(func():
		_settings["speed"] = {1.0: 2.0, 2.0: 4.0, 4.0: 1.0}[_settings["speed"]]
		sp.text = "Vitesse ennemie : x%d" % int(_settings["speed"])
		setting.emit("speed", _settings["speed"]))
	_button(mv, "Nouvelle mission", func(): restart.emit(), 14)
	# bas : aperçu sur une ligne + actions contextuelles
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -118
	bottom.offset_bottom = -6
	bottom.offset_left = 130 + margin
	bottom.offset_right = -margin
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_theme_constant_override("separation", 4)
	bottom.add_child(prow)
	preview_box = PanelContainer.new()
	preview_box.add_theme_stylebox_override("panel", _box(PANEL, Color(0.22, 0.85, 0.94, 0.45)))
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(preview_box)
	preview = _label(preview_box, "", 13, TEXT)
	confirm_btn = _button(prow, "Confirmer", func(): confirm.emit(), 14)
	confirm_btn.custom_minimum_size = Vector2(96, 40)
	cancel_btn = _button(prow, "X", func(): cancel.emit(), 14)
	cancel_btn.custom_minimum_size = Vector2(44, 40)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 4)
	bottom.add_child(arow)
	for m in ["snap", "aimed", "throw", "breach", "heal", "reload", "kneel", "watch", "interact", "evac", "end"]:
		var b := _button(arow, m, func(): action.emit(m), 12)
		b.custom_minimum_size = Vector2(84, 70)
		var ip := "res://assets/ui/icons/%s.png" % m # icônes UI-112 (planche de Max)
		if ResourceLoader.exists(ip):
			b.icon = load(ip)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 34)
		actions[m] = b
	actions["end"].custom_minimum_size = Vector2(92, 70)
	_build_foe_panel(root)
	info = _label(root, "", 12, Color(0.75, 0.88, 0.94))
	info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(margin, -22)
	# bandeau d'événements (non bloquant)
	toast = _label(root, "", 17, AMBER)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-240, 58)
	toast.custom_minimum_size = Vector2(480, 0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	# récapitulatif final (seule fenêtre)
	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-210, -100)
	end_panel.custom_minimum_size = Vector2(420, 190)
	end_panel.add_theme_stylebox_override("panel", frame())
	end_panel.visible = false
	root.add_child(end_panel)

func _process(delta: float) -> void:
	fps_lbl.text = ("%d i/s" % Engine.get_frames_per_second()) if _settings["fps"] else ""
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t, 0.0, 1.0)

## Habillage de l'interface (phase 2) : cadres et boutons découpés de la planche UI-114 HD de Max,
## police Rajdhani (licence OFL), palette anthracite / cyan désaturé / orange tactique / rouge d'alerte.
const KIT := "res://assets/ui/kit/%s.png"
static var _sb := {}

static func tex_box(name: String, m := Vector4(14, 12, 14, 12), pad := Vector4(10, 6, 10, 6)) -> StyleBoxTexture:
	var key := name + str(m) + str(pad)
	if _sb.has(key):
		return _sb[key]
	var sb := StyleBoxTexture.new()
	sb.texture = load(KIT % name)
	sb.texture_margin_left = m.x; sb.texture_margin_top = m.y; sb.texture_margin_right = m.z; sb.texture_margin_bottom = m.w
	sb.content_margin_left = pad.x; sb.content_margin_top = pad.y; sb.content_margin_right = pad.z; sb.content_margin_bottom = pad.w
	_sb[key] = sb
	return sb

static func frame() -> StyleBoxTexture:
	return tex_box("panel2", Vector4(34, 30, 34, 30), Vector4(14, 10, 14, 10))

func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL, Color(0.22, 0.85, 0.94, 0.3)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 7; s.content_margin_right = 7; s.content_margin_top = 4; s.content_margin_bottom = 4
	return s

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable, size := 13) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_stylebox_override("normal", tex_box("btn_secondary"))
	b.add_theme_stylebox_override("hover", tex_box("btn_primary"))
	b.add_theme_stylebox_override("pressed", tex_box("btn_primary"))
	b.add_theme_stylebox_override("disabled", tex_box("btn_disabled"))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 3)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func flash(text: String, color := AMBER) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	_toast_t = 2.2
	toast.modulate.a = 1.0

func set_quality(q: String) -> void:
	_settings["quality"] = q
	if quality_btn:
		quality_btn.text = "Qualité : %s" % q

func set_preview(text: String, can_confirm: bool) -> void:
	if text == "":
		hide_foe()
	preview.text = text
	preview_box.visible = text != ""
	confirm_btn.visible = can_confirm
	cancel_btn.visible = can_confirm

## Met à jour l'escouade, les objectifs et les actions utiles pour le soldat actif.
func refresh(b: AbyssBattle, sel: AbyssUnit, mode: String, busy: bool) -> void:
	objectives.text = "Tour %d%s\n%s Artefact -> sas    %s Journal (passerelle)" % [
		b.turn, "  ·  hostiles en alerte" if b.alert else "",
		"[x]" if b.artifact.x < 0 and b.living(true).any(func(u): return u.carrying) else "[ ]", "[x]" if b.logs_done else "[ ]"]
	for id in squad:
		var u := b.unit(id)
		var btn: Button = squad[id]
		var w: Dictionary = AbyssData.WEAPONS[u.weapon]
		var state := "Évacué" if u.evacuated else ("Mort au combat" if not u.alive else "%d PV · %d UT" % [u.hp, u.tu])
		btn.text = "%s\n%s · %d/%d\n%s\n" % [u.name.replace("Sgt. ", ""), ROLES.get(id, ""), u.ammo, w.get("mag", 0), state]
		btn.modulate = Color(1, 1, 1) if u.alive and not u.evacuated else Color(0.55, 0.58, 0.62)
		var bd: Dictionary = badges[id]
		bd["interact"].visible = u.carrying
		bd["kneel"].visible = u.alive and u.kneeling
		bd["watch"].visible = u.alive and u.watching
		bd["heal"].visible = u.alive and u.wounds > 0
		bars[id][0].size.x = 90.0 * clampf(float(u.hp) / u.max_hp, 0, 1) if u.alive else 0.0
		bars[id][1].size.x = 90.0 * clampf(float(u.tu) / u.max_tu, 0, 1) if u.alive else 0.0
		bars[id][0].color = GREEN if u.hp > u.max_hp * 0.5 else (AMBER if u.hp > u.max_hp * 0.25 else RED)
		btn.disabled = not u.alive or u.evacuated or busy
		btn.add_theme_stylebox_override("normal", _box(Color(0.06, 0.16, 0.2, 0.92) if sel == u else Color(0.04, 0.1, 0.15, 0.85), CYAN if sel == u else Color(0.22, 0.85, 0.94, 0.3)))
	var ready := sel != null and sel.alive and not busy and b.side == "human" and b.outcome == "ongoing"
	if sel:
		var w: Dictionary = AbyssData.WEAPONS[sel.weapon]
		info.text = "%s · %s %d/%d%s%s" % [sel.name, w["name"], sel.ammo, w.get("mag", 0), "  · genou" if sel.kneeling else "", "  · surveillance" if sel.watching else ""]
	var split := b.evac_split()
	var target := b.interact_target(sel) if sel else ""
	var spec := {
		"snap": ["Rapide", b.shot_cost(sel, "snap") if sel else 0, true],
		"aimed": ["Précis", b.shot_cost(sel, "aimed") if sel else 0, true],
		"throw": ["Grenade", AbyssData.GRENADE_TU, sel != null and sel.grenades > 0],
		"breach": ["Brèche", b.shot_cost(sel, "aimed") if sel else 0, sel != null and AbyssData.WEAPONS[sel.weapon]["breach"]],
		"heal": ["Soin x%d" % (sel.medkit if sel else 0), AbyssData.MEDKIT_TU, sel != null and sel.medkit > 0],
		"reload": ["Recharger", AbyssData.RELOAD_TU, sel != null and b.reload_error(sel) != "Chargeur plein"],
		"kneel": ["Genou", AbyssData.KNEEL_TU, sel != null and not sel.kneeling],
		"watch": ["Veille", AbyssData.WATCH_TU, sel != null and not sel.watching],
		"interact": ["Artefact" if target == "artifact" else "Journal", AbyssData.INTERACT_TU, target != ""],
		"evac": ["Évacuer", 0, not split["leaving"].is_empty()],
	}
	for m in spec:
		var btn: Button = actions[m]
		btn.visible = spec[m][2]
		btn.text = "%s %d" % [spec[m][0], spec[m][1]] if m != "evac" else ("Évacuer (%d)" % split["staying"].size() if split["staying"].size() else "Évacuer")
		btn.disabled = not ready or (sel != null and sel.tu < spec[m][1])
		btn.add_theme_color_override("font_color", AMBER if mode == m or m in ["interact", "evac"] else TEXT)
		btn.add_theme_stylebox_override("normal", tex_box("btn_orange" if mode == m else ("btn_green" if m in ["interact", "evac"] else "btn_secondary")))
	actions["end"].text = "FIN DU\nTOUR"
	actions["end"].add_theme_stylebox_override("normal", tex_box("btn_orange"))
	actions["end"].add_theme_color_override("font_color", AMBER)
	actions["end"].disabled = busy or b.side != "human" or b.outcome != "ongoing"

## Débriefing : verdict, objectifs, état de chaque soldat, bilan, recherche débloquée.
func show_end(b: AbyssBattle) -> void:
	for c in end_panel.get_children():
		c.queue_free()
	end_panel.custom_minimum_size = Vector2(600, 0)
	var carried := b.units.any(func(u): return u.carrying and u.evacuated)
	var retreat := b.units.any(func(u): return u.evacuated)
	var title := "VICTOIRE" if b.outcome == "victory" else ("RETRAITE" if retreat else "ÉCHEC")
	var tcol := GREEN if b.outcome == "victory" else (AMBER if retreat else RED)
	var foes := b.units.filter(func(x): return not x.human)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	end_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_label(head, title, 30, tcol)
	var sub := _label(head, "   DÉBRIEFING · OPÉRATION NÉMÉSIS · %d tours" % b.turn, 13, Color(0.7, 0.8, 0.86))
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	_label(left, "OBJECTIFS", 13, AMBER)
	for o in [["Artefact extrait", carried], ["Journal du terminal", b.logs_done]]:
		var row := HBoxContainer.new()
		left.add_child(row)
		var st := _label(row, "RÉUSSI " if o[1] else "ÉCHOUÉ ", 13, GREEN if o[1] else RED)
		st.custom_minimum_size = Vector2(62, 0)
		_label(row, o[0], 13, TEXT)
	_label(left, "ESCOUADE", 13, AMBER)
	for u in b.units.filter(func(x): return x.human):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		var pic := TextureRect.new()
		pic.texture = load("res://assets/ui/portraits/%s.jpg" % u.id)
		pic.custom_minimum_size = Vector2(34, 34)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if not u.alive:
			pic.modulate = Color(0.45, 0.45, 0.48)
		row.add_child(pic)
		var nm := _label(row, u.name.replace("Sgt. ", ""), 14, TEXT)
		nm.custom_minimum_size = Vector2(70, 0)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var st: Array = ["Évacué%s · %d PV" % [" (artefact)" if u.carrying else "", u.hp], GREEN] if u.evacuated else (["Mort au combat", RED] if not u.alive else ["Laissé sur place · %d PV" % u.hp, AMBER])
		_label(row, st[0], 13, st[1]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_label(right, "BILAN", 13, AMBER)
	_label(right, "Hostiles neutralisés : %d/%d\nSoldats perdus : %d/4" % [foes.size() - b.living(false).size(), foes.size(), b.units.filter(func(u): return u.human and not u.alive).size()], 13, TEXT)
	if carried:
		_label(right, "RECHERCHE DÉBLOQUÉE", 13, CYAN)
		var card := TextureRect.new() # fiche de recherche RES-001
		card.texture = load("res://assets/ui/screens/research_res001.jpg")
		card.custom_minimum_size = Vector2(250, 140)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		right.add_child(card)
		_label(right, "Artefact alien inconnu (RES-001)", 12, Color(0.7, 0.8, 0.86))
	var again := _button(v, "Nouvelle mission", func(): restart.emit(), 15)
	again.custom_minimum_size = Vector2(0, 44)
	again.add_theme_stylebox_override("normal", tex_box("btn_orange"))
	end_panel.visible = true
	set_preview("", false)
	await get_tree().process_frame
	end_panel.reset_size()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

## Fiche ennemi (haut droite) : portrait, PV, armure, arme, conseil ; chance de toucher si un tir est visé.
func _build_foe_panel(root: Control) -> void:
	foe_panel = PanelContainer.new()
	foe_panel.add_theme_stylebox_override("panel", frame())
	foe_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	foe_panel.position = Vector2(-262 - margin, 58)
	foe_panel.custom_minimum_size = Vector2(262, 0)
	foe_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_panel.visible = false
	root.add_child(foe_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_panel.add_child(h)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(64, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.custom_minimum_size = Vector2(160, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_l := _label(v, "", 16, RED)
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(160, 5)
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.size = Vector2(160, 5)
	bar.color = RED
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar)
	var stats := _label(v, "", 12, TEXT)
	var desc := _label(v, "", 11, Color(0.7, 0.8, 0.86))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(160, 0)
	_foe_widgets = {"pic": pic, "name": name_l, "bar": bar, "stats": stats, "desc": desc}

func show_foe(u: AbyssUnit, chance := -1) -> void:
	var f: Array = FOES.get(u.kind, ["", u.name])
	var w: Dictionary = AbyssData.WEAPONS[u.weapon]
	_foe_widgets["pic"].texture = load(f[0]) if f[0] != "" and ResourceLoader.exists(f[0]) else null
	_foe_widgets["name"].text = u.name.to_upper() + ("   ·   %d %%" % chance if chance >= 0 else "")
	_foe_widgets["bar"].size.x = 160.0 * clampf(float(u.hp) / u.max_hp, 0, 1)
	_foe_widgets["stats"].text = "%d/%d PV · armure %d · %s (%d)" % [u.hp, u.max_hp, u.armor, w["name"], w["range"]]
	_foe_widgets["desc"].text = f[1]
	foe_panel.visible = true
	menu.visible = false

func hide_foe() -> void:
	if foe_panel:
		foe_panel.visible = false
