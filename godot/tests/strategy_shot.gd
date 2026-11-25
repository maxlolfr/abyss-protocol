extends SceneTree
## Captures du géoscape et des onglets : xvfb-run godot --path . -s res://tests/strategy_shot.gd -- dossier/
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "/tmp/"
	var st: AbyssStrategy = load("res://view/strategy/strategy.tscn").instantiate()
	st.show_title = false
	AbyssSession.mission = {}
	AbyssSession.result = {}
	root.add_child(st)
	await process_frame
	var c := st.c
	# quelques jours de campagne : un contact détecté, le Triton en route vers Némésis
	c.advance(60 * 30)
	c.pending = {}
	c.contacts.clear()
	var k := c._new_op("moisson")
	k["detected"] = true
	k["pos"] = AbyssGeo.offset(StratData.BASE_POS, 250, 1500)
	k["error"] = 180.0
	var tri := c._craft_of_type("triton")
	c.apply({"type": "send", "craft": tri["id"], "site": c.site_of_kind("nemesis")["id"]})
	c.advance(60 * 5)
	st._select({"kind": "contact", "id": k["id"]})
	st.globe.view = Vector2(30, -38)
	st.globe._place_cam()
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "geo_contact.png")
	st._select({"kind": "site", "id": c.site_of_kind("nemesis")["id"]})
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "geo_site.png")
	c.items["alliage"] = 2
	c.items["corps_nereide"] = 1
	c.research_done.append("autopsie_nereide")
	c.apply({"type": "research", "id": "alliages"})
	c.apply({"type": "manufacture", "id": "medkit"})
	for t in ["base", "escouade", "recherche"]:
		st._set_tab(t)
		for i in 10:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(dir + "tab_%s.png" % t)
	st._set_tab("monde")
	c.pending = {"type": "intercept", "craft": c._craft_of_type("barracuda")["id"], "contact": k["id"], "odds": c.intercept_odds(c._craft_of_type("barracuda")["id"], k["id"])}
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "modal_intercept.png")
	quit()
