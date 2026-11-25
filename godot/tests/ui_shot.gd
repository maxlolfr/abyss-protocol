extends SceneTree
## Captures de l'interface en jeu : xvfb-run godot --path . -s res://tests/ui_shot.gd -- dossier
## hud.png (cartes d'escouade avec états + fiche ennemi) et debrief.png (récapitulatif final).
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var main: Node = load("res://view/main.tscn").instantiate()
	main.show_intro = false
	root.add_child(main)
	for i in 30:
		await process_frame
	var b: AbyssBattle = main.battle
	b.unit("s1").kneeling = true
	b.unit("s2").watching = true
	b.unit("s3").wounds = 2
	b.unit("s3").hp = 14
	b.unit("s4").carrying = true
	main.hud.refresh(b, b.unit("s1"), "aimed", false)
	main.hud.set_preview("Tir précis · 24 UT · 54 % · couvert partiel · reste 36 UT", true)
	main.hud.show_foe(b.unit("a2"), 54)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/hud.png")
	b.outcome = "victory"
	b.turn = 6
	b.unit("s4").evacuated = true
	b.unit("s1").evacuated = true
	b.unit("s2").alive = false
	b.unit("s2").hp = 0
	b.unit("a1").alive = false
	b.unit("a3").alive = false
	b.logs_done = false
	main.hud.show_end(b)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/debrief.png")
	quit()
