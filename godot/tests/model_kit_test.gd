extends SceneTree
## Branchement des modèles 3D (ModelKit) avec de faux GLB générés à la volée :
##   godot --headless --path . -s res://tests/model_kit_test.gd            (vérifications)
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/model_kit_test.gd -- out.png   (+ capture de Némésis)
## Vérifie : échelle, orientation automatique d'un mur livré dans l'autre sens, dalle au ras du sol,
## couverts numérotés, objet qui remplace un sprite, néons recolorés (cyan humain, violet alien), repli sans fichier.

var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "ÉCHEC ") + what)

func _glb(rel: String, size: Vector3, glow_name := "") -> void:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.5, 0.4)
	if glow_name != "":
		m.resource_name = glow_name
	b.material = m
	mi.mesh = b
	mi.position = Vector3(3, 7, -2) # origine décalée : le jeu doit recentrer
	root.add_child(mi)
	mi.owner = root
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_scene(root, st)
	var path := ProjectSettings.globalize_path("user://kit_test/" + rel + ".glb")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	doc.write_to_filesystem(st, path)
	root.free()

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	_glb("kit/station/cloison", Vector3(0.25, 2.0, 3.0))       # livré le long de Z, 3 unités de long
	_glb("kit/sol_dalle", Vector3(2.0, 0.2, 2.0))              # commun à tous les thèmes
	_glb("kit/station/mur_coque", Vector3(2.0, 4.8, 2.0))
	_glb("kit/station/couvert_bas_01", Vector3(1.2, 0.5, 0.8))
	_glb("kit/station/couvert_bas_02", Vector3(0.9, 0.9, 0.9))
	_glb("props/reacteur", Vector3(1, 1, 1), "Neon_Strip")
	_glb("props/oeuf_alien", Vector3(1, 2, 1), "glow")
	_glb("weapons/fusil_assaut", Vector3(2.0, 0.3, 0.2)) # livré le long de X
	ModelKit.root = ProjectSettings.globalize_path("user://kit_test/") + "/"
	ModelKit.clear_cache()

	var w := ModelKit.piece("wall", "station")
	check(not w.is_empty(), "cloison trouvée dans kit/station")
	var box: AABB = (w["xform"] as Transform3D) * (w["mesh"] as Mesh).get_aabb()
	check(absf(box.size.x - 1.0) < 0.02 and box.size.z < 0.2, "cloison tournée le long de X, 1 m de large (%s)" % box.size)
	check(absf(box.position.y) < 0.01 and absf(box.get_center().x) < 0.01, "cloison posée au sol et centrée")
	var f := ModelKit.piece("floor", "nid")
	var fb: AABB = (f["xform"] as Transform3D) * (f["mesh"] as Mesh).get_aabb()
	check(absf(fb.end.y) < 0.01 and absf(fb.size.x - 1.0) < 0.02, "dalle commune : 1 m, dessus au ras du sol")
	check(ModelKit.piece("hull_w", "station").is_empty(), "hublot absent : pièce provisoire gardée")
	var c1 := ModelKit.cover("station", false, 0)
	var c2 := ModelKit.cover("station", false, 1)
	check(c1 != null and c2 != null and c1 != c2, "deux couverts bas numérotés")
	var cb := _bounds(c1)
	check(absf(cb.size.y - ModelKit.COVER_LOW_H) < 0.02, "couvert bas à %.1f m (%.2f)" % [ModelKit.COVER_LOW_H, cb.size.y])
	check(ModelKit.cover("port", true, 0) == null, "aucun couvert haut : null")
	var r := AbyssKit.prop("k007_1", 1.2)
	check(not (r is Sprite3D), "le réacteur 3D remplace l'objet peint k007_1")
	var rm := (r.get_child(0) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	check(rm.emission_enabled and rm.emission == ModelKit.CYAN, "néon humain recoloré en cyan")
	var e := AbyssKit.prop("k009_4", 1.2)
	var em := (e.get_child(0) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	check(em.emission == ModelKit.VIOLET, "néon alien recoloré en violet")
	check(AbyssKit.prop("k010_4", 1.0) is Sprite3D, "objet sans modèle : sprite gardé")
	var gun := ModelKit.weapon("fusil_assaut", 0.95)
	var gb := _bounds(gun)
	check(gun != null and absf(gb.size.z - 0.95) < 0.02 and gb.size.x < 0.2, "fusil remis canon vers +Z, 0,95 m (%s)" % gb.size)
	check(ModelKit.weapon("pistolet", 0.3) == null, "pistolet absent : rien d'attaché")
	r.free(); e.free(); c1.free(); c2.free(); gun.free()

	var out := OS.get_cmdline_user_args()
	if out.size() > 0: # capture : la mission Némésis avec les faux modèles
		var main: Node = load("res://view/main.tscn").instantiate()
		if "show_intro" in main:
			main.show_intro = false
		root.add_child(main)
		for i in 40:
			await process_frame
		main.cam.size = 17.0
		main.pivot.position = Vector3(8, 0, 7)
		for i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out[0])
		var mm: MultiMesh = main.hull_mm["hull"]
		var hb := AABB()
		for i in mm.instance_count:
			var b: AABB = mm.get_instance_transform(i) * mm.mesh.get_aabb()
			hb = b if i == 0 else hb.merge(b)
		check(hb.size.y > 2.0 and hb.size.x <= main.battle.grid.w + 0.01, "coque livrée en place après la coupe caméra (%s)" % hb.size)
		print("capture : ", out[0])
	print("ModelKit : %d échec(s)" % fails)
	quit(1 if fails > 0 else 0)

func _bounds(n: Node3D) -> AABB:
	var mi := n.get_child(0) as MeshInstance3D
	return (n.transform * mi.transform) * mi.mesh.get_aabb()
