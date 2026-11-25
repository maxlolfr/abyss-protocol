extends SceneTree
## Capture des écrans d'interface : godot --path . -s res://tests/screens_shot.gd -- out.png title|briefing
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sc := AbyssScreens.new()
	root.add_child(sc)
	if a[1] == "title":
		sc.show_title(false, func(): pass)
	else:
		sc.show_briefing()
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
