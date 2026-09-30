extends Node
## Plays sound effects from res://assets/sfx/<name>.wav and owns the volume settings.
## The current sounds are synthesized placeholders; drop in real ones with the same names.

const DIR := "res://assets/sfx/"
const VOICES := 8
const SETTINGS_PATH := "user://settings.cfg"
## Baseline for every effect at 100% volume: a third of the previous level, so nobody has to
## turn it down on first launch.
const BASE_DB := -19.6

var master := 1.0  # 0..1.5, applied to the whole game
var effects := 1.0  # 0..1.5, applied to sound effects

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master = float(cfg.get_value("audio", "master", 1.0))
		effects = float(cfg.get_value("audio", "effects", 1.0))
	_apply()


func set_master(v: float) -> void:
	master = v
	_apply()
	_save()


func set_effects(v: float) -> void:
	effects = v
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(0, master <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.001)))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "effects", effects)
	cfg.save(SETTINGS_PATH)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if effects <= 0.0:
		return
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _streams[sound]
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = volume_db + BASE_DB + linear_to_db(effects)
	p.play()
