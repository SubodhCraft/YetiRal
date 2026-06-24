extends Control

@onready var label_momos: Label = %MomosCollectedLabel
@onready var btn_lobby: Button = %LobbyBtn
@onready var vbox_container: VBoxContainer = $CenterContainer/VBox

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var final_momos = 0
	if GameManager:
		if GameManager.is_multiplayer:
			# Multi-player Leaderboard and victory logic
			_build_multiplayer_leaderboard(vbox_container)
			
			# Save multiplayer stats to session DB
			if SessionManager.is_logged_in():
				var my_username = SessionManager.get_current_user()
				SessionManager.increment_matches_played(my_username)
				
				# Find overall match winner
				var winner_id = -1
				var max_score = -1
				for pid in GameManager.player_scores:
					var score = GameManager.player_scores[pid]
					if score > max_score:
						max_score = score
						winner_id = pid
				
				# If we are the winner, increment wins
				if winner_id == multiplayer.get_unique_id():
					SessionManager.increment_wins(my_username)
					
				# Add momos collected in the match
				var my_momos = GameManager.player_momos.get(multiplayer.get_unique_id(), 0)
				if my_momos > 0:
					SessionManager.add_user_momos(my_username, my_momos)
		else:
			# Single-player victory
			final_momos = GameManager.momos
			label_momos.text = "🥟 FINAL MOMOS COLLECTED: %d" % final_momos
			
			if SessionManager.is_logged_in():
				var username = SessionManager.get_current_user()
				SessionManager.increment_matches_played(username)
				SessionManager.increment_wins(username)
				if final_momos > 0:
					SessionManager.add_user_momos(username, final_momos)
					
	if btn_lobby:
		btn_lobby.pressed.connect(_on_lobby_pressed)
		
	# Trigger falling confetti animation
	_spawn_confetti()

func _on_lobby_pressed() -> void:
	if GameManager:
		GameManager.is_multiplayer = false
		GameManager.return_to_dashboard()

func _spawn_confetti() -> void:
	var screen_size = get_viewport_rect().size
	# Spawn 80 colorful pieces of confetti falling from the sky
	for i in range(80):
		var rect = ColorRect.new()
		rect.size = Vector2(randf_range(8.0, 16.0), randf_range(8.0, 16.0))
		rect.color = Color(randf(), randf(), randf(), randf_range(0.8, 1.0))
		rect.position = Vector2(randf_range(0, screen_size.x), -30)
		rect.pivot_offset = rect.size / 2.0
		rect.rotation = randf_range(0, 360)
		add_child(rect)
		
		# Put confetti behind front text but in front of background
		move_child(rect, 1)
		
		var fall_time = randf_range(3.0, 6.0)
		var delay = randf_range(0.0, 4.0)
		
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(rect, "position:y", screen_size.y + 30, fall_time).set_delay(delay)
		tween.tween_property(rect, "position:x", rect.position.x + randf_range(-150, 150), fall_time).set_delay(delay)
		tween.tween_property(rect, "rotation", rect.rotation + randf_range(360, 1080), fall_time).set_delay(delay)
		
		# Free node when animation finishes
		var cleanup_tween = create_tween()
		cleanup_tween.tween_interval(fall_time + delay)
		cleanup_tween.tween_callback(rect.queue_free)

func _build_multiplayer_leaderboard(vbox_node: VBoxContainer) -> void:
	if label_momos:
		label_momos.hide()
		
	# Extract and sort players by score
	var sorted_players = []
	for pid in GameManager.player_scores:
		var pdata = NetworkManager.players.get(pid, {"username": "Unknown", "uid": ""})
		var score = GameManager.player_scores[pid]
		sorted_players.append({
			"peer_id": pid,
			"username": pdata.get("username", "Unknown"),
			"score": score
		})
	sorted_players.sort_custom(func(a, b): return a.score > b.score)
	
	# Leaderboard container
	var leaderboard_vbox = VBoxContainer.new()
	leaderboard_vbox.name = "LeaderboardVBox"
	leaderboard_vbox.add_theme_constant_override("separation", 12)
	vbox_node.add_child(leaderboard_vbox)
	vbox_node.move_child(leaderboard_vbox, 2)
	
	# Headers
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	
	var h_rank = Label.new()
	h_rank.text = "RANK"
	h_rank.custom_minimum_size = Vector2(80, 0)
	h_rank.add_theme_font_size_override("font_size", 18)
	h_rank.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_hbox.add_child(h_rank)
	
	var h_name = Label.new()
	h_name.text = "PLAYER"
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_name.add_theme_font_size_override("font_size", 18)
	h_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_hbox.add_child(h_name)
	
	var h_score = Label.new()
	h_score.text = "SCORE"
	h_score.custom_minimum_size = Vector2(100, 0)
	h_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_score.add_theme_font_size_override("font_size", 18)
	h_score.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_hbox.add_child(h_score)
	
	leaderboard_vbox.add_child(header_hbox)
	
	# Leaderboard Rows
	var rank = 1
	for pinfo in sorted_players:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(500, 50)
		
		var style = StyleBoxFlat.new()
		if rank == 1:
			style.bg_color = Color(0.3, 0.25, 0.05, 0.7) # Gold highlight
			style.border_color = Color(1.0, 0.84, 0.0, 0.9)
			style.border_width_left = 5
		elif rank == 2:
			style.bg_color = Color(0.2, 0.2, 0.22, 0.7) # Silver highlight
			style.border_color = Color(0.75, 0.75, 0.75, 0.9)
			style.border_width_left = 4
		elif rank == 3:
			style.bg_color = Color(0.22, 0.15, 0.1, 0.7) # Bronze highlight
			style.border_color = Color(0.8, 0.5, 0.2, 0.9)
			style.border_width_left = 4
		else:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
			style.border_color = Color(0.25, 0.25, 0.25, 0.5)
			style.border_width_left = 2
			
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		panel.add_child(hbox)
		
		var lbl_rank = Label.new()
		if rank == 1:
			lbl_rank.text = "🥇 1st"
			lbl_rank.add_theme_color_override("font_color", Color(1, 0.84, 0))
		elif rank == 2:
			lbl_rank.text = "🥈 2nd"
			lbl_rank.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		elif rank == 3:
			lbl_rank.text = "🥉 3rd"
			lbl_rank.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
		else:
			lbl_rank.text = "%dth" % rank
			lbl_rank.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
		lbl_rank.custom_minimum_size = Vector2(80, 0)
		lbl_rank.add_theme_font_size_override("font_size", 22)
		hbox.add_child(lbl_rank)
		
		var lbl_name = Label.new()
		lbl_name.text = pinfo.username
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.add_theme_font_size_override("font_size", 22)
		
		if pinfo.peer_id == multiplayer.get_unique_id():
			lbl_name.text += " (You)"
			lbl_name.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0)) # Cyan
		hbox.add_child(lbl_name)
		
		var lbl_score = Label.new()
		lbl_score.text = "%d pts" % pinfo.score
		lbl_score.custom_minimum_size = Vector2(100, 0)
		lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_score.add_theme_font_size_override("font_size", 22)
		hbox.add_child(lbl_score)
		
		leaderboard_vbox.add_child(panel)
		
		# Animate the row sliding in (staggered)
		panel.modulate.a = 0.0
		panel.position.x -= 40
		
		var slide_t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		slide_t.tween_interval((rank - 1) * 0.2)
		slide_t.tween_property(panel, "modulate:a", 1.0, 0.35)
		
		var pos_t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pos_t.tween_interval((rank - 1) * 0.2)
		pos_t.tween_property(panel, "position:x", panel.position.x + 40, 0.35)
		
		# Pulse animation for the winner
		if rank == 1:
			var pulse_t = create_tween().set_loops()
			pulse_t.tween_interval((rank - 1) * 0.2 + 0.35)
			pulse_t.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.75).set_trans(Tween.TRANS_SINE)
			pulse_t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
			
		rank += 1
