extends SceneTree
## Outil (pas un test) : niveaux de détail d'un GLB calculés par Godot, pour tools/reduce_glb.py.
## godot --headless --path godot -s res://tests/lods.gd -- entree.glb sortie.bin
## sortie.bin : nombre de niveaux, puis pour chacun (nombre d'indices, indices int32 dans l'ordre glTF).
## Godot s'arrête de simplifier quand la forme se dégraderait trop : le dernier niveau peut dépasser le budget.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var st := GLTFState.new()
	if GLTFDocument.new().append_from_file(a[0], st) != OK:
		quit(1)
		return
	var im: ImporterMesh = st.get_meshes()[0].mesh
	im.generate_lods(60.0, 60.0, [])
	var f := FileAccess.open(a[1], FileAccess.WRITE)
	f.store_32(im.get_surface_lod_count(0))
	for l in im.get_surface_lod_count(0):
		var idx: PackedInt32Array = im.get_surface_lod_indices(0, l)
		for t in range(0, idx.size(), 3): # Godot inverse le sens des triangles : retour à l'ordre glTF
			var k := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = k
		f.store_32(idx.size())
		f.store_buffer(idx.to_byte_array())
	f.close()
	quit()
