class_name AbyssHud
extends CanvasLayer
## Interface tactile minimaliste : unité active, actions avec coût UT, aperçu + confirmer, caméra, bandeaux.
## Aucune fenêtre modale sauf le récapitulatif de fin.

signal action(mode: String)
signal confirm
signal select_unit(id: String)
signal rotate_cam(dir: int)
signal speed_changed(speed: float)
signal shadows_changed(on: bool)
signal restart

const CYAN := Color("5cf2ff")
const AMBER := Color("ffb347")
const PANEL := Color(0.02, 0.07, 0.1, 0.82)

var info: Label
var turn_lbl: Label
var preview: Label
var confirm_btn: Button
var toast: Label
var fps_lbl: Label
var actions := {}
var squad := {}
var end_panel: PanelContainer
var end_lbl: Label
var speed := 1.0
var shadows := true
var _toast_t := 0.0

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# haut gauche : tour + unité active
	var tl := _panel(root, Vector2(10, 10))
	var v := VBoxContainer.new()
	tl.add_child(v)
	turn_lbl = _label(v, "Tour 1", 15, AMBER)
	info = _label(v, "", 17, Color.WHITE)
	# gauche : escouade
	var sq := VBoxContainer.new()
	sq.position = Vector2(10, 110)
	sq.add_theme_constant_override("separation", 6)
	root.add_child(sq)
	for id in ["s1", "s2", "s3", "s4"]:
		var b := _button(sq, id, func(): select_unit.emit(id))
		b.custom_minimum_size = Vector2(150, 44)
		squad[id] = b
	# haut droite : caméra, vitesse, ombres, i/s
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-500, 10)
	tr.add_theme_constant_override("separation", 6)
	root.add_child(tr)
	fps_lbl = _label(tr, "", 14, Color(0.7, 0.85, 0.9))
	_button(tr, "< Tourner", func(): rotate_cam.emit(-1)).custom_minimum_size = Vector2(90, 48)
	_button(tr, "Tourner >", func(): rotate_cam.emit(1)).custom_minimum_size = Vector2(90, 48)
	var sp := _button(tr, "×1", func(): pass)
	sp.pressed.connect(func():
		speed = {1.0: 2.0, 2.0: 4.0, 4.0: 1.0}[speed]
		sp.text = "×%d" % int(speed)
		speed_changed.emit(speed))
	var sh := _button(tr, "Ombres : oui", func(): pass)
	sh.pressed.connect(func():
		shadows = not shadows
		sh.text = "Ombres : %s" % ("oui" if shadows else "non")
		shadows_changed.emit(shadows))
	# bas : aperçu + actions
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -118
	bottom.offset_bottom = -8
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(prow)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", _box(PANEL, CYAN))
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(pp)
	preview = _label(pp, "Touchez un soldat, puis une case ou un ennemi.", 16, Color.WHITE)
	confirm_btn = _button(prow, "Confirmer", func(): confirm.emit())
	confirm_btn.visible = false
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 6)
	bottom.add_child(arow)
	for m in [["snap", "Tir rapide"], ["aimed", "Tir précis"], ["throw", "Grenade"], ["breach", "Brèche"], ["kneel", "Genou"], ["watch", "Surveillance"], ["end", "Fin du tour"]]:
		var b := _button(arow, m[1], func(): action.emit(m[0]))
		b.custom_minimum_size = Vector2(108, 50)
		actions[m[0]] = b
	# bandeau
	toast = _label(root, "", 20, AMBER)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-260, 70)
	toast.custom_minimum_size = Vector2(520, 0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	# récapitulatif final
	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-200, -110)
	end_panel.custom_minimum_size = Vector2(400, 220)
	end_panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.06, 0.09, 0.95), CYAN))
	end_panel.visible = false
	root.add_child(end_panel)
	var ev := VBoxContainer.new()
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	end_panel.add_child(ev)
	end_lbl = _label(ev, "", 20, Color.WHITE)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(ev, "Rejouer (nouvelle seed)", func(): restart.emit())

func _process(delta: float) -> void:
	fps_lbl.text = "%d i/s" % Engine.get_frames_per_second()
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t, 0.0, 1.0)

func _panel(parent: Control, pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.add_theme_stylebox_override("panel", _box(PANEL, Color(0.36, 0.95, 1, 0.35)))
	parent.add_child(p)
	return p

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8)
	return s

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", _box(Color(0.05, 0.14, 0.19, 0.92), Color(0.36, 0.95, 1, 0.5)))
	b.add_theme_stylebox_override("hover", _box(Color(0.08, 0.2, 0.26, 0.95), CYAN))
	b.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.3, 0.36, 0.95), CYAN))
	b.add_theme_stylebox_override("disabled", _box(Color(0.04, 0.07, 0.09, 0.8), Color(0.3, 0.35, 0.4, 0.4)))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func flash(text: String) -> void:
	toast.text = text
	_toast_t = 2.2
	toast.modulate.a = 1.0

func set_preview(text: String, can_confirm: bool) -> void:
	preview.text = text
	confirm_btn.visible = can_confirm

## Met à jour l'escouade, l'unité active et l'état des boutons.
func refresh(b: AbyssBattle, sel: AbyssUnit, mode: String, busy: bool) -> void:
	turn_lbl.text = "Tour %d · %s" % [b.turn, "à vous" if b.side == "human" else "hostiles"]
	for id in squad:
		var u := b.unit(id)
		var btn: Button = squad[id]
		btn.text = "%s  %d PV · %d UT%s" % [u.name.replace("Sgt. ", ""), u.hp, u.tu, "" if u.alive else " (mort)"]
		btn.disabled = not u.alive or busy
		btn.modulate = Color(1, 1, 1) if sel == u else Color(0.75, 0.82, 0.86)
	if sel:
		var w: Dictionary = AbyssData.WEAPONS[sel.weapon]
		info.text = "%s · %s\nPV %d/%d · UT %d/%d%s%s" % [sel.name, w["name"], sel.hp, sel.max_hp, sel.tu, sel.max_tu,
			" · à genoux" if sel.kneeling else "", " · surveillance" if sel.watching else ""]
	var costs := {"snap": b.shot_cost(sel, "snap") if sel else 0, "aimed": b.shot_cost(sel, "aimed") if sel else 0,
		"throw": AbyssData.GRENADE_TU, "breach": b.shot_cost(sel, "aimed") if sel else 0, "kneel": AbyssData.KNEEL_TU, "watch": AbyssData.WATCH_TU}
	var labels := {"snap": "Tir rapide", "aimed": "Tir précis", "throw": "Grenade", "breach": "Brèche", "kneel": "Genou", "watch": "Surveillance"}
	for m in labels:
		var btn: Button = actions[m]
		btn.text = "%s\n%d UT" % [labels[m], costs[m]]
		var ok: bool = sel != null and sel.alive and not busy and b.side == "human" and sel.tu >= costs[m]
		if m == "throw":
			ok = ok and sel.grenades > 0
			btn.visible = sel != null and sel.grenades > 0
		if m == "breach":
			ok = ok and AbyssData.WEAPONS[sel.weapon]["breach"]
			btn.visible = sel != null and AbyssData.WEAPONS[sel.weapon]["breach"]
		btn.disabled = not ok
		btn.modulate = Color(1, 0.85, 0.5) if mode == m else Color.WHITE
	actions["end"].disabled = busy or b.side != "human"

func show_end(b: AbyssBattle) -> void:
	var lost := 4 - b.living(true).size()
	end_lbl.text = "%s\nTours : %d · Hostiles neutralisés : %d/3 · Pertes : %d" % [
		"VICTOIRE" if b.outcome == "victory" else "ÉCHEC DE LA MISSION", b.turn, 3 - b.living(false).size(), lost]
	end_panel.visible = true
