extends SceneTree
## Mesure du coût de rendu d'une vue de jeu : godot --path . -s res://tests/perf.gd [-- carte]
## (appels de rendu, objets, primitives : indépendants de la machine ; le temps par image ne l'est pas)
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var main: Node = load("res://view/main.tscn").instantiate()
	if "show_intro" in main:
		main.show_intro = false
	root.add_child(main)
	for i in 40:
		await process_frame
	var q := OS.get_cmdline_user_args()
	if q.size() > 0 and main.has_method("_apply_quality"):
		main._apply_quality(q[0])
	main.cam.size = 16.0
	main.pivot.position = Vector3(8, 0, 7)
	for i in 10:
		await process_frame
	var draws := 0.0
	var objs := 0.0
	var prims := 0.0
	for i in 10:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("PERF appels=%d objets=%d primitives=%d lumières=%d" % [draws / 10, objs / 10, prims / 10, main.find_children("*", "Light3D", true, false).filter(func(l): return l.is_visible_in_tree()).size()])
	quit()
