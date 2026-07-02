extends Control

## --- VictoryScreen.gd --------------------------------------------------------
## Shown after all rounds in both Singleplayer and Multiplayer.
## Node references use unique-name accessors (%NodeName) for robustness.

@onready var win_label: Label      = %WinLabel
@onready var rewards_label: Label  = %RewardsLabel
@onready var main_menu_btn: Button = %LobbyBtn
@onready var leaderboard_vbox: VBoxContainer = %LeaderboardVBox

var rounds_cleared: int = 0
var momos_collected: int = 0

func _ready() -> void:
	if GameManager:
		rounds_cleared  = GameManager.current_round_index
		momos_collected = GameManager.momos

	if AudioManager:
		AudioManager.play_track(AudioManager.MusicTrack.VICTORY)

	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu)

	# Fireworks
	if VFXManager and VFXManager.has_method("play_victory_fireworks"):
		VFXManager.play_victory_fireworks()

	if GameManager and GameManager.is_multiplayer:
		_setup_multiplayer()
	else:
		_setup_singleplayer()

	# Pulse the title
	var title_node: Label = find_child("Title")
	if title_node:
		title_node.pivot_offset = title_node.size / 2.0
		var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(title_node, "scale", Vector2(1.07, 1.07), 0.7)
		tw.tween_property(title_node, "scale", Vector2(1.0,  1.0),  0.7)


func _setup_singleplayer() -> void:
	var xp = rounds_cleared * 50 + momos_collected * 5
	if win_label:
		win_label.text = "?? YOU WIN!  ???? ?!"
		win_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	if rewards_label:
		rewards_label.text = "?? Rewards: +%d XP   +%d Momos" % [xp, momos_collected]

	if SessionManager and SessionManager.get_current_user() != "":
		SessionManager.log_match_result("SP", rounds_cleared, 1, momos_collected)


func _setup_multiplayer() -> void:
	var leaderboard: Array = GameManager.mp_leaderboard
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else -1

	# Find local player's position (0-indexed)
	var my_pos = leaderboard.size() - 1
	for i in leaderboard.size():
		if leaderboard[i]["id"] == my_id:
			my_pos = i
			break

	# Win / Lose headline
	const HEADLINES = [
		["?? VICTORY!\nYou're the Champion!", Color(1.0, 0.84, 0.0)],
		["?? 2nd Place!\nGreat Race!",         Color(0.85, 0.85, 0.85)],
		["?? 3rd Place!\nWell Played!",         Color(0.80, 0.50, 0.20)],
	]
	if win_label:
		if my_pos < HEADLINES.size():
			win_label.text = HEADLINES[my_pos][0]
			win_label.add_theme_color_override("font_color", HEADLINES[my_pos][1])
		else:
			win_label.text = "You Finished!\nBetter Luck Next Time!"
			win_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# Rewards
	var xp_table   = [200, 100, 50, 20]
	var momo_table = [30,  15,   5,  2]
	var rp = min(my_pos if my_pos >= 0 else xp_table.size() - 1, xp_table.size() - 1)
	var my_momos_mp = GameManager.player_momos.get(my_id, 0)
	if rewards_label:
		rewards_label.text = "?? Rewards: +%d XP   +%d Momos" % [xp_table[rp], momo_table[rp]]

	# Build the leaderboard rows
	if leaderboard_vbox:
		for c in leaderboard_vbox.get_children():
			c.queue_free()

		var medals = ["??", "??", "??", "4??", "5??", "6??", "7??", "8??"]
		var rank_colors = [Color(1.0, 0.84, 0.0), Color(0.85, 0.85, 0.85), Color(0.80, 0.50, 0.20)]

		for i in leaderboard.size():
			var entry = leaderboard[i]
			var is_me = entry["id"] == my_id

			# Row panel
			var row = PanelContainer.new()
			var row_style = StyleBoxFlat.new()
			row_style.bg_color = Color(0.13, 0.34, 0.18, 0.92) if is_me else Color(0.12, 0.11, 0.06, 0.88)
			row_style.corner_radius_top_left    = 10
			row_style.corner_radius_top_right   = 10
			row_style.corner_radius_bottom_right = 10
			row_style.corner_radius_bottom_left  = 10
			row_style.content_margin_left   = 16
			row_style.content_margin_right  = 16
			row_style.content_margin_top    = 10
			row_style.content_margin_bottom = 10
			if i < rank_colors.size():
				row_style.border_width_left = 4
				row_style.border_color      = rank_colors[i]
			row.add_theme_stylebox_override("panel", row_style)

			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 14)
			row.add_child(hbox)

			var medal_lbl = Label.new()
			medal_lbl.text = medals[min(i, medals.size() - 1)]
			medal_lbl.add_theme_font_size_override("font_size", 26)
			hbox.add_child(medal_lbl)

			var name_lbl = Label.new()
			name_lbl.text = entry["username"] + (" (You)" if is_me else "")
			name_lbl.add_theme_font_size_override("font_size", 20)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_me:
				name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			hbox.add_child(name_lbl)

			var score_lbl = Label.new()
			score_lbl.text = "%d pts" % entry["score"]
			score_lbl.add_theme_font_size_override("font_size", 20)
			score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hbox.add_child(score_lbl)

			leaderboard_vbox.add_child(row)

			# Animate the row sliding in from the right
			row.modulate.a = 0.0
			row.position.x = 160
			var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.12 * i)
			tw.tween_property(row, "modulate:a", 1.0, 0.35)
			tw.parallel().tween_property(row, "position:x", 0.0, 0.35)

	# Log result
	if SessionManager and SessionManager.get_current_user() != "":
		SessionManager.log_match_result("MP", GameManager.current_round_index, my_pos + 1, my_momos_mp)


func _on_main_menu() -> void:
	if GameManager:
		GameManager.return_to_dashboard()
