extends Control

## SettingsScreen.gd
## Overlay screen managing graphics, audio, controls, and game settings.

const SETTINGS_FILE: String = "user://settings.cfg"

# ── Graphics Tab ──
@onready var window_mode: OptionButton = %WindowMode if has_node("%WindowMode") else find_child("WindowMode")
@onready var resolution: OptionButton = %Resolution if has_node("%Resolution") else find_child("Resolution")
@onready var render_scale: HSlider = %RenderScale if has_node("%RenderScale") else find_child("RenderScale")
@onready var vsync: CheckBox = %VSync if has_node("%VSync") else find_child("VSync")

# ── Audio Tab ──
@onready var master_vol: HSlider = %MasterVol if has_node("%MasterVol") else find_child("MasterVol")
@onready var music_vol: HSlider = %MusicVol if has_node("%MusicVol") else find_child("MusicVol")
@onready var sfx_vol: HSlider = %SFXVol if has_node("%SFXVol") else find_child("SFXVol")

# ── Controls Tab ──
@onready var mouse_sensitivity: HSlider = %MouseSensitivity if has_node("%MouseSensitivity") else find_child("MouseSensitivity")
@onready var rebind_grid: GridContainer = %RebindGrid if has_node("%RebindGrid") else find_child("RebindGrid")
var _listening_action: String = ""
var _listening_button: Button = null

# ── Game Tab ──
@onready var show_fps: CheckBox = %ShowFPS if has_node("%ShowFPS") else find_child("ShowFPS")
@onready var show_ping: CheckBox = %ShowPing if has_node("%ShowPing") else find_child("ShowPing")
@onready var language: OptionButton = %Language if has_node("%Language") else find_child("Language")

func _ready() -> void:
	_connect_signals()
	_populate_rebind_table()
	_load_settings()

func _connect_signals() -> void:
	if window_mode: window_mode.item_selected.connect(_on_setting_changed)
	if resolution: resolution.item_selected.connect(_on_setting_changed)
	if render_scale: render_scale.value_changed.connect(_on_setting_changed)
	if vsync: vsync.toggled.connect(_on_setting_changed)
	
	if master_vol: master_vol.value_changed.connect(_on_audio_changed)
	if music_vol: music_vol.value_changed.connect(_on_music_changed)
	if sfx_vol: sfx_vol.value_changed.connect(_on_sfx_changed)
	
	if mouse_sensitivity: mouse_sensitivity.value_changed.connect(_on_setting_changed)
	
	if show_fps: show_fps.toggled.connect(_on_setting_changed)
	if show_ping:
		show_ping.toggled.connect(_on_setting_changed)
		if GameManager and not GameManager.is_multiplayer:
			show_ping.hide()
			
	if language: language.item_selected.connect(_on_setting_changed)
	
	var close_btn = find_child("CloseButton", true, false)
	if close_btn:
		close_btn.pressed.connect(func(): queue_free())

func _on_setting_changed(_val = null) -> void:
	_apply_settings()
	_save_settings()

func _on_audio_changed(val: float) -> void:
	var idx = AudioServer.get_bus_index("Master")
	if idx != -1: AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))
	_save_settings()

func _on_music_changed(val: float) -> void:
	if AudioManager: AudioManager.set_music_volume_db(linear_to_db(val / 100.0))
	_save_settings()

func _on_sfx_changed(val: float) -> void:
	if AudioManager: AudioManager.set_sfx_volume_db(linear_to_db(val / 100.0))
	_save_settings()

func _apply_settings() -> void:
	if window_mode:
		match window_mode.selected:
			0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN) 
			2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	if resolution:
		match resolution.selected:
			0: DisplayServer.window_set_size(Vector2i(1280, 720))
			1: DisplayServer.window_set_size(Vector2i(1920, 1080))
			2: DisplayServer.window_set_size(Vector2i(2560, 1440))
			
	if render_scale:
		get_viewport().scaling_3d_scale = render_scale.value / 100.0
		
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync.button_pressed else DisplayServer.VSYNC_DISABLED)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		if window_mode: window_mode.selected = cfg.get_value("graphics", "window_mode", 1)
		if resolution: resolution.selected = cfg.get_value("graphics", "resolution", 1)
		if render_scale: render_scale.value = cfg.get_value("graphics", "render_scale", 100)
		if vsync: vsync.button_pressed = cfg.get_value("graphics", "vsync", true)
		
		if master_vol: master_vol.value = cfg.get_value("audio", "master_vol", 100)
		if music_vol: music_vol.value = cfg.get_value("audio", "music_vol", 100)
		if sfx_vol: sfx_vol.value = cfg.get_value("audio", "sfx_vol", 100)
		
		if mouse_sensitivity: mouse_sensitivity.value = cfg.get_value("controls", "mouse_sens", 0.005)
		if show_fps: show_fps.button_pressed = cfg.get_value("game", "show_fps", false)
		if show_ping: show_ping.button_pressed = cfg.get_value("game", "show_ping", false)
		if language: language.selected = cfg.get_value("game", "language", 0)
	
	_apply_settings()

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	if window_mode: cfg.set_value("graphics", "window_mode", window_mode.selected)
	if resolution: cfg.set_value("graphics", "resolution", resolution.selected)
	if render_scale: cfg.set_value("graphics", "render_scale", render_scale.value)
	if vsync: cfg.set_value("graphics", "vsync", vsync.button_pressed)
	
	if master_vol: cfg.set_value("audio", "master_vol", master_vol.value)
	if music_vol: cfg.set_value("audio", "music_vol", music_vol.value)
	if sfx_vol: cfg.set_value("audio", "sfx_vol", sfx_vol.value)
	
	if mouse_sensitivity: cfg.set_value("controls", "mouse_sens", mouse_sensitivity.value)
	if show_fps: cfg.set_value("game", "show_fps", show_fps.button_pressed)
	if show_ping: cfg.set_value("game", "show_ping", show_ping.button_pressed)
	if language: cfg.set_value("game", "language", language.selected)
	
	cfg.save(SETTINGS_FILE)

func _populate_rebind_table() -> void:
	if not rebind_grid: return
	
	var actions = ["move_left", "move_right", "move_forward", "move_back", "jump", "dive", "emote_wave", "emote_dance", "emote_namaste", "emote_roar"]
	for child in rebind_grid.get_children():
		child.queue_free()
		
	for action in actions:
		var lbl = Label.new()
		lbl.text = action.capitalize()
		rebind_grid.add_child(lbl)
		
		var btn = Button.new()
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			btn.text = events[0].as_text()
		else:
			btn.text = "Unbound"
			
		btn.pressed.connect(func():
			_listening_action = action
			_listening_button = btn
			btn.text = "Press any key..."
		)
		rebind_grid.add_child(btn)

func _input(event: InputEvent) -> void:
	if _listening_action != "" and _listening_button != null:
		if event is InputEventKey and event.pressed:
			InputMap.action_erase_events(_listening_action)
			InputMap.action_add_event(_listening_action, event)
			_listening_button.text = event.as_text()
			_listening_action = ""
			_listening_button = null
			get_viewport().set_input_as_handled()
