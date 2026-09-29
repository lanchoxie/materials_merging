extends Node
## Global sound player (autoload "Sfx").
## Sounds are synthesized by dev/gen_audio.py into res://assets/audio/<name>.wav.
## Missing sounds are ignored so gameplay never depends on audio being present.

const AUDIO_DIR = "res://assets/audio/"
const SETTINGS_PATH = "user://settings.cfg"
const VOICES = 14
const RETRIGGER_SECONDS = 0.035

## Per-sound base volume (dB) and random pitch spread, tuned by ear against each other.
const MIX = {
	"tap": [-9.0, 0.06], "coin": [-8.0, 0.04], "harvest": [-5.0, 0.02], "sell": [-4.0, 0.0],
	"build": [-4.0, 0.03], "upgrade": [-3.0, 0.0], "perfect": [-3.0, 0.0], "error": [-8.0, 0.0],
	"ui": [-14.0, 0.05], "whoosh": [-10.0, 0.05], "discovery": [-3.0, 0.0], "chop": [-5.0, 0.08],
	"dig": [-6.0, 0.08], "step": [-16.0, 0.12], "pop": [-9.0, 0.08], "tick": [-15.0, 0.0],
	"hit": [-5.0, 0.07], "open": [-9.0, 0.0], "close": [-10.0, 0.0],
}

var enabled: bool = true
var sfx_volume: float = 1.0
var music_volume: float = 0.6
var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _ambience: Array[AudioStreamPlayer] = []
var _ambience_name: String = ""
var _ambience_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in range(VOICES):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	for i in range(2):
		var a = AudioStreamPlayer.new()
		a.bus = "Music"
		a.volume_db = -80.0
		add_child(a)
		_ambience.append(a)
	_load_settings()
	_apply_volumes()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1: return
	AudioServer.add_bus()
	var index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func has_sound(sound: String) -> bool:
	return _stream(sound) != null

func _stream(sound: String) -> AudioStream:
	if _cache.has(sound): return _cache[sound]
	var path = AUDIO_DIR + sound + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[sound] = stream
	return stream

## Play a one-shot. `pitch` multiplies the base pitch (use it for rising combos/meters).
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not enabled or _voices.is_empty(): return
	var now = Time.get_ticks_msec() / 1000.0
	# Many identical triggers in one burst (e.g. harvest-all) should read as one sound.
	if now - float(_last_played.get(sound, -1.0)) < RETRIGGER_SECONDS: return
	var stream = _stream(sound)
	if stream == null: return
	_last_played[sound] = now
	var mix: Array = MIX.get(sound, [-8.0, 0.0])
	var voice = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = float(mix[0]) + volume_db
	voice.pitch_scale = clampf(pitch * (1.0 + randf_range(-float(mix[1]), float(mix[1]))), 0.25, 4.0)
	voice.play()

## Cross-fade to a looping ambience ("" fades out).
func ambience(sound: String, fade: float = 1.2) -> void:
	if sound == _ambience_name: return
	_ambience_name = sound
	if _ambience_tween: _ambience_tween.kill()
	var outgoing = _ambience[0]
	var incoming = _ambience[1]
	_ambience.reverse()
	_ambience_tween = create_tween().set_parallel(true)
	_ambience_tween.tween_property(outgoing, "volume_db", -80.0, fade)
	var stream = _stream(sound) if not sound.is_empty() else null
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if stream != null:
		incoming.stream = stream
		incoming.volume_db = -60.0
		incoming.play()
		_ambience_tween.tween_property(incoming, "volume_db", -6.0, fade)
	_ambience_tween.chain().tween_callback(outgoing.stop)

func set_enabled(value: bool) -> void:
	enabled = value
	_apply_volumes()
	_save_settings()

func toggle() -> bool:
	set_enabled(not enabled)
	return enabled

func _apply_volumes() -> void:
	var master = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, not enabled)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK: return
	enabled = bool(cfg.get_value("audio", "enabled", true))
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.6)), 0.0, 1.0)

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "enabled", enabled)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)
