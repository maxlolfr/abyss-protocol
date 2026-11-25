extends SceneTree
## Capture d'écran hors ligne : xvfb-run godot --path . -s res://tests/shot.gd -- out.png [yaw_steps] [zoom] [x,y = tout révéler] [qualité]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shot.png"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var main: Node = load("res://view/main.tscn").instantiate()
	main.show_intro = false
	root.add_child(main)
	for i in 30:
		await process_frame
	if args.size() > 4:
		main._apply_quality(args[4])
	if args.size() > 1 and int(args[1]) != 0:
		main._rotate(int(args[1]))
	if args.size() > 2:
		main.cam.size = float(args[2])
	if args.size() > 3: # vue d'ensemble : tout révélé, caméra centrée sur la case x,y
		main.battle.explored.fill(1)
		main._sync()
		for fq in main.fog_quads.values():
			fq.visible = false
		for mm in main.fog_layers: # phase 3 : brouillard en MultiMesh, masqué pour les vues d'ensemble
			mm.visible_instance_count = 0
		var xy: PackedStringArray = args[3].split(",")
		main.pivot.position = Vector3(float(xy[0]), 0, float(xy[1]))
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
