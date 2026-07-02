extends Control

@onready var win_label: Label = %WinLabel if has_node("%WinLabel") else find_child("WinLabel")
@onready var momos_label: Label = %MomosCollectedLabel if has_node("%MomosCollectedLabel") else find_child("MomosCollectedLabel")
@onready var stats_label: Label = %StatsLabel if has_node("%StatsLabel") else find_child("StatsLabel")
@onready var badges_container: HBoxContainer = %BadgesContainer if has_node("%BadgesContainer") else find_child("BadgesContainer")
@onready var play_again_btn: Button = %PlayAgainBtn if has_node("%PlayAgainBtn") else find_child("PlayAgainBtn")
@onready var main_menu_btn: Button = %LobbyBtn if has_node("%LobbyBtn") else find_child("LobbyBtn")

@onready var sp_container: Control = %SPContainer if has_node("%SPContainer") else find_child("SPContainer")
@onready var mp_container: Control = %MPContainer if has_node("%MPContainer") else find_child("MPContainer")

var rounds_cleared: int = 0
var momos_collected: int = 0
var xp_earned: int = 0

func _ready() -> void:
	# Read actual values directly from GameManager — fixes 0 momo bug
	if GameManager:
		rounds_cleared   = GameManager.current_round_index
		momos_collected  = GameManager.momos
		xp_earned        = rounds_cleared * 50 + momos_collected * 5
	
	if AudioManager:
		AudioManager.play_track(AudioManager.MusicTrack.VICTORY)
		
	if play_again_btn: play_again_btn.pressed.connect(_on_play_again)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu)
	
	if GameManager and GameManager.is_multiplayer:
		_setup_multiplayer()
	else:
		_setup_singleplayer()

func _setup_singleplayer() -> void:
	if mp_container: mp_container.hide()
	if sp_container: sp_container.show()
	
	if win_label:
		win_label.text = "🏆 YOU WIN!\nबधाई छ!"
		win_label.modulate = Color(1.0, 0.84, 0.0) # Golden
		win_label.pivot_offset = win_label.size / 2.0
		var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(win_label, "scale", Vector2(1.1, 1.1), 0.5)
		tw.tween_property(win_label, "scale", Vector2(1.0, 1.0), 0.5)
		
	if stats_label:
		stats_label.text = "Rounds Cleared: %d\nMomos Collected: %d\nXP Earned: +%d" % [rounds_cleared, momos_collected, xp_earned]
		
	if momos_label:
		momos_label.text = "🥟 FINAL MOMOS COLLECTED: %d" % momos_collected
		
	if SessionManager and SessionManager.get_current_user() != "":
		SessionManager.log_match_result("SP", rounds_cleared, 1, momos_collected)

func _setup_multiplayer() -> void:
	if sp_container: sp_container.hide()
	if mp_container: mp_container.show()
	
	if VFXManager:
		VFXManager.play_victory_fireworks()
	
	var leaderboard: Array = GameManager.mp_leaderboard
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else -1
	
	# Determine local player's position
	var my_pos = -1
	for i in leaderboard.size():
		if leaderboard[i]["id"] == my_id:
			my_pos = i
			break
	
	# Win / Lose headline
	if win_label:
		if my_pos == 0:
			win_label.text = "🏆 VICTORY!\nYou're the Champion!"
			win_label.modulate = Color(1.0, 0.84, 0.0)
		elif my_pos == 1:
			win_label.text = "🥈 2nd Place!\nGreat Race!"
			win_label.modulate = Color(0.85, 0.85, 0.85)
		elif my_pos == 2:
			win_label.text = "🥉 3rd Place!\nWell Played!"
			win_label.modulate = Color(0.80, 0.50, 0.20)
		else:
			win_label.text = "You Finished!\nBetter Luck Next Time!"
			win_label.modulate = Color(1, 1, 1)
		win_label.pivot_offset = win_label.size / 2.0
		var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(win_label, "scale", Vector2(1.08, 1.08), 0.6)
		tw.tween_property(win_label, "scale", Vector2(1.0, 1.0), 0.6)
	
	# Reward shown
	var xp_rewards = [200, 100, 50, 20]
	var momo_rewards = [30, 15, 5, 2]
	var reward_pos = min(my_pos if my_pos >= 0 else xp_rewards.size() - 1, xp_rewards.size() - 1)
	if momos_label:
		momos_label.text = "🎁 Rewards: +%d XP  +%d Momos" % [xp_rewards[reward_pos], momo_rewards[reward_pos]]
	
	# Build ranked list inside mp_container (clear first)
	for c in mp_container.get_children():
		if c.name != "Title" and c.name != "WinLabel" and c.name != "MomosCollectedLabel":
			c.queue_free()
	
	var medals = ["🥇", "🥈", "🥉", "4️⃣", "5️⃣", "6️⃣"]
	var rank_colors = [Color(1.0, 0.84, 0.0), Color(0.85, 0.85, 0.85), Color(0.80, 0.50, 0.20)]
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	mp_container.add_child(vbox)
	
	var header = Label.new()
	header.text = "── FINAL STANDINGS ──"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	for i in leaderboard.size():
		var entry = leaderboard[i]
		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		var is_me = entry["id"] == my_id
		row_style.bg_color = Color(0.1, 0.1, 0.15, 0.85) if not is_me else Color(0.1, 0.3, 0.15, 0.9)
		row_style.corner_radius_top_left = 10
		row_style.corner_radius_top_right = 10
		row_style.corner_radius_bottom_right = 10
		row_style.corner_radius_bottom_left = 10
		row_style.content_margin_left = 16
		row_style.content_margin_right = 16
		row_style.content_margin_top = 10
		row_style.content_margin_bottom = 10
		if i < rank_colors.size():
			row_style.border_width_left = 3
			row_style.border_color = rank_colors[i]
		row_panel.add_theme_stylebox_override("panel", row_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row_panel.add_child(hbox)
		
		var medal_lbl = Label.new()
		medal_lbl.text = medals[min(i, medals.size() - 1)]
		medal_lbl.add_theme_font_size_override("font_size", 28)
		hbox.add_child(medal_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = entry["username"] + (" (You)" if is_me else "")
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_me:
			name_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		hbox.add_child(name_lbl)
		
		var score_lbl = Label.new()
		score_lbl.text = "%d pts" % entry["score"]
		score_lbl.add_theme_font_size_override("font_size", 22)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(score_lbl)
		
		vbox.add_child(row_panel)
	
	# Only log match result once (host decides)
	if SessionManager and SessionManager.get_current_user() != "":
		var my_rounds = GameManager.current_round_index
		var my_momos_mp = GameManager.player_momos.get(my_id, 0)
		SessionManager.log_match_result("MP", my_rounds, my_pos + 1, my_momos_mp)


func _on_play_again() -> void:
	if GameManager:
		GameManager.start_game()

func _on_main_menu() -> void:
	if GameManager:
		GameManager.return_to_dashboard()
