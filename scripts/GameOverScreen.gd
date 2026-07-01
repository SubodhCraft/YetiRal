extends Control

@onready var try_again_btn: Button = %TryAgainBtn if has_node("%TryAgainBtn") else find_child("TryAgainBtn")
@onready var main_menu_btn: Button = %LobbyBtn if has_node("%LobbyBtn") else find_child("LobbyBtn")
@onready var stats_label: Label = %StatsLabel if has_node("%StatsLabel") else find_child("StatsLabel")
@onready var momos_label: Label = %MomosCollectedLabel if has_node("%MomosCollectedLabel") else find_child("MomosCollectedLabel")
@onready var yeti_viewport: SubViewport = %YetiViewport if has_node("%YetiViewport") else find_child("YetiViewport")

var rounds_cleared: int = 0
var momos_collected: int = 0
var xp_earned: int = 0

func _ready() -> void:
	if GameManager:
		rounds_cleared   = GameManager.current_round_index
		momos_collected  = GameManager.momos
		xp_earned        = rounds_cleared * 50 + momos_collected * 5
		
	if AudioManager:
		AudioManager.play_track(AudioManager.MusicTrack.GAME_OVER)
		
	if try_again_btn: try_again_btn.pressed.connect(_on_try_again)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu)
	
	if stats_label:
		stats_label.text = "Rounds Cleared: %d of 7\nMomos Collected: %d 🥟\nXP Earned: +%d" % [rounds_cleared, momos_collected, xp_earned]
		
	if momos_label:
		momos_label.text = "🥟 MOMOS COLLECTED: %d" % momos_collected
		
	if SessionManager and SessionManager.get_current_user() != "":
		SessionManager.log_match_result("SP", rounds_cleared, 0, momos_collected)
		
	_setup_yeti_ragdoll()

func _setup_yeti_ragdoll() -> void:
	if not yeti_viewport: return
	var player_res = load("res://scenes/gameplay/Player3D.tscn")
	if player_res:
		var p = player_res.instantiate()
		yeti_viewport.add_child(p)
		
		# Animate flat lying
		var visuals = p.get_node_or_null("Visuals")
		if visuals:
			visuals.rotation_degrees.x = 90
		var ap = p.get_node_or_null("AnimationPlayer")
		if ap and ap.has_animation("ragdoll"):
			ap.play("ragdoll")

func _on_try_again() -> void:
	if GameManager:
		if GameManager.is_multiplayer:
			GameManager.return_to_dashboard()
		else:
			GameManager.start_game()

func _on_main_menu() -> void:
	if GameManager:
		GameManager.return_to_dashboard()
