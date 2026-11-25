extends SceneTree
## Combat lancé depuis la campagne : xvfb-run godot --path . -s res://tests/campaign_battle_shot.gd -- out.png <type de mission>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/cb.png"
	var kind: String = a[1] if a.size() > 1 else "port"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var c := AbyssCampaign.new("shot")
	c.recruits[0]["visual"] = "s4"
	c.apply({"type": "recruit", "index": 0})
	c.soldier("s2")["status"] = "dead"
	var s := c._add_site(kind, StratData.PORTS["lisbonne"]["pos"], 600, ["nereide", "carapace", "nereide"] if kind != "nid" else ["spectre", "carapace", "nereide", "nereide", "carapace"])
	AbyssSession.mission = c.mission_config(s["id"])
	var main: Node = load("res://view/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.battle.explored.fill(1)
	main._sync()
	for fq in main.fog_quads.values():
		fq.visible = false
	main.cam.size = 17.0
	main.pivot.position = Vector3(8, 0, 7)
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("unités : ", main.battle.units.map(func(u): return "%s:%s" % [u.id, u.kind]))
	quit()
