extends SceneTree
## Partie automatique complète avec rendu des événements (sans écran) : détecte les erreurs de la vue.
## godot --headless --path . -s res://tests/play_smoke.gd
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var main: Node = load("res://view/main.tscn").instantiate()
	main.show_intro = false
	root.add_child(main)
	await process_frame
	print("départ : ", main.battle.outcome, " carte ", main.battle.map_id, " tour ", main.battle.turn)
	Engine.time_scale = 8.0
	main.speed = 4.0
	main._autoplay()
	var t0 := Time.get_ticks_msec()
	while main.battle.outcome == "ongoing" and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	print("partie vue : %s au tour %d (%d ms)" % [main.battle.outcome, main.battle.turn, Time.get_ticks_msec() - t0])
	quit()
