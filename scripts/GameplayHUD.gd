extends Control

@onready var label_round_name: Label = %RoundNameLabel
@onready var label_timer: Label = %TimerLabel
@onready var progress_timer: ProgressBar = %TimerProgressBar
@onready var label_momo: Label = %MomoLabel
@onready var container_hearts: HBoxContainer = %HeartsContainer

const HEART_FULL: String = "❤️"

var fade_rect: ColorRect

func _ready() -> void:
	# Black overlay — starts fully opaque.
	# BaseRound calls fade_from_black() after the info card or countdown starts.
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 1.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.z_index = 100
	add_child(fade_rect)
	# Do NOT auto-fade — BaseRound controls timing

	if GameManager.is_multiplayer:
		# Create VBoxContainer "Leaderboard" anchored top-right (margin 20px)
		var leaderboard_panel = PanelContainer.new()
		leaderboard_panel.name = "Leaderboard"
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 15
		style.content_margin_bottom = 15
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		leaderboard_panel.add_theme_stylebox_override("panel", style)
		
		var leaderboard_vbox = VBoxContainer.new()
		leaderboard_vbox.name = "LeaderboardVBox"
		leaderboard_panel.add_child(leaderboard_vbox)
		
		var header = Label.new()
		header.text = "🏆 SCORES"
		header.add_theme_font_size_override("font_size", 20)
		header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaderboard_vbox.add_child(header)
		
		var rows_container = VBoxContainer.new()
		rows_container.name = "RowsContainer"
		leaderboard_vbox.add_child(rows_container)
		
		add_child(leaderboard_panel)
		leaderboard_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
		leaderboard_panel.custom_minimum_size = Vector2(200, 0)
		
		# Timer to refresh leaderboard every 1.0s
		var leaderboard_timer = Timer.new()
		leaderboard_timer.name = "LeaderboardTimer"
		leaderboard_timer.wait_time = 1.0
		leaderboard_timer.one_shot = false
		leaderboard_timer.timeout.connect(_refresh_leaderboard)
		add_child(leaderboard_timer)
		leaderboard_timer.start()
		
		# Initial refresh
		_refresh_leaderboard()

func _refresh_leaderboard() -> void:
	var rows_container = get_node_or_null("Leaderboard/LeaderboardVBox/RowsContainer")
	if not rows_container:
		return
		
	# Clear previous rows
	for child in rows_container.get_children():
		child.queue_free()
		
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
	
	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		var pid = player.peer_id
		var username = player.username
		var score = player.score
		
		var label = Label.new()
		var finish_str = " [FINISHED ✓]" if (pid in GameManager.round_finishes) else ""
		label.text = "%d. %s — %dpts%s" % [i + 1, username, score, finish_str]
		label.add_theme_font_size_override("font_size", 16)
		
		if pid == multiplayer.get_unique_id():
			label.modulate = Color(0.4, 0.8, 1.0)
			
		rows_container.add_child(label)

func set_round_name(name_str: String) -> void:
	if label_round_name:
		label_round_name.text = name_str.to_upper()

func update_timer(remaining: float, limit: float) -> void:
	if label_timer:
		var minutes = int(remaining) / 60
		var seconds = int(remaining) % 60
		label_timer.text = "%d:%02d" % [minutes, seconds]
		
	if progress_timer:
		progress_timer.max_value = limit
		progress_timer.value = remaining
		
		var ratio = remaining / limit
		var style: StyleBoxFlat = progress_timer.get_theme_stylebox("fill").duplicate()
		if style:
			if ratio < 0.25:
				style.bg_color = Color(0.9, 0.2, 0.2) # Urgent red
			elif ratio < 0.5:
				style.bg_color = Color(0.9, 0.6, 0.1) # Warning orange
			else:
				style.bg_color = Color(0.18, 0.8, 0.44) # Safe green
			progress_timer.add_theme_stylebox_override("fill", style)

func update_stats(lives: int, momos: int) -> void:
	if label_momo:
		label_momo.text = "🥟 %d" % momos
		
	if container_hearts:
		for child in container_hearts.get_children():
			child.queue_free()
			
		for i in range(max(0, lives)):
			var heart = Label.new()
			heart.text = HEART_FULL
			heart.add_theme_font_size_override("font_size", 32)
			container_hearts.add_child(heart)

func show_finished_message() -> void:
	if has_node("FinishedPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "FinishedPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.84, 0.0, 0.8) # Gold border
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var label = Label.new()
	if GameManager.is_multiplayer:
		var my_id = multiplayer.get_unique_id()
		var pos = GameManager.round_finishes.find(my_id) + 1
		var total = NetworkManager.players.size()
		label.text = "🏁 You Finished! Position: %d / %d players" % [pos, total]
	else:
		label.text = "🏆 ROUND FINISHED!"
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "Waiting for other players..." if GameManager.is_multiplayer else "Round complete!"
	sub_label.add_theme_font_size_override("font_size", 22)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

func show_victory_message(xp_earned: int) -> void:
	if has_node("VictoryPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "VictoryPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.18, 0.8, 0.44, 0.9) # Safe green
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "🏆 ROUND VICTORY!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "+%d XP Earned" % xp_earned
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

func show_time_up_message() -> void:
	if has_node("TimeUpPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "TimeUpPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.9, 0.2, 0.2, 0.9) # Urgent red
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "⏰ TIME'S UP!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "You ran out of time!"
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

func show_round_results(finishes: Array) -> void:
	if has_node("RoundResultsPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "RoundResultsPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var center = CenterContainer.new()
	panel.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var header = Label.new()
	header.text = "🏁 ROUND RESULTS"
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(1, 0.84, 0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	var points_map = [10, 8, 6, 4, 2]
	var prefixes = ["🥇 1st", "🥈 2nd", "🥉 3rd", "4th", "5th"]
	
	for i in range(finishes.size()):
		if i >= prefixes.size():
			break
			
		var pid = finishes[i]
		var pdata = NetworkManager.players.get(pid, {"username": "Unknown", "uid": ""})
		var username = pdata.get("username", "Unknown")
		var points = points_map[i]
		var prefix = prefixes[i]
		
		var row = Label.new()
		row.text = "%s: %s (+%d pts)" % [prefix, username, points]
		row.add_theme_font_size_override("font_size", 24)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if pid == multiplayer.get_unique_id():
			row.modulate = Color(0.4, 0.8, 1.0)
			
		vbox.add_child(row)
		
	add_child(panel)
	
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(4.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(panel.queue_free)

func show_momo_popup(amount: int) -> void:
	var label = Label.new()
	label.text = "+%d 🥟" % amount
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(label)
	
	var screen_center = get_viewport_rect().size / 2.0
	var random_x_offset = randf_range(-100.0, 100.0)
	label.position = Vector2(screen_center.x + random_x_offset - 50.0, screen_center.y - 20.0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(label.queue_free)

func fade_to_black(duration: float) -> void:
	if not fade_rect:
		fade_rect = ColorRect.new()
		fade_rect.name = "FadeRect"
		fade_rect.color = Color.BLACK
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.z_index = 100
		add_child(fade_rect)
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)

func fade_from_black(duration: float) -> void:
	if not fade_rect:
		return
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(func(): fade_rect.visible = false)
