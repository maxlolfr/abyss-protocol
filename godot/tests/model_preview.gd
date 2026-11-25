extends SceneTree
## Aperçu brut des modèles 3D importés : xvfb-run godot --path . -s res://tests/model_preview.gd -- out.png [angle]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/models.png"
	var yaw := float(a[1]) if a.size() > 1 else 0.0
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a7f98")
	var we := WorldEnvironment.new(); we.environment = env; w.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); w.add_child(sun)
	var files := ["walker.glb", "okafor.glb", "lind.glb", "nereide.glb", "brute.glb"]
	for i in files.size():
		var n: Node3D = (load("res://assets/models/units/" + files[i]) as PackedScene).instantiate()
		var aabb := _aabb(n)
		print(files[i], " aabb ", aabb)
		var s: float = 1.8 / maxf(aabb.size.y, 0.001)
		n.scale = Vector3.ONE * s
		n.position = Vector3(-3.75 + i * 1.5, -aabb.position.y * s, 0)
		n.rotation_degrees.y = yaw
		w.add_child(n)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 6.5)
	cam.fov = 50
	w.add_child(cam)
	root.size = Vector2i(1500, 600)
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()

func _aabb(n: Node) -> AABB:
	var r := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D()
		var p: Node = mi
		while p and p != n:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * mi.get_aabb()
		r = b if first else r.merge(b)
		first = false
	return r
