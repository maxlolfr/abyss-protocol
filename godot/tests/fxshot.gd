extends SceneTree
## Planche des effets (temps ralenti) : xvfb-run godot --path . -s res://tests/fxshot.gd -- out.png [instant_s]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/fx.png"
	var at := float(a[1]) if a.size() > 1 else 0.12
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070d16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("23384a")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; w.add_child(we)
	for x in range(-4, 5):
		for z in range(-1, 2):
			AbyssKit.spawn("floor", AbyssKit.floor_tile.bind(false), w, Vector3(x, 0, z))
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.4, 5.5)
	cam.rotation_degrees.x = -18
	w.add_child(cam)
	await process_frame
	Engine.time_scale = 0.04
	AbyssFx.flash(w, Vector3(-3.5, 1.0, 0), Color("cff8ff"), 0.8, 0.09)
	AbyssFx.impact(w, Vector3(-2.2, 1.0, 0), "metal")
	AbyssFx.explosion(w, Vector3(0, 0, 0))
	AbyssFx.impact(w, Vector3(2.0, 1.0, 0), "psi")
	AbyssFx.impact(w, Vector3(3.4, 0.6, 0), "acid")
	AbyssFx.puddle(w, Vector3(3.4, 0, 0), Color(0.45, 0.95, 0.2, 0.75), 0.9)
	AbyssFx.projectile(w, Vector3(-4, 1.2, 1), Vector3(4, 1.2, 1), Color("9ff3ff"), 20.0, 0.16)
	var t0 := Time.get_ticks_msec()
	while true:
		await process_frame
		if Engine.get_process_frames() > 0 and (Time.get_ticks_msec() - t0) * 0.04 / 1000.0 >= at:
			break
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
