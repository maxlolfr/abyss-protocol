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
var menu: PanelContainer
var end_panel: PanelContainer
var end_lbl: Label
var _toast_t := 0.0
var _settings := {"speed": 1.0, "shadows": true, "cine": true, "fps": true}

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
		b.custom_minimum_size = Vector2(112, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		squad[id] = b
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
	menu.add_theme_stylebox_override("panel", _box(Color(0.03, 0.07, 0.1, 0.94), CYAN))
	menu.visible = false
	root.add_child(menu)
	var mv := VBoxContainer.new()
	menu.add_child(mv)
	for s in [["shadows", "Ombres dynamiques"], ["cine", "Caméra cinématique"], ["fps", "Afficher les i/s"]]:
		var c := CheckButton.new()
		c.text = s[1]
		c.button_pressed = _settings[s[0]]
		c.add_theme_font_size_override("font_size", 14)
		c.toggled.connect(func(on): _settings[s[0]] = on; setting.emit(s[0], on))
		mv.add_child(c)
	var sp := _button(mv, "Vitesse ennemie : x1", func(): pass, 14)
	sp.pressed.connect(func():
		_settings["speed"] = {1.0: 2.0, 2.0: 4.0, 4.0: 1.0}[_settings["speed"]]
		sp.text = "Vitesse ennemie : x%d" % int(_settings["speed"])
		setting.emit("speed", _settings["speed"]))
	_button(mv, "Nouvelle mission", func(): restart.emit(), 14)
	# bas : aperçu sur une ligne + actions contextuelles
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
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
		b.custom_minimum_size = Vector2(76, 46)
		actions[m] = b
	actions["end"].custom_minimum_size = Vector2(84, 46)
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
	end_panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.05, 0.08, 0.95), CYAN))
	end_panel.visible = false
	root.add_child(end_panel)
	var ev := VBoxContainer.new()
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	end_panel.add_child(ev)
	end_lbl = _label(ev, "", 16, TEXT)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(ev, "Nouvelle mission", func(): restart.emit(), 15)

func _process(delta: float) -> void:
	fps_lbl.text = ("%d i/s" % Engine.get_frames_per_second()) if _settings["fps"] else ""
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t, 0.0, 1.0)

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
	b.add_theme_stylebox_override("normal", _box(Color(0.04, 0.1, 0.15, 0.88), Color(0.22, 0.85, 0.94, 0.4)))
	b.add_theme_stylebox_override("hover", _box(Color(0.06, 0.15, 0.2, 0.92), CYAN))
	b.add_theme_stylebox_override("pressed", _box(Color(0.08, 0.22, 0.28, 0.95), CYAN))
	b.add_theme_stylebox_override("disabled", _box(Color(0.03, 0.05, 0.07, 0.75), Color(0.3, 0.35, 0.4, 0.3)))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func flash(text: String, color := AMBER) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	_toast_t = 2.2
	toast.modulate.a = 1.0

func set_preview(text: String, can_confirm: bool) -> void:
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
		var state := "évacué" if u.evacuated else ("perdu" if not u.alive else "%d PV  %d UT" % [u.hp, u.tu])
		btn.text = "%s%s\n%s" % [u.name.replace("Sgt. ", ""), " *" if u.carrying else "", state]
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
		btn.text = "%s\n%d UT" % [spec[m][0], spec[m][1]] if m != "evac" else ("Évacuer\n%d reste%s" % [split["staying"].size(), "nt" if split["staying"].size() > 1 else ""] if split["staying"].size() else "Évacuer\ntous")
		btn.disabled = not ready or (sel != null and sel.tu < spec[m][1])
		btn.add_theme_color_override("font_color", AMBER if mode == m or m in ["interact", "evac"] else TEXT)
	actions["end"].text = "Fin du\ntour"
	actions["end"].disabled = busy or b.side != "human" or b.outcome != "ongoing"

func show_end(b: AbyssBattle) -> void:
	var carried := b.units.any(func(u): return u.carrying and u.evacuated)
	var title := "VICTOIRE" if b.outcome == "victory" else ("RETRAITE" if b.units.any(func(u): return u.evacuated) else "ÉCHEC")
	end_lbl.text = "%s\nArtefact : %s · Journal : %s\nTours : %d · Hostiles neutralisés : %d/3 · Soldats perdus : %d" % [
		title, "récupéré" if carried or (b.outcome == "victory" and b.living(false).is_empty()) else "perdu", "oui" if b.logs_done else "non",
		b.turn, 3 - b.living(false).size(), b.units.filter(func(u): return u.human and not u.alive).size()]
	end_panel.visible = true
