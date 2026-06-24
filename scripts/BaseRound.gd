class_name BaseRound
extends Node3D

@export var round_name: String = "ROUND"
@export var time_limit: float = 60.0

var time_remaining: float
var hud: Control
var round_ended: bool = false

const HUD_SCENE: String = "res://scenes/ui/GameplayHUD.tscn"
const PLAYER_SCENE: String = "res://scenes/gameplay/Player3D.tscn"

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var kill_zone: Area3D = $KillZone
@onready var finish_zone: Area3D = $FinishZone

func _ready() -> void:
	time_remaining = time_limit
	_spawn_player()
	_setup_hud()
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	if finish_zone:
		finish_zone.body_entered.connect(_on_finish_zone_body_entered)

func _process(delta: float) -> void:
	if time_remaining > 0.0 and not round_ended:
		time_remaining -= delta
		if hud:
			hud.update_timer(time_remaining, time_limit)
		if time_remaining <= 0.0:
			time_remaining = 0.0
			_freeze_local_players()
			_on_time_out()

func _freeze_local_players() -> void:
	for child in get_children():
		if child is CharacterBody3D and child.has_method("set_physics_process"):
			if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
				if child.is_multiplayer_authority():
					child.set_physics_process(false)
					child.set_process_unhandled_input(false)
					child.set_process_input(false)
			else:
				child.set_physics_process(false)
				child.set_process_unhandled_input(false)
				child.set_process_input(false)

func _spawn_player() -> void:
	if not spawn_point:
		push_error("SpawnPoint Marker3D not found in scene!")
		return

	var player_res = load(PLAYER_SCENE)
	if not player_res:
		return

	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		# ── MULTIPLAYER: spawn one node per connected peer ──────────────────────
		# Player name tags ARE shown in multiplayer.
		var index = 0
		for peer_id in NetworkManager.players:
			var player = player_res.instantiate()
			player.name = str(peer_id)
			add_child(player)

			# Show name label above head — MULTIPLAYER ONLY
			var pdata = NetworkManager.players[peer_id]
			var username = pdata.get("username", "Player")
			if player.has_method("setup_username_label"):
				player.setup_username_label(username)

			# Stagger spawn positions slightly so players don't overlap
			var half_spread = (NetworkManager.players.size() - 1) * 0.75
			var offset = Vector3(index * 1.5 - half_spread, 0.0, 0.0)
			player.global_position = spawn_point.global_position + offset
			player.global_rotation = spawn_point.global_rotation
			index += 1
	else:
		# ── SINGLEPLAYER: one player, no name label ─────────────────────────────
		var player = player_res.instantiate()
		player.name = "Player3D"
		add_child(player)
		# NO setup_username_label call in singleplayer
		player.global_position = spawn_point.global_position
		player.global_rotation = spawn_point.global_rotation

func _setup_hud() -> void:
	var hud_res = load(HUD_SCENE)
	if hud_res:
		hud = hud_res.instantiate()
		add_child(hud)
		hud.set_round_name(round_name)
		_update_hud_stats()
		if GameManager.has_signal("stats_changed"):
			GameManager.stats_changed.connect(_update_hud_stats)

func _update_hud_stats() -> void:
	if hud and GameManager:
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			var my_id = multiplayer.get_unique_id()
			var my_momos = GameManager.player_momos.get(my_id, 0)
			hud.update_stats(99, my_momos)
		else:
			hud.update_stats(GameManager.lives, GameManager.momos)

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if round_ended:
		return
	if body is CharacterBody3D:
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			if body.is_multiplayer_authority():
				# Respawn at spawn point — no life loss in multiplayer
				body.global_position = spawn_point.global_position
				body.velocity = Vector3.ZERO
		else:
			# Singleplayer: lose a life
			if GameManager:
				round_ended = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				GameManager.lose_life()

func _on_finish_zone_body_entered(body: Node3D) -> void:
	if round_ended:
		return
	if body is CharacterBody3D:
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			if body.is_multiplayer_authority():
				round_ended = true
				body.set_physics_process(false)
				body.set_process_unhandled_input(false)
				body.set_process_input(false)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				GameManager.rpc_id(1, "submit_finish", multiplayer.get_unique_id())
				if hud and hud.has_method("show_finished_message"):
					hud.show_finished_message()
		else:
			# Singleplayer: advance to next round
			if GameManager:
				round_ended = true
				body.set_physics_process(false)
				body.set_process_unhandled_input(false)
				body.set_process_input(false)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				if hud and hud.has_method("show_victory_message"):
					hud.show_victory_message(50)
				
				get_tree().create_timer(3.0).timeout.connect(func():
					GameManager.next_round()
				)

func _on_time_out() -> void:
	if round_ended:
		return
	round_ended = true
	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			GameManager.host_advance_round()
	else:
		if GameManager:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if hud and hud.has_method("show_time_up_message"):
				hud.show_time_up_message()
				
			get_tree().create_timer(3.0).timeout.connect(func():
				GameManager.lose_life()
			)
