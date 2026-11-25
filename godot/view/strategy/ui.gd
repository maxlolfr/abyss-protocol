class_name StratUI
## Petits constructeurs d'interface du géoscape et de la base (mêmes couleurs et boutons UI-114 que le combat).

const CYAN := Color("39d9ef")
const AMBER := Color("ffb547")
const RED := Color("e5484d")
const GREEN := Color("52c99a")
const VIOLET := Color("b06cff")
const TEXT := Color("e4edf5")
const DIM := Color(0.66, 0.77, 0.85)
const PANEL := Color(0.02, 0.045, 0.075, 0.9)

static func label(parent: Node, text: String, size := 14, col := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## kind : primary (cyan), secondary, orange, green, red. Hauteur minimale 44 px (doigt).
static func button(parent: Node, text: String, cb: Callable, kind := "secondary", min_w := 0.0, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var fc: Color = {"primary": CYAN, "orange": AMBER, "green": GREEN, "red": Color("ff8a8d")}.get(kind, TEXT)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.56, 0.6))
	var sb := AbyssHud.tex_box("btn_" + kind, Vector4(14, 12, 14, 12), Vector4(12, 6, 12, 6))
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("disabled", AbyssHud.tex_box("btn_disabled", Vector4(14, 12, 14, 12), Vector4(12, 6, 12, 6)))
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func box(bg := PANEL, border := Color(0.22, 0.85, 0.94, 0.35), pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(pad)
	return s

static func panel(parent: Node, framed := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AbyssHud.frame() if framed else box())
	parent.add_child(p)
	return p

static func vbox(parent: Node, sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

static func hbox(parent: Node, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h

static func scroll(parent: Node) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	return s

static func bar(parent: Node, frac: float, col := CYAN, w := 120.0, h := 6.0) -> Control:
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.1)
	back.custom_minimum_size = Vector2(w, h)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var f := ColorRect.new()
	f.color = col
	f.size = Vector2(w * clampf(frac, 0, 1), h)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(f)
	return back

static func portrait(parent: Node, visual: String, size := 48) -> void:
	var path := "res://assets/ui/portraits/%s.jpg" % visual
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/portraits/s3.jpg"
	var p := TextureRect.new()
	p.texture = load(path)
	p.custom_minimum_size = Vector2(size, size)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)

static func k(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " k"

static func duration(mins: int) -> String:
	if mins >= 2880:
		return "%d j" % int(round(mins / 1440.0))
	if mins >= 60:
		return "%d h" % int(round(mins / 60.0))
	return "%d min" % mins
