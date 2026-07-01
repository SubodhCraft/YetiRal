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
		
	# Assume mp_container has 3 ColorRects/Panels for podium
	var p1 = mp_container.get_node_or_null("Podium1")
	var p2 = mp_container.get_node_or_null("Podium2")
	var p3 = mp_container.get_node_or_null("Podium3")
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if p1: tw.tween_property(p1, "custom_minimum_size:y", 220, 1.5)
	if p2: tw.tween_property(p2, "custom_minimum_size:y", 160, 1.5)
	if p3: tw.tween_property(p3, "custom_minimum_size:y", 100, 1.5)
	
	if SessionManager and SessionManager.get_current_user() != "":
		SessionManager.log_match_result("MP", rounds_cleared, 1, momos_collected)

func _on_play_again() -> void:
	if GameManager:
		GameManager.start_game()

func _on_main_menu() -> void:
	if GameManager:
		GameManager.return_to_dashboard()
