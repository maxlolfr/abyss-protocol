class_name AbyssAudio
extends Node
## Son d'ABYSS PROTOCOL (lot audio 01 de Max, docs/AUDIO_DIRECTION.md) :
## bus Music / Ambience / SFX / UI, deux lecteurs de musique en fondu enchaîné, ambiance du labo en boucle,
## bruitages positionnés (écouteur au centre de la vue, pas à la caméra orthographique lointaine),
## anti-doublon par événement, légère variation de hauteur. Le son réagit aux événements de la simulation
## et ne la modifie jamais. Les ennemis cachés ne s'entendent pas en 3D (sons joués non positionnés).

const DIR := "res://assets/audio/%s/%s.ogg"
const BUSES := {"Music": -7.0, "Ambience": -11.0, "SFX": -2.0, "UI": -6.0}
const SFX := ["airlock", "alien_plasma", "armor_impact", "artifact_pulse", "grenade_blast", "harpoon_fire",
	"nereid_alert", "rifle_fire", "sonar_signature", "spectre_psionic", "step_metal", "ui_confirm"]

var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _track := ""
var _amb := AudioStreamPlayer.new()
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}
var listener := AudioListener3D.new()
var enabled := true
var played := {} # compteur par bruitage (contrôle automatique)

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), BUSES[b])
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	_amb.bus = "Ambience"
	add_child(_amb)
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

## Musique : "mus_01_abyss_protocol" (titre), "mus_02_silent_depths" (exploration), "mus_03_contact_hostile" (combat).
func music(track: String, fade := 1.5) -> void:
	if track == _track:
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
		_amb.stream = load(DIR % ["ambience", "amb_01_lab_pressure"])
		_amb.play()
	elif not on:
		_amb.stop()

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

func ui() -> void:
	if not enabled:
		return
	var p := _free(_pool2d)
	p.bus = "UI"
	p.stream = _streams["ui_confirm"]
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()
	p.finished.connect(func(): p.bus = "SFX", CONNECT_ONE_SHOT)

func _free(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]

func set_enabled(on: bool) -> void:
	enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)
