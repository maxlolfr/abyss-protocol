extends SceneTree
## Planche des modèles : xvfb-run godot --path . -s res://tests/lineup.gd -- out.png [anim] [temps] [angle]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/lineup.png"
	var anim: String = a[1] if a.size() > 1 else "idle"
	var t := float(a[2]) if a.size() > 2 else 0.0
	var yaw := float(a[3]) if a.size() > 3 else 25.0
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a5068")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; w.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); sun.shadow_enabled = true; w.add_child(sun)
	var fill := OmniLight3D.new(); fill.position = Vector3(0, 2.5, 3); fill.omni_range = 9; fill.light_color = Color("8fe8ff"); w.add_child(fill)
	for x in range(-4, 5):
		for z in range(-1, 2):
			AbyssKit.spawn("floor", AbyssKit.floor_tile.bind(false), w, Vector3(x, 0, z))
	var kinds := [["soldier", "s1"], ["soldier", "s2"], ["soldier", "s3"], ["nereide", ""], ["carapace", ""], ["brute", ""], ["spectre", ""]]
	for i in kinds.size():
		var n := UnitVisuals.build(kinds[i][0], Callable(), kinds[i][1])
		n.position = Vector3(-3.6 + i * 1.2, 0, 0)
		n.rotation_degrees.y = yaw
		w.add_child(n)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 4.6)
	cam.rotation_degrees.x = -12
	cam.fov = 50
	w.add_child(cam)
	await process_frame
	for ap in w.find_children("Anim", "AnimationPlayer", true, false):
		if ap.has_animation(anim):
			ap.play(anim)
			ap.seek(t, true)
			ap.pause()
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
