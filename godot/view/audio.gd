class_name AbyssAudio
extends Node
## Son d'ABYSS PROTOCOL (lots audio 01 à 03 de Max, docs/AUDIO_DIRECTION.md, docs/AUDIO-LOT03.md) :
## bus Music / Ambience / SFX / UI / Voice / Radio, deux lecteurs de musique en fondu enchaîné, ambiance par carte,
## bruitages positionnés (écouteur au centre de la vue, pas à la caméra orthographique lointaine),
## anti-doublon par événement, légère variation de hauteur, banques de pas par matériau sans répétition,
## messages radio en file d'attente avec priorité. Le son réagit aux événements de la simulation
## et ne la modifie jamais. Les ennemis cachés ne s'entendent pas en 3D (sons joués non positionnés).

const DIR := "res://assets/audio/%s/%s.ogg"
const BUSES := {"Music": -7.0, "Ambience": -11.0, "SFX": -2.0, "UI": -6.0, "Voice": -4.0, "Radio": -3.0}
const SFX := ["airlock", "alarm_intruder", "alarm_pressure", "alien_plasma", "armor_impact", "artifact_pulse", "boss_arrival",
	"bullet_ricochet", "carapace_alert", "carapace_hit", "cover_break", "crate_open", "door_locked", "elevator_start",
	"elevator_stop", "empty_weapon", "gear_rustle", "generator_start", "glass_break", "grenade_blast", "harpoon_fire",
	"hull_breach", "medkit", "nereid_alert", "nereid_move", "objective_complete", "radio_static", "reload_harpoon",
	"reload_rifle", "rifle_fire", "sonar_signature", "spectre_move", "spectre_psionic", "terminal_access", "terminal_hack",
	"ui_confirm", "ui_error", "ui_turn_end"]
## Banques de pas (fichiers égalisés en niveau, lot 03) ; correction de niveau par matériau.
const STEPS := {"metal": ["step_metal", "step_metal_02", "step_metal_03", "step_metal_04"],
	"concrete": ["step_concrete_01", "step_concrete_02", "step_concrete_03"],
	"water": ["step_water_01", "step_water_02", "step_water_03"]}
const STEP_GAIN := {"metal": 0.0, "concrete": 9.0, "water": 0.0}
## Par carte : ambiance, musique d'exploration, sol.
const MAPS := {"nemesis": ["amb_01_lab_pressure", "mus_02_silent_depths", "metal"],
	"lab": ["amb_04_open_abyss", "mus_05_deep_descent", "metal"],
	"port": ["amb_02_flooded_corridor", "mus_02_silent_depths", "concrete"],
	"nid": ["amb_05_alien_chamber", "mus_05_deep_descent", "water"]}
## Pistes dont le raccord est intégré (boucle Godot). Les autres sont relancées en fondu enchaîné
## (pas de raccord sec tant que Max ne les a pas validées à l'écoute). La 07 est jouée une seule fois.
const SEAMLESS := ["mus_01_abyss_protocol", "mus_02_silent_depths", "mus_03_contact_hostile"]
const ONCE := ["mus_07_mission_debrief"]
## Rang des états musicaux en mission : une demande plus calme n'écrase pas un état plus tendu.
const RANK := {"mus_02_silent_depths": 1, "mus_05_deep_descent": 1, "mus_03_contact_hostile": 2,
	"mus_06_extraction": 3, "mus_08_boss_encounter": 4, "mus_09_last_stand": 5}
## Priorité radio (plus haut = passe devant dans la file).
const RADIO_PRIO := {"radio_pressure": 9, "radio_abort": 9, "radio_extract": 8, "radio_extraction_ready": 8,
	"radio_reinforcements": 6, "radio_contact": 5, "radio_objective": 5, "radio_mission_success": 7,
	"radio_terminal": 3, "radio_artifact": 2, "radio_mission_start": 4, "radio_move": 1}

var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _track := ""
var _amb := AudioStreamPlayer.new()
var _amb2 := AudioStreamPlayer.new()
var _amb_name := ""
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}
var listener := AudioListener3D.new()
var enabled := true
var played := {} # compteur par bruitage (contrôle automatique)
var map_id := "nemesis"
var _ended := false
# voix
var _radio := AudioStreamPlayer.new()
var _voice := AudioStreamPlayer.new()
var _queue: Array = [] # [nom, priorité]
var _said := {} # répliques déjà dites dans cette mission (une fois par événement validé)
var _bark_at := -100000
var _step_last := {} # "unité|matériau" -> dernière variante
var _humans0 := 0
var _contact := false

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			if b == "Radio": # filtre de transmission : passe-haut 300 Hz, passe-bas 3 kHz, compression légère
				var hp := AudioEffectHighPassFilter.new(); hp.cutoff_hz = 300.0
				var lp := AudioEffectLowPassFilter.new(); lp.cutoff_hz = 3000.0
				var co := AudioEffectCompressor.new(); co.threshold = -18.0; co.ratio = 3.0
				for fx in [hp, lp, co]:
					AudioServer.add_bus_effect(i, fx)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), BUSES[b])
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	for p in [_amb, _amb2]:
		p.bus = "Ambience"
		add_child(p)
	_radio.bus = "Radio"
	add_child(_radio)
	_radio.finished.connect(_next_radio)
	_voice.bus = "Voice"
	add_child(_voice)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 40.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in 5:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for s in SFX:
		_streams[s] = load(DIR % ["sfx", "sfx_" + s])
	for bank in STEPS.values():
		for s in bank:
			_streams[s] = load(DIR % ["sfx", "sfx_" + s])
	var b = get_parent().get("battle") if get_parent() else null # scène de combat : carte en cours
	if b != null and MAPS.has(String(b.map_id)):
		map_id = b.map_id
		_humans0 = b.living(true).size()

## Relance en fondu des pistes non validées en boucle sèche (musique et ambiance).
func _process(_dt: float) -> void:
	var m := _music[_cur]
	if m.playing and m.stream and not (_track in SEAMLESS or _track in ONCE) and m.stream.get_length() - m.get_playback_position() < 2.0:
		var t := _track
		_track = ""
		music(t, 2.0)
	if _amb_name != "" and _amb.playing and _amb.stream.get_length() - _amb.get_playback_position() < 2.0:
		var keep := _amb
		_amb = _amb2
		_amb2 = keep
		_amb.stream = keep.stream
		_amb.volume_db = -30.0
		_amb.play()
		var tw := create_tween().set_parallel()
		tw.tween_property(_amb, "volume_db", 0.0, 2.0)
		tw.tween_property(keep, "volume_db", -30.0, 2.0)
		tw.chain().tween_callback(keep.stop)

## Musique : "mus_01_abyss_protocol" (titre), exploration (02 ou 05 selon la carte), combat (03), base (04),
## extraction (06), débriefing (07, une fois), boss (08), dernier carré (09).
func music(track: String, fade := 1.5) -> void:
	if _ended and track == "mus_01_abyss_protocol":
		track = "mus_07_mission_debrief" # fin de mission : débriefing joué une fois au lieu du titre
	if track == "mus_02_silent_depths" and MAPS.has(map_id):
		track = MAPS[map_id][1]
	if track == _track:
		return
	if not _ended and int(RANK.get(track, 0)) > 0 and int(RANK.get(track, 0)) < int(RANK.get(_track, 0)):
		return
	_track = track
	var old := _music[_cur]
	_cur = 1 - _cur
	var nw := _music[_cur]
	nw.stream = load(DIR % ["music", track])
	nw.volume_db = -40.0
	nw.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(nw, "volume_db", 0.0, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)

func ambience(on: bool) -> void:
	if on and not _amb.playing:
		_amb_name = MAPS.get(map_id, MAPS["nemesis"])[0]
		_amb.stream = load(DIR % ["ambience", _amb_name])
		_amb.volume_db = 0.0
		_amb.play()
		if not _said.has("start"): # début de mission : ouverture radio
			_said["start"] = true
			radio("radio_mission_start")
			if map_id in ["nemesis", "nid"]:
				radio("radio_artifact")
	elif not on:
		_amb_name = ""
		_amb.stop()
		_amb2.stop()

## Bruitage. `at` : position 3D si l'événement est visible par le joueur, sinon null (non positionné).
func sfx(name: String, at: Variant = null, vol_db := 0.0, pitch := 1.0, vary := 0.06) -> void:
	if not enabled or not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 45: # anti-doublon (plusieurs événements dans la même image)
		return
	_last[name] = now
	played[name] = int(played.get(name, 0)) + 1
	var p: Node
	if at is Vector3:
		p = _free(_pool3d)
		(p as AudioStreamPlayer3D).global_position = at
	else:
		p = _free(_pool2d)
	p.set("stream", _streams[name])
	p.set("volume_db", vol_db)
	p.set("pitch_scale", pitch * randf_range(1.0 - vary, 1.0 + vary))
	p.call("play")

## Son d'interface (bus UI) : "ui_confirm", "ui_error", "ui_turn_end".
func ui(name := "ui_confirm") -> void:
	if not enabled or not _streams.has(name):
		return
	played[name] = int(played.get(name, 0)) + 1
	var p := _free(_pool2d)
	p.bus = "UI"
	p.stream = _streams[name]
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()
	p.finished.connect(func(): p.bus = "SFX", CONNECT_ONE_SHOT)

## Pas : créature selon son espèce, sinon banque du sol de la carte, sans rejouer la même variante pour l'unité.
func step(u: AbyssUnit, at: Vector3) -> void:
	match u.kind:
		"spectre":
			sfx("spectre_move", at, -12.0, 1.0, 0.08)
			return
		"nereide":
			sfx("nereid_move", at, -10.0, 1.0, 0.1)
			return
	var mat: String = MAPS.get(map_id, MAPS["nemesis"])[2]
	var bank: Array = STEPS[mat]
	var key := u.id + "|" + mat
	var choice: String = bank[0]
	if bank.size() > 1:
		var others := bank.filter(func(s): return s != _step_last.get(key, ""))
		choice = others[randi() % others.size()]
	_step_last[key] = choice
	_last.erase(choice) # deux unités peuvent marcher dans la même image
	sfx(choice, at, (-9.0 if u.human else -11.0) + STEP_GAIN[mat], 1.0 if u.human else 0.75, 0.05)

## Réplique de soldat (bus Voice), espacée pour ne pas saturer.
func bark(name: String, gap_ms := 5000) -> void:
	var now := Time.get_ticks_msec()
	if not enabled or _voice.playing or now - _bark_at < gap_ms:
		return
	_bark_at = now
	played[name] = int(played.get(name, 0)) + 1
	_voice.stream = load(DIR % ["voice/soldiers", "soldier_" + name])
	_voice.play()

## Message du commandement (bus Radio, non positionné), en file d'attente par priorité, une fois par mission.
func radio(name: String, once := true) -> void:
	if not enabled or (once and _said.has(name)):
		return
	_said[name] = true
	var pr := int(RADIO_PRIO.get(name, 0))
	var i := 0
	while i < _queue.size() and int(_queue[i][1]) >= pr:
		i += 1
	_queue.insert(i, [name, pr])
	if not _radio.playing:
		_next_radio()

func _next_radio() -> void:
	var mb := AudioServer.get_bus_index("Music")
	if _queue.is_empty():
		if _ducked:
			AudioServer.set_bus_volume_db(mb, AudioServer.get_bus_volume_db(mb) + 4.0)
		_ducked = false
		return
	var n: String = _queue.pop_front()[0]
	played[n] = int(played.get(n, 0)) + 1
	if not _ducked: # la musique baisse sous la voix
		_ducked = true
		AudioServer.set_bus_volume_db(mb, AudioServer.get_bus_volume_db(mb) - 4.0)
	sfx("radio_static", null, -14.0, 1.0, 0.0)
	_radio.stream = load(DIR % ["voice/radio", n])
	_radio.play()

var _ducked := false

## Événements de combat : sons ajoutés par le lot 03 (les bruitages du lot 01 restent joués par main.gd).
## `where` : Callable(AbyssUnit) -> Vector3 ou null si l'unité n'est pas visible.
func event(e: Dictionary, battle: AbyssBattle, where: Callable) -> void:
	if not enabled:
		return
	match String(e["t"]):
		"spotted":
			var u := battle.unit(e["unit"])
			if u.kind == "carapace":
				sfx("carapace_alert", where.call(u), -3.0)
			if map_id == "nid" and not _said.has("boss") and u.kind in ["carapace", "spectre"]:
				_said["boss"] = true # le gardien du Nid
				sfx("boss_arrival", null, -2.0)
				music("mus_08_boss_encounter", 1.5)
			if not _contact:
				_contact = true
				radio("radio_contact")
			if battle.side == "human":
				bark("contact", 6000)
		"interrupt":
			if battle.unit(e["unit"]).human:
				bark("contact", 4000)
		"move":
			var u := battle.unit(e["unit"])
			if u.human and u.carrying and e["to"] in battle.evac:
				radio("radio_extraction_ready")
		"shot":
			var u := battle.unit(e["unit"])
			var victim := battle.units.filter(func(x): return x.cell == e["to"])
			if not e["hit"] and e["weapon"] in ["rifle", "pistol"]:
				sfx("bullet_ricochet", null, -10.0, 1.0, 0.15)
			elif e["hit"] and not victim.is_empty() and victim[0].kind == "carapace":
				sfx("carapace_hit", where.call(victim[0]), -2.0)
			if u.human and u.ammo <= 1 and AbyssData.WEAPONS[u.weapon].get("mag", 0) > 0 and not _said.has("ammo_" + u.id):
				_said["ammo_" + u.id] = true
				if u.ammo == 0:
					sfx("empty_weapon", where.call(u), -4.0)
				bark("low_ammo", 2000)
		"damage":
			var u := battle.unit(e["unit"])
			if u.human and e["amount"] > 0 and e["hp"] > 0:
				bark("wounded", 3000)
		"death":
			var u := battle.unit(e["unit"])
			if u.human:
				_bark_at = -100000
				bark("down", 0)
				var alive := battle.living(true).filter(func(x): return not x.evacuated)
				if _humans0 > 1 and alive.size() == 1 and battle.outcome == "ongoing":
					music("mus_09_last_stand", 1.5) # dernier carré
					radio("radio_abort")
		"destroy":
			sfx("cover_break", null, -4.0)
			if not _said.has("breach"):
				_said["breach"] = true # première cloison percée : la station prend l'eau
				sfx("hull_breach", null, -4.0)
				sfx("alarm_pressure", null, -12.0, 1.0, 0.0)
				radio("radio_pressure")
		"heal":
			sfx("medkit", where.call(battle.unit(e["target"])), -2.0)
		"reload":
			var u := battle.unit(e["unit"])
			sfx("reload_harpoon" if u.weapon == "harpoon" else "reload_rifle", where.call(u), -3.0)
			_said.erase("ammo_" + u.id)
		"kneel", "watch":
			sfx("gear_rustle", where.call(battle.unit(e["unit"])), 0.0)
			if e["t"] == "watch":
				bark("ack", 8000)
		"pickup":
			sfx("objective_complete", null, -4.0)
			radio("radio_objective")
		"alarm":
			sfx("alarm_intruder", null, -10.0, 1.0, 0.0)
			music("mus_06_extraction", 1.5)
			radio("radio_extract")
		"spawn":
			radio("radio_reinforcements")
		"logs":
			sfx("terminal_hack", null, -8.0)
			sfx("terminal_access", null, -4.0)
			radio("radio_terminal")
		"turn":
			if e["side"] == "alien":
				ui("ui_turn_end")
			elif e["turn"] == 2 and not _contact:
				radio("radio_move")
		"outcome":
			_ended = true
			if e["outcome"] == "victory":
				radio("radio_mission_success")
			else:
				radio("radio_abort")

## Géoscape et base : musique de commandement, alertes et sons d'interface.
func strategy_events(ev: Array) -> void:
	for e in ev:
		match String(e.get("t", "")):
			"error":
				ui("ui_error")
			"contact", "site":
				sfx("sonar_signature", null, -6.0)
			"intercept", "assault":
				sfx("alarm_intruder", null, -12.0, 1.0, 0.0)
			"intercept_result":
				sfx("harpoon_fire", null, -4.0)
			"research":
				sfx("terminal_access", null, -4.0)
			"room":
				sfx("generator_start", null, -6.0)
			"made", "craft":
				sfx("crate_open", null, -4.0)
			"report":
				sfx("radio_static", null, -10.0)
			"campaign_end":
				music("mus_07_mission_debrief", 2.0)

## Clic sur n'importe quel bouton de la scène (géoscape) : son de confirmation.
func click_buttons() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(ui):
		(n as BaseButton).pressed.connect(ui)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if _ducked: # ne pas laisser la musique baissée en changeant de scène
		var mb := AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(mb, AudioServer.get_bus_volume_db(mb) + 4.0)
		_ducked = false

func _free(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]

func set_enabled(on: bool) -> void:
	enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)
