extends Control

var pulse_tween: Tween

func _ready() -> void:
	# Connect signals
	NetworkManager.player_list_changed.connect(_on_player_list_changed)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.all_players_ready.connect(_on_all_players_ready)
	NetworkManager.join_failed.connect(_on_join_failed)
	
	# Connect buttons
	%CopyCodeBtn.pressed.connect(_on_copy_code_btn_pressed)
	%ReadyBtn.pressed.connect(_on_ready_btn_pressed)
	%StartBtn.pressed.connect(_on_start_btn_pressed)
	%LeaveBtn.pressed.connect(_on_leave_btn_pressed)
	
	%StartBtn.resized.connect(_on_start_btn_resized)
	
	# Initialize room code display
	%RoomCodeLabel.text = NetworkManager.room_code
	
	_refresh_player_list()

func _refresh_player_list() -> void:
	# Clear %PlayerList
	for child in %PlayerList.get_children():
		child.queue_free()
		
	# Update player count
	var num_players = NetworkManager.players.size()
	%PlayerCountLabel.text = "PLAYERS (%d/%d)" % [num_players, NetworkManager.MAX_CLIENTS + 1]
	
	# Check ready status
	var all_ready = true
	
	for p_id in NetworkManager.players:
		var player_info = NetworkManager.players[p_id]
		var username = player_info.get("username", "Unknown")
		var uid = player_info.get("uid", "N/A")
		var is_ready = NetworkManager.player_ready.get(p_id, false)
		
		if not is_ready:
			all_ready = false
			
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		
		# ColorRect for avatar
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		
		# Seed random generator with peer ID
		var rng = RandomNumberGenerator.new()
		rng.seed = p_id
		color_rect.color = Color(
			rng.randf_range(0.2, 0.8),
			rng.randf_range(0.2, 0.8),
			rng.randf_range(0.2, 0.8)
		)
		row.add_child(color_rect)
		
		# Label for username and UID
		var name_label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p_id == 1:
			name_label.text = "👑 %s (%s)" % [username, uid]
		else:
			name_label.text = "%s (%s)" % [username, uid]
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)
		
		# Label for ready status
		var ready_label = Label.new()
		if is_ready:
			ready_label.text = "✅ READY"
			ready_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			ready_label.text = "⏳ Waiting"
			ready_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		ready_label.add_theme_font_size_override("font_size", 18)
		row.add_child(ready_label)
		
		%PlayerList.add_child(row)
		
	# Disable ready button if we are already ready
	var my_id = multiplayer.get_unique_id()
	var my_ready = NetworkManager.player_ready.get(my_id, false)
	%ReadyBtn.disabled = my_ready
	
	_update_action_buttons(all_ready)

func _update_action_buttons(all_ready: bool) -> void:
	var num_players = NetworkManager.players.size()
	var can_start = all_ready and num_players >= 2
	
	if NetworkManager.is_host:
		%StartBtn.visible = true
		%StartBtn.disabled = not can_start
		_update_start_button_animation(can_start)
	else:
		%StartBtn.visible = false
		_update_start_button_animation(false)
		
	if can_start:
		%StatusLabel.text = "All players ready! Host can start match."
		%StatusLabel.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif num_players < 2:
		%StatusLabel.text = "Waiting for at least 2 players to join..."
		%StatusLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		%StatusLabel.text = "Waiting for all players to be ready..."
		%StatusLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update_start_button_animation(should_pulse: bool) -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
		
	if should_pulse:
		var btn = %StartBtn
		btn.pivot_offset = btn.size / 2.0
		pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		%StartBtn.scale = Vector2.ONE

func _on_start_btn_resized() -> void:
	%StartBtn.pivot_offset = %StartBtn.size / 2.0

func _on_copy_code_btn_pressed() -> void:
	DisplayServer.clipboard_set(NetworkManager.room_code)

func _on_ready_btn_pressed() -> void:
	NetworkManager.rpc("set_ready", multiplayer.get_unique_id())

func _on_start_btn_pressed() -> void:
	NetworkManager.start_match()

func _on_leave_btn_pressed() -> void:
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://Dashboard.tscn")

func _on_player_list_changed() -> void:
	_refresh_player_list()

func _on_game_started() -> void:
	GameManager.start_multiplayer_game()

func _on_all_players_ready() -> void:
	_refresh_player_list()

func _on_join_failed(reason: String) -> void:
	%StatusLabel.text = "Error: " + reason
	%StatusLabel.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
