extends Node

# AudioManager.gd
# Autoload singleton handling music crossfading, sfx pooling, and bus management.

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS & ENUMS
# ─────────────────────────────────────────────────────────────────────────────
enum MusicTrack {
	MENU, ROUND_1, ROUND_2, ROUND_3, ROUND_4, ROUND_5,
	ROUND_6, ROUND_7, VICTORY, GAME_OVER
}

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
var music_volume: float = 0.0
var sfx_volume: float = 0.0
const SETTINGS_FILE: String = "user://audio_settings.cfg"

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer3D] = []
var _sfx_idx: int = 0
var _crossfade_tween: Tween
var _ui_sfx_player: AudioStreamPlayer
var _starting_sfx_player: AudioStreamPlayer

var _active_generators: Array[Dictionary] = [] # Tracks AudioStreamGeneratorPlaybacks for fallbacks

# ─────────────────────────────────────────────────────────────────────────────
# REGISTRIES
# ─────────────────────────────────────────────────────────────────────────────
var music_tracks: Dictionary = {
	MusicTrack.MENU: null,
	MusicTrack.ROUND_1: null,
	MusicTrack.ROUND_2: null,
	MusicTrack.ROUND_3: null,
	MusicTrack.ROUND_4: null,
	MusicTrack.ROUND_5: null,
	MusicTrack.ROUND_6: null,
	MusicTrack.ROUND_7: null,
	MusicTrack.VICTORY: null,
	MusicTrack.GAME_OVER: null,
}

var sfx_registry: Dictionary = {
	"jump": null, "land": null, "dive": null, "ragdoll_hit": null, "momo_collect": null,
	"boulder_roll": null, "wind_whoosh": null, "bell_ring": null, "door_open": null, "door_slam": null,
	"tile_crack": null, "tile_fall": null, "victory_fanfare": null, "countdown_beep": null, "round_start": null
}

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_buses()
	_load_settings()
	
	# Setup Music Players
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_a.volume_db = -80.0
	add_child(_music_a)
	
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	_music_b.volume_db = -80.0
	add_child(_music_b)
	
	_current_player = _music_a
	
	# Setup UI SFX Player
	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.bus = "UI"
	add_child(_ui_sfx_player)

	# Setup Starting SFX Player (so it can be stopped separately)
	_starting_sfx_player = AudioStreamPlayer.new()
	_starting_sfx_player.bus = "UI"
	add_child(_starting_sfx_player)
	
	# Setup SFX Pool
	for i in range(8):
		var p = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _process(_delta: float) -> void:
	# Feed procedural AudioStreamGenerators (if fallbacks are being used)
	for i in range(_active_generators.size() - 1, -1, -1):
		var gen_data = _active_generators[i]
		var player = gen_data.player
		
		# Remove if finished or destroyed
		if not is_instance_valid(player) or not player.playing:
			_active_generators.remove_at(i)
			continue
			
		var playback = gen_data.playback as AudioStreamGeneratorPlayback
		if not playback:
			continue
			
		var frames = playback.get_frames_available()
		if frames > 0:
			var phase = gen_data.phase
			var freq = gen_data.freq
			var phase_inc = freq / 44100.0
			for j in range(frames):
				var val = sin(phase * TAU) * 0.1
				playback.push_frame(Vector2(val, val))
				phase = fmod(phase + phase_inc, 1.0)
			gen_data.phase = phase

# ─────────────────────────────────────────────────────────────────────────────
# SETUP & SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
func _setup_buses() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx == -1: return
	
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus(1)
		music_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
		AudioServer.set_bus_volume_db(music_idx, -6.0)
		
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus(2)
		sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
		AudioServer.set_bus_volume_db(sfx_idx, 0.0)
		
	var ui_idx = AudioServer.get_bus_index("UI")
	if ui_idx == -1:
		AudioServer.add_bus(3)
		ui_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(ui_idx, "UI")
		AudioServer.set_bus_send(ui_idx, "Master")
		AudioServer.set_bus_volume_db(ui_idx, 0.0)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		music_volume = cfg.get_value("audio", "music_volume", 0.0)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 0.0)
		
		var music_idx = AudioServer.get_bus_index("Music")
		if music_idx != -1: AudioServer.set_bus_volume_db(music_idx, music_volume - 6.0)
		var sfx_idx = AudioServer.get_bus_index("SFX")
		if sfx_idx != -1: AudioServer.set_bus_volume_db(sfx_idx, sfx_volume)

func set_music_volume_db(db: float) -> void:
	music_volume = db
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, db - 6.0)
	_save_settings()

func set_sfx_volume_db(db: float) -> void:
	sfx_volume = db
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, db)
	_save_settings()

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_FILE)

# ─────────────────────────────────────────────────────────────────────────────
# MUSIC CROSSFADE
# ─────────────────────────────────────────────────────────────────────────────
func play_track(track: MusicTrack, crossfade_time: float = 1.5) -> void:
	var stream = music_tracks.get(track)
	var is_procedural = false
	if not stream:
		stream = AudioStreamGenerator.new()
		stream.mix_rate = 44100
		is_procedural = true
		
	play_music(stream, crossfade_time)
	
	if is_procedural:
		_active_generators.append({
			"player": _current_player,
			"playback": _current_player.get_stream_playback(),
			"phase": 0.0,
			"freq": 220.0
		})

func play_music(stream: AudioStream, crossfade_time: float = 1.5) -> void:
	var next_player: AudioStreamPlayer
	if _current_player == _music_a:
		next_player = _music_b
	else:
		next_player = _music_a
		
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	
	if _crossfade_tween:
		_crossfade_tween.kill()
		
	_crossfade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	
	if _current_player.playing:
		_crossfade_tween.tween_property(_current_player, "volume_db", -80.0, crossfade_time)
	
	_crossfade_tween.tween_property(next_player, "volume_db", 0.0, crossfade_time)
	
	_crossfade_tween.chain().tween_callback(func():
		_current_player.stop()
		_current_player = next_player
	)

# ─────────────────────────────────────────────────────────────────────────────
# SFX POOL
# ─────────────────────────────────────────────────────────────────────────────
func play_sfx(sfx_name: String, world_pos: Vector3 = Vector3.ZERO) -> void:
	var stream = sfx_registry.get(sfx_name)
	var freq: float = 0.0
	var is_procedural = false
	
	if not stream:
		freq = 200.0 + (hash(sfx_name) % 600)
		stream = AudioStreamGenerator.new()
		stream.mix_rate = 44100
		stream.buffer_length = 0.1
		is_procedural = true
		
	var player = _sfx_pool[_sfx_idx]
	player.stream = stream
	player.global_position = world_pos
	player.play()
	
	if is_procedural:
		_active_generators.append({
			"player": player,
			"playback": player.get_stream_playback(),
			"phase": 0.0,
			"freq": freq
		})
		
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOM SFX HELPERS (Added for Yeti tasks)
# ─────────────────────────────────────────────────────────────────────────────

func play_round_background() -> void:
	var bg = load("res://assets/fruits/sound_Effects/background.MP3")
	if bg:
		play_music(bg, 1.5)

func stop_round_background() -> void:
	if _crossfade_tween:
		_crossfade_tween.kill()
	_crossfade_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_crossfade_tween.tween_property(_current_player, "volume_db", -80.0, 1.5)
	_crossfade_tween.tween_callback(func(): _current_player.stop())

func play_victory_sfx() -> void:
	var stream = load("res://assets/fruits/sound_Effects/party_popper.mp3")
	if stream and _ui_sfx_player:
		_ui_sfx_player.stream = stream
		_ui_sfx_player.play()

func play_momo_collect() -> void:
	var stream = load("res://assets/fruits/sound_Effects/MomoMaja.MP3")
	if stream and _ui_sfx_player:
		_ui_sfx_player.stream = stream
		_ui_sfx_player.play()

func play_death_sfx() -> void:
	var stream = load("res://assets/fruits/sound_Effects/Mario Death - Sound Effect (HD).mp3")
	if stream and _ui_sfx_player:
		_ui_sfx_player.stream = stream
		_ui_sfx_player.play()

func play_game_over_sfx() -> void:
	var stream = load("res://assets/fruits/sound_Effects/Mario Death - Sound Effect (HD).mp3")
	if stream and _ui_sfx_player:
		_ui_sfx_player.stream = stream
		_ui_sfx_player.play()

func play_starting_sfx() -> void:
	var stream = load("res://assets/fruits/sound_Effects/Starting.MP3")
	if stream and _starting_sfx_player:
		_starting_sfx_player.stream = stream
		_starting_sfx_player.play()

func stop_starting_sfx() -> void:
	if _starting_sfx_player and _starting_sfx_player.playing:
		_starting_sfx_player.stop()

