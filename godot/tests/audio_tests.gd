extends SceneTree
## Contrôle du son (lot 03) : fichiers présents, musique par écran, file radio, pas sans répétition.
## godot --headless --path . -s res://tests/audio_tests.gd
var ok := 0
var ko := 0

func check(c: bool, what: String) -> void:
	if c:
		ok += 1
	else:
		ko += 1
		print("ÉCHEC : ", what)

func _initialize() -> void:
	# géoscape : musique de commandement, clic sur les boutons
	AbyssSession.mission = {}
	AbyssSession.result = {}
	var st: AbyssStrategy = load("res://view/strategy/strategy.tscn").instantiate()
	st.show_title = false
	root.add_child(st)
	await process_frame
	check(st.audio._track == "mus_04_command_center", "musique du géoscape")
	var b := Button.new()
	st.add_child(b)
	b.pressed.emit()
	check(int(st.audio.played.get("ui_confirm", 0)) >= 1, "clic de bouton")
	st.audio.strategy_events([{"t": "error", "text": "x"}])
	check(int(st.audio.played.get("ui_error", 0)) == 1, "son d'erreur")
	st.queue_free()
	await process_frame
	# combat
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	var main: Node = load("res://view/main.tscn").instantiate()
	main.show_intro = false
	root.add_child(main)
	await process_frame
	var a: AbyssAudio = main.audio
	for s in a._streams:
		check(a._streams[s] != null, "bruitage chargé : " + s)
	for d in ["voice/radio", "voice/soldiers", "music", "ambience"]:
		var n := 0
		for f in DirAccess.get_files_at("res://assets/audio/" + d):
			if f.ends_with(".ogg"):
				check(load("res://assets/audio/%s/%s" % [d, f]) != null, "chargé : " + f)
				n += 1
		check(n == {"voice/radio": 12, "voice/soldiers": 6, "music": 9, "ambience": 5}[d], "nombre de fichiers : " + d)
	check(a._track == "mus_02_silent_depths" and a._amb.playing, "exploration Némésis + ambiance")
	# file radio : priorité, une seule fois par mission
	a._queue.clear()
	a._radio.stop()
	a._said.erase("radio_move"); a._said.erase("radio_pressure"); a._said.erase("radio_terminal")
	a._radio.stream = load("res://assets/audio/voice/radio/radio_move.ogg")
	a._radio.play() # un message en cours : les suivants attendent
	a.radio("radio_terminal")
	a.radio("radio_pressure")
	a.radio("radio_terminal")
	check(a._queue.size() == 2 and a._queue[0][0] == "radio_pressure", "file radio triée par priorité, sans doublon")
	# musique : un état plus calme n'écrase pas un état plus tendu
	a.music("mus_06_extraction", 0.1)
	a.music("mus_03_contact_hostile", 0.1)
	check(a._track == "mus_06_extraction", "extraction gardée face au combat")
	a.music("mus_09_last_stand", 0.1)
	check(a._track == "mus_09_last_stand", "dernier carré")
	a.event({"t": "outcome", "outcome": "victory"}, main.battle, main._where)
	a.music("mus_01_abyss_protocol", 0.1)
	check(a._track == "mus_07_mission_debrief", "débriefing en fin de mission")
	# pas : jamais deux fois de suite la même variante pour une unité
	var u: AbyssUnit = main.battle.living(true)[0]
	var prev := ""
	var rep := 0
	for i in 40:
		a.step(u, Vector3.ZERO)
		var cur: String = a._step_last[u.id + "|metal"]
		if cur == prev:
			rep += 1
		prev = cur
	check(rep == 0, "pas sans répétition")
	print("Tests audio : %d réussis, %d échoués" % [ok, ko])
	quit(1 if ko > 0 else 0)
