class_name StratMarker
extends Control
## Marqueur tactile du globe : forme dessinée (losange base, triangle engin, anneau contact, carré mission)
## + étiquette. Zone de toucher de 28 px autour du point.

var pressed_cb: Callable
var col := Color.WHITE
var shape := "ring"
var selected := false
var _label := Label.new()
var _t := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(28, 28)
	size = Vector2(28, 28)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label.position = Vector2(30, 4)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func setup(text: String, c: Color, s: String, sel: bool) -> void:
	if _label.text != text:
		_label.text = text
	_label.add_theme_color_override("font_color", c)
	if c != col or s != shape or sel != selected:
		col = c
		shape = s
		selected = sel
		queue_redraw()

func _process(delta: float) -> void:
	if shape == "ring" or selected:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var o := Vector2(14, 14)
	match shape:
		"diamond":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -9), o + Vector2(9, 0), o + Vector2(0, 9), o + Vector2(-9, 0)]), col)
			draw_circle(o, 3, Color("06121a"))
		"tri":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -8), o + Vector2(7, 6), o + Vector2(-7, 6)]), col)
		"square":
			draw_rect(Rect2(o - Vector2(7, 7), Vector2(14, 14)), col)
			draw_rect(Rect2(o - Vector2(3, 3), Vector2(6, 6)), Color("06121a"))
		_:
			var pulse := fmod(_t, 1.6) / 1.6
			draw_arc(o, 6, 0, TAU, 24, col, 2.5)
			draw_arc(o, 6 + pulse * 10, 0, TAU, 24, Color(col, 1.0 - pulse), 1.5)
	if selected:
		draw_arc(o, 13 + sin(_t * 4) * 1.5, 0, TAU, 32, Color(1, 1, 1, 0.9), 1.5)

func _gui_input(e: InputEvent) -> void:
	var up: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed # le toucher est émulé en souris
	if up and pressed_cb.is_valid():
		accept_event()
		pressed_cb.call()
