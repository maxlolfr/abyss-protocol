class_name AbyssScreens
extends CanvasLayer
## Écran titre (ENV-001), briefing de la mission Némésis (ENV-007, fiches des hostiles, escouade),
## illustrations de Max allégées pour le Web. Plein écran, adapté au tactile et aux zones de sécurité.

signal closed

const CYAN := Color("39d9ef")
const AMBER := Color("ffb547")
const TEXT := Color("e4edf5")
const DIM := Color(0.75, 0.85, 0.92)

var root: Control
var margin := 24.0

func _ready() -> void:
	layer = 20
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x > 0 and scr.x > 0:
		margin = maxf(24.0, float(safe.position.x) * 960.0 / scr.x + 12.0)

func _clear() -> void:
	if root:
		root.queue_free()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

func _bg(path: String, dim: float) -> void:
	var bg := TextureRect.new()
	bg.texture = load(path)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.05, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

func _label(parent: Node, text: String, size: int, col: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _box(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	return s

func _button(parent: Node, text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20 if primary else 17)
	b.add_theme_color_override("font_color", Color("071018") if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color("071018") if primary else TEXT)
	b.add_theme_color_override("font_pressed_color", Color("071018") if primary else TEXT)
	b.add_theme_stylebox_override("normal", _box(CYAN if primary else Color(0.03, 0.08, 0.12, 0.85), CYAN))
	b.add_theme_stylebox_override("hover", _box(Color("6fe6f5") if primary else Color(0.06, 0.15, 0.2, 0.92), CYAN))
	b.add_theme_stylebox_override("pressed", _box(Color("2bb8cc") if primary else Color(0.08, 0.2, 0.26, 0.95), CYAN))
	b.custom_minimum_size = Vector2(280, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _portrait(parent: Node, path: String, size: int) -> void:
	var p := TextureRect.new()
	p.texture = load(path)
	p.custom_minimum_size = Vector2(size, size)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)

## Écran titre : illustration ENV-001, logo, Continuer / Nouvelle mission.
func show_title(can_continue: bool, on_new: Callable) -> void:
	_clear()
	_bg("res://assets/ui/screens/title.jpg", 0.35)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.03, 0.05, 0.0))
	g.set_color(1, Color(0.01, 0.03, 0.05, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.3)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.position = Vector2(margin + 16, -290)
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.custom_minimum_size = Vector2(620, 0)
	var t := _label(v, "ABYSS PROTOCOL", 58, TEXT, 10)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(v, "MISSION 01  ·  NÉMÉSIS", 18, CYAN, 4).autowrap_mode = TextServer.AUTOWRAP_OFF
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	v.add_child(sp)
	if can_continue:
		_button(v, "Reprendre la mission", func(): _close(), true)
		_button(v, "Nouvelle mission", on_new)
	else:
		_button(v, "Commencer", func(): show_briefing(), true)

## Briefing : salle Némésis (ENV-007), objectifs, hostiles détectés, escouade.
func show_briefing() -> void:
	_clear()
	_bg("res://assets/ui/screens/briefing_nemesis.jpg", 0.45)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.05, 0.08, 0.86), Color(0.22, 0.85, 0.94, 0.5)))
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = margin
	panel.offset_top = 16
	panel.offset_bottom = -16
	panel.offset_right = margin + 470
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	_label(v, "BRIEFING  ·  OPÉRATION NÉMÉSIS", 22, CYAN, 3)
	_label(v, "Laboratoire de confinement englouti. Une cuve centrale abrite l'artefact Némésis ; la station ne répond plus et des signatures non humaines ont été relevées.", 14, DIM)
	_label(v, "OBJECTIFS", 15, AMBER)
	_label(v, "• Principal : récupérer l'artefact dans sa cuve et l'évacuer par le sas.\n• Secondaire : télécharger le journal du terminal (mezzanine est).", 14, TEXT)
	_label(v, "Éliminer les hostiles ne suffit pas : la prise de l'artefact déclenche l'alarme et réveille des renforts dans les bassins, par vagues.", 12, Color(1.0, 0.55, 0.45))
	_label(v, "HOSTILES DÉTECTÉS", 15, AMBER)
	var hz := HBoxContainer.new()
	hz.add_theme_constant_override("separation", 10)
	v.add_child(hz)
	for e in [["nereide", "Néréide", "Éclaireuse amphibie, rapide"], ["spectre", "Spectre", "Entité psionique, ignore les couverts"], ["", "Carapace", "Non identifiée, lourde"]]:
		var c := VBoxContainer.new()
		c.custom_minimum_size = Vector2(138, 0)
		hz.add_child(c)
		if e[0] != "":
			_portrait(c, "res://assets/ui/portraits/%s.jpg" % e[0], 58)
		else:
			var q := _label(c, "?", 48, Color(0.9, 0.5, 0.4), 4)
			q.custom_minimum_size = Vector2(58, 58)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(c, e[1], 14, TEXT)
		_label(c, e[2], 11, DIM)
	_label(v, "ESCOUADE", 15, AMBER)
	var sq := HBoxContainer.new()
	sq.add_theme_constant_override("separation", 8)
	v.add_child(sq)
	for s in [["s1", "Walker", "Fusilier"], ["s2", "Okafor", "Lourd"], ["s3", "Lind", "Précision"], ["s4", "Moreau", "Médecin"]]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		c.custom_minimum_size = Vector2(96, 0)
		sq.add_child(c)
		_portrait(c, "res://assets/ui/portraits/%s.jpg" % s[0], 50)
		_label(c, s[1], 13, TEXT)
		_label(c, s[2], 11, DIM)
	var go := HBoxContainer.new()
	go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-300 - margin, -80)
	root.add_child(go)
	_button(go, "LANCER LA MISSION", func(): _close(), true)

func _close() -> void:
	queue_free()
	closed.emit()
