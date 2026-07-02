class_name BaseRound
extends Node3D

enum RoundType { RACE, SURVIVAL, MEMORY, FINAL }

@export var round_name: String = "ROUND"
@export var time_limit: float = 60.0
@export var round_type: RoundType = RoundType.RACE
## Index into YetiFactScreen.FACTS array shown after this round.
@export var yeti_fact_index: int = 0

## ─── FEATURE 1: CHECKPOINT SYSTEM ───────────────────────────────────────────
## Array of Marker3D nodes placed in the scene as checkpoint triggers.
## Each Marker3D must have an Area3D child named "Area3D" whose body_entered
## signal is connected in _ready() to _on_checkpoint_area_entered().
@export var checkpoints: Array[Marker3D] = []

## ─── FEATURE 2: AUTO MOMO COINS ──────────────────────────────────────────────
## When true, momo_count coins are scattered around spawn_point on _ready().
@export var auto_spawn_momos: bool = false
@export var momo_count: int = 5

## ─── FEATURE 4: SPECTATOR THRESHOLD ─────────────────────────────────────────
## How many kill-zone hits promote a MP player to spectator in one round.
@export var spectator_kill_threshold: int = 3

var time_remaining: float
var hud: Control
var round_ended: bool = false
var round_started: bool = false

## ─── FEATURE 1: checkpoint tracking ─────────────────────────────────────────
## Maps body node → last Marker3D checkpoint reached.
## Keyed by the CharacterBody3D node itself (works SP and MP).
var _player_checkpoints: Dictionary = {}

## ─── FEATURE 4: spectator tracking (MP only) ─────────────────────────────────
## kill_count: peer_id (int) → number of times that peer has entered kill_zone.
var _kill_count: Dictionary = {}
## Set of peer_ids already promoted to spectator this round.
var _spectators: Dictionary = {}

const HUD_SCENE: String = "res://scenes/ui/GameplayHUD.tscn"
const PLAYER_SCENE: String = "res://scenes/gameplay/Player3D.tscn"
const MOMO_COIN_SCENE: String = "res://scenes/gameplay/MomoCoin.tscn"
const YETI_FACT_SCENE: String = "res://scenes/ui/YetiFactScreen.tscn"

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
		_build_finish_banner()

	# ── Feature 1: connect each checkpoint Area3D ─────────────────────────────
	for cp: Marker3D in checkpoints:
		var area: Area3D = cp.get_node_or_null("Area3D") as Area3D
		if area:
			# bind() passes the Marker3D along so the callback knows which one fired
			area.body_entered.connect(_on_checkpoint_area_entered.bind(cp))
		else:
			push_warning("BaseRound: checkpoint '%s' has no Area3D child — skipped." % cp.name)

	# ── Feature 2: scatter momo coins ────────────────────────────────────────
	if auto_spawn_momos:
		_spawn_momo_coins()

	# ── Feature 3: round intro countdown (freezes players, starts timer) ──────
	_freeze_local_players()
	_show_round_info_card()

func _process(delta: float) -> void:
	if round_started and time_remaining > 0.0 and not round_ended:
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

func _build_finish_banner() -> void:
	if not finish_zone:
		return
		
	var banner = Label3D.new()
	banner.text = "FINISH 🏁"
	banner.font_size = 200
	banner.outline_size = 20
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.modulate = Color(1.0, 0.84, 0.0) # Golden yellow
	banner.position = Vector3(0, 4.0, 0) # Float 4 units above the finish zone
	
	# Add a slight bobbing animation
	var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(banner, "position:y", 4.5, 1.5)
	tw.tween_property(banner, "position:y", 4.0, 1.5)
	
	finish_zone.add_child(banner)

## Re-enables physics and input for non-spectator local players.
## Called by _begin_intro_countdown() after "GO!" completes.
func _unfreeze_local_players() -> void:
	for child in get_children():
		if not child is CharacterBody3D:
			continue
		var cb := child as CharacterBody3D
		# In MP, only touch our own authority node; skip spectators
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			if not cb.is_multiplayer_authority():
				continue
			var pid: int = cb.get_multiplayer_authority()
			if _spectators.has(pid):
				continue
		cb.set_physics_process(true)
		cb.set_process_unhandled_input(true)
		cb.set_process_input(true)

## Starts the round timer; called at the end of the intro countdown.
func _start_round_timer() -> void:
	round_started = true

func _spawn_player() -> void:
	if not spawn_point:
		push_error("SpawnPoint Marker3D not found in scene!")
		return

	var player_res = load(PLAYER_SCENE)
	if not player_res:
		return
		
	await get_tree().process_frame
	await get_tree().physics_frame

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

			# Feature 4: initialise kill-count slot for this peer
			_kill_count[peer_id] = 0

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
		hud.update_timer(time_remaining, time_limit)
		_update_hud_stats()
		if GameManager.has_signal("stats_changed"):
			GameManager.stats_changed.connect(_update_hud_stats)

func _update_hud_stats() -> void:
	if hud and GameManager:
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			var my_id = multiplayer.get_unique_id()
			var my_momos = GameManager.player_momos.get(my_id, 0)
			var my_lives = GameManager.player_lives.get(my_id, 3)
			hud.update_stats(my_lives, my_momos)
		else:
			hud.update_stats(GameManager.lives, GameManager.momos)

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if round_ended:
		return
	if body is CharacterBody3D:
		if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
			if body.is_multiplayer_authority():
				var pid: int = body.get_multiplayer_authority()
				
				# Tell the server to deduct a life — it will broadcast back to everyone
				GameManager.rpc_id(1, "deduct_mp_life", pid)
				
				var current_lives = GameManager.player_lives.get(pid, 3) - 1
				if current_lives <= 0:
					# No lives left — become a spectator immediately
					_make_spectator(body as CharacterBody3D, pid)
					if hud and hud.has_method("show_eliminated_message"):
						hud.show_eliminated_message()
					return
				
				# Still has lives — respawn at last checkpoint or spawn point
				var target: Marker3D = _player_checkpoints.get(body, spawn_point) as Marker3D
				if not target:
					target = spawn_point
				body.global_position = target.global_position
				body.velocity = Vector3.ZERO
				rpc("force_sync_position", pid, target.global_position)
		else:
			# Singleplayer: death sequence with black fade screen and Mario Death sound
			_play_singleplayer_death_sequence(body as CharacterBody3D)

func _play_singleplayer_death_sequence(body: CharacterBody3D) -> void:
	round_ended = true
	
	# Freeze the player completely
	body.set_physics_process(false)
	body.set_process_input(false)
	body.set_process_unhandled_input(false)
	body.velocity = Vector3.ZERO
	
	# Fade HUD to black
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.8)
		
	# Play Mario Death sound
	if AudioManager and AudioManager.has_method("play_death_sfx"):
		AudioManager.play_death_sfx()
		
	# Wait for 3 seconds for the sound to finish playing
	await get_tree().create_timer(3.0).timeout
	
	var target: Marker3D = _player_checkpoints.get(body, null) as Marker3D
	if target:
		# Respawn at checkpoint — body stays frozen, play countdown again
		round_ended = false
		round_started = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		body.global_position = target.global_position
		body.velocity = Vector3.ZERO
		
		# Fade HUD back from black then run the 3-2-1-GO countdown
		if hud and hud.has_method("fade_from_black"):
			hud.fade_from_black(0.8)
		_freeze_local_players()
		_begin_intro_countdown()
	else:
		# No checkpoint → lose a life and reload the whole scene
		if GameManager and GameManager.has_method("lose_life_instant"):
			GameManager.lose_life_instant()
		else:
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
				# Activate spectator-style camera so the waiting player can watch
				_activate_finish_spectator_camera(body as CharacterBody3D)
		else:
			# Singleplayer: advance to next round
			if GameManager:
				round_ended = true
				body.set_physics_process(false)
				body.set_process_unhandled_input(false)
				body.set_process_input(false)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				
				if AudioManager:
					AudioManager.stop_round_background()
					if AudioManager.has_method("play_victory_sfx"):
						AudioManager.play_victory_sfx()
				
				if hud and hud.has_method("show_victory_message"):
					hud.show_victory_message(50)
				
				var timer = get_tree().create_timer(2.0)
				timer.timeout.connect(func():
					if hud and hud.has_node("VictoryPanel"):
						hud.get_node("VictoryPanel").queue_free()
					_show_yeti_fact_then(func(): GameManager.next_round())
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
			GameManager.lose_life()

## ─── FEATURE 1: CHECKPOINT SYSTEM ───────────────────────────────────────────
## Called when a player body enters an Area3D that is a child of a checkpoint
## Marker3D.  The bound `cp` argument identifies which checkpoint triggered.
func _on_checkpoint_area_entered(body: Node3D, cp: Marker3D) -> void:
	if not body is CharacterBody3D:
		return
	# In MP only record for the locally authoritative body
	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		if not (body as CharacterBody3D).is_multiplayer_authority():
			return
	_player_checkpoints[body] = cp

## ─── FEATURE 2: AUTO MOMO COINS ──────────────────────────────────────────────
## Instantiates momo_count MomoCoin nodes scattered around spawn_point.
## Scatter range: ±6 units on X and Z, 0–3 units on Y above spawn.
func _spawn_momo_coins() -> void:
	if not spawn_point:
		return
	var coin_scene: PackedScene = load(MOMO_COIN_SCENE) as PackedScene
	if coin_scene == null:
		push_warning("BaseRound: MomoCoin scene not found at '%s'." % MOMO_COIN_SCENE)
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var base: Vector3 = spawn_point.global_position

	for _i: int in momo_count:
		var coin: Node3D = coin_scene.instantiate() as Node3D
		add_child(coin)
		coin.global_position = base + Vector3(
			rng.randf_range(-6.0, 6.0),
			rng.randf_range(0.5, 3.0),   # keep slightly above ground
			rng.randf_range(-6.0, 6.0)
		)

## ─── FEATURE 3: ROUND INTRO COUNTDOWN ───────────────────────────────────────
## Shows a Label3D above the spawn point counting "3 → 2 → 1 → GO!" with a
## one-second gap between digits and a tween fade-out.  After "GO!" disappears
## the label is queue_free()'d and the round timer + player input are enabled.
func _begin_intro_countdown() -> void:
	var label := Label3D.new()
	label.name = "IntroCountdown"
	label.font_size = 128
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	
	# Position 3 units above player's current position (or spawn_point if player not found)
	var above: Vector3
	var player = get_node_or_null("Player3D")
	if player:
		above = player.global_position + Vector3(0.0, 3.0, 0.0)
	else:
		above = (spawn_point.global_position if spawn_point else Vector3.ZERO) + Vector3(0.0, 3.0, 0.0)
		
	add_child(label)
	label.global_position = above

	if AudioManager:
		AudioManager.play_starting_sfx()

	# Fade the black screen away as the countdown starts
	if hud and hud.has_method("fade_from_black"):
		hud.fade_from_black(1.2)

	# Run the sequence asynchronously so _ready() can return normally.
	_run_countdown_sequence(label)


func _run_countdown_sequence(label: Label3D) -> void:
	var steps: Array[String] = ["3", "2", "1", "GO!"]
	for i: int in steps.size():
		if not is_instance_valid(label):
			break
		label.text = steps[i]
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)

		# Tween: fade the label out over 0.8 s
		var tw: Tween = create_tween()
		tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.15)

		if steps[i] != "GO!":
			# Wait one full second before showing next digit
			await get_tree().create_timer(1.0).timeout
		else:
			# Wait for the fade to finish, then clean up and start the round
			await get_tree().create_timer(1.1).timeout
			if is_instance_valid(label):
				label.queue_free()
			
			if AudioManager:
				AudioManager.stop_starting_sfx()
				AudioManager.play_round_background()
				
			_unfreeze_local_players()
			_start_round_timer()
			return


## ─── FEATURE 4: SPECTATOR MODE (MP only) ────────────────────────────────────
## Hides the player's Visuals mesh, disables collision, attaches a free-fly
## Camera3D, and stops physics/input processing.  The spectator can still
## observe the match but cannot interact with the world.
func _make_spectator(body: CharacterBody3D, peer_id: int) -> void:
	_spectators[peer_id] = true

	# Freeze CharacterBody3D — physics and input both off
	body.set_physics_process(false)
	body.set_process_unhandled_input(false)
	body.set_process_input(false)
	body.velocity = Vector3.ZERO

	# Hide $Visuals so the spectator's mesh is invisible to everyone locally
	var visuals: Node3D = body.get_node_or_null("Visuals") as Node3D
	if visuals:
		visuals.visible = false

	# Disable all CollisionShape3D children so the body is non-solid
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true

	# Create a free-fly Camera3D parented to the body so it moves with any
	# position syncs, then immediately detach it to world-space for free flight.
	var spec_cam := Camera3D.new()
	spec_cam.name = "SpectatorCamera"
	# Start just above and behind the eliminated position
	spec_cam.global_position = body.global_position + Vector3(0.0, 6.0, 8.0)
	spec_cam.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
	get_tree().current_scene.add_child(spec_cam)
	spec_cam.make_current()

	# Wire a lightweight free-fly movement script via a meta-stored callable
	# so no extra .gd file is required.
	var cam_ref: Camera3D = spec_cam   # capture for lambda
	var move_speed: float = 8.0
	var look_speed: float = 0.003
	# Connect once per physics frame — the lambda checks is_current() so it
	# automatically becomes inert if the camera is replaced.
	get_tree().process_frame.connect(
		func() -> void:
			if not is_instance_valid(cam_ref) or not cam_ref.is_current():
				return
			var d: float = get_process_delta_time()
			var move: Vector3 = Vector3.ZERO
			if Input.is_key_pressed(KEY_W): move -= cam_ref.global_transform.basis.z
			if Input.is_key_pressed(KEY_S): move += cam_ref.global_transform.basis.z
			if Input.is_key_pressed(KEY_A): move -= cam_ref.global_transform.basis.x
			if Input.is_key_pressed(KEY_D): move += cam_ref.global_transform.basis.x
			if Input.is_key_pressed(KEY_Q): move -= Vector3.UP
			if Input.is_key_pressed(KEY_E): move += Vector3.UP
			if move != Vector3.ZERO:
				cam_ref.global_position += move.normalized() * move_speed * d
	)

@rpc("any_peer","call_local","reliable")
func force_sync_position(peer_id: int, pos: Vector3) -> void:
	var player = _find_player_by_peer_id(peer_id)
	if player: player.global_position = pos

func _find_player_by_peer_id(peer_id: int) -> Node:
	return get_node_or_null(str(peer_id))

## Activates a spectator-style overhead camera for a player who crossed the finish.
## Unlike _make_spectator (elimination), the player's body stays visible.
## The camera orbits/pans slowly so they can watch the remaining players.
func _activate_finish_spectator_camera(body: CharacterBody3D) -> void:
	var spec_cam := Camera3D.new()
	spec_cam.name = "FinishSpectatorCamera"
	# Position high above the finish area looking down
	spec_cam.global_position = body.global_position + Vector3(0.0, 14.0, 10.0)
	spec_cam.rotation_degrees = Vector3(-35.0, 180.0, 0.0)
	get_tree().current_scene.add_child(spec_cam)
	spec_cam.make_current()

	# Gentle slow pan so the spectating player sees the whole level
	var cam_ref: Camera3D = spec_cam
	var move_speed: float = 5.0
	get_tree().process_frame.connect(
		func() -> void:
			if not is_instance_valid(cam_ref) or not cam_ref.is_current():
				return
			var d: float = get_process_delta_time()
			var move: Vector3 = Vector3.ZERO
			if Input.is_key_pressed(KEY_W): move -= cam_ref.global_transform.basis.z
			if Input.is_key_pressed(KEY_S): move += cam_ref.global_transform.basis.z
			if Input.is_key_pressed(KEY_A): move -= cam_ref.global_transform.basis.x
			if Input.is_key_pressed(KEY_D): move += cam_ref.global_transform.basis.x
			if Input.is_key_pressed(KEY_Q): move -= Vector3.UP
			if Input.is_key_pressed(KEY_E): move += Vector3.UP
			if move != Vector3.ZERO:
				cam_ref.global_position += move.normalized() * move_speed * d
	)



## Shows the Yeti fact card for this round, then calls callback.
## Works in both SP and MP (fact always shown locally).
func _show_yeti_fact_then(callback: Callable) -> void:
	var fact_res := load(YETI_FACT_SCENE) as PackedScene
	if fact_res == null:
		await get_tree().create_timer(2.5).timeout
		callback.call()
		return
	var fact_screen = fact_res.instantiate()
	get_tree().current_scene.add_child(fact_screen)
	fact_screen.show_fact(yeti_fact_index)
	fact_screen.fact_dismissed.connect(func():
		if is_instance_valid(fact_screen):
			fact_screen.queue_free()
		callback.call()
	)

func _show_round_info_card() -> void:
	# Only show the info card the FIRST time the round is played.
	# If the user dies and respawns, it will skip this.
	if GameManager and GameManager.has_fact_been_shown(yeti_fact_index):
		# Skip card — respawn or mid-run restart, go straight to countdown
		if hud and hud.has_method("fade_from_black"):
			hud.fade_from_black(1.0)
		_begin_intro_countdown()
		return
		
	if GameManager:
		GameManager.mark_fact_shown(yeti_fact_index)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# ── Full-screen dimmed background ────────────────────────────────────────
	# z_index 101 puts this ABOVE the HUD's fade_rect (z_index 100)
	var bg = ColorRect.new()
	bg.name = "InfoCardBG"
	bg.color = Color(0.0, 0.0, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = 101

	# ── Card panel ────────────────────────────────────────────────────────────
	var card = PanelContainer.new()
	card.name = "RoundInfoCard"
	card.custom_minimum_size = Vector2(680, 0)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.07, 0.12, 1.0)
	card_style.corner_radius_top_left	= 18
	card_style.corner_radius_top_right   = 18
	card_style.corner_radius_bottom_right = 18
	card_style.corner_radius_bottom_left  = 18
	card_style.content_margin_left   = 50
	card_style.content_margin_right  = 50
	card_style.content_margin_top	= 40
	card_style.content_margin_bottom = 40
	card_style.border_width_left   = 3
	card_style.border_width_top	= 3
	card_style.border_width_right  = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.18, 0.82, 0.46)
	card.add_theme_stylebox_override("panel", card_style)

	# ── Content ───────────────────────────────────────────────────────────────
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = round_name
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Round Journey mini-list
	var journey_hdr = Label.new()
	journey_hdr.text = "🗺️  ROUND JOURNEY (8 Rounds)"
	journey_hdr.add_theme_font_size_override("font_size", 16)
	journey_hdr.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	vbox.add_child(journey_hdr)

	var round_names: Array[String] = [
		"1 · Himalayan Climb 🏔",
		"2 · Boudha Spinners ☸",
		"3 · Trishuli Crossing 🌊",
		"4 · Kathmandu Dash 🏃",
		"5 · Glacier Melt ❄",
		"6 · Bhanjyang Balance 🧊",
		"7 · Lava Doors 🌋",
		"8 · Avalanche Run 🌨",
	]
	var current_idx = GameManager.current_round_index if GameManager else 0
	var journey_grid = HFlowContainer.new()
	journey_grid.add_theme_constant_override("h_separation", 16)
	journey_grid.add_theme_constant_override("v_separation", 6)
	for i in round_names.size():
		var rn_lbl = Label.new()
		rn_lbl.text = round_names[i]
		rn_lbl.add_theme_font_size_override("font_size", 13)
		if i == current_idx:
			rn_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif i < current_idx:
			rn_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			rn_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		journey_grid.add_child(rn_lbl)
	vbox.add_child(journey_grid)

	vbox.add_child(HSeparator.new())
	var obj_hdr = Label.new()
	obj_hdr.text = "🎯  OBJECTIVE"
	obj_hdr.add_theme_font_size_override("font_size", 22)
	obj_hdr.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	vbox.add_child(obj_hdr)

	# Objective body
	var obj_lbl = Label.new()
	obj_lbl.text = _get_round_objective()
	obj_lbl.add_theme_font_size_override("font_size", 17)
	obj_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(obj_lbl)

	vbox.add_child(HSeparator.new())

	# Fact header
	var fact_hdr = Label.new()
	fact_hdr.text = "🇳🇵  DID YOU KNOW?"
	fact_hdr.add_theme_font_size_override("font_size", 22)
	fact_hdr.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	vbox.add_child(fact_hdr)

	# Fact body
	var fact_lbl = Label.new()
	fact_lbl.text = _get_round_fact()
	fact_lbl.add_theme_font_size_override("font_size", 17)
	fact_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	fact_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(fact_lbl)

	# ── Continue button ───────────────────────────────────────────────────────
	var btn = Button.new()
	btn.text = "▶   LET'S GO!"
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn.custom_minimum_size = Vector2(230, 64)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.80, 0.44)
	btn_normal.corner_radius_top_left	= 12
	btn_normal.corner_radius_top_right   = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.corner_radius_bottom_left  = 12
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.12, 0.62, 0.34)
	btn_hover.corner_radius_top_left	= 12
	btn_hover.corner_radius_top_right   = 12
	btn_hover.corner_radius_bottom_right = 12
	btn_hover.corner_radius_bottom_left  = 12
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.10, 0.50, 0.28)
	btn_pressed.corner_radius_top_left	= 12
	btn_pressed.corner_radius_top_right   = 12
	btn_pressed.corner_radius_bottom_right = 12
	btn_pressed.corner_radius_bottom_left  = 12
	btn.add_theme_stylebox_override("pressed", btn_pressed)

	var btn_center = CenterContainer.new()
	btn_center.add_child(btn)
	vbox.add_child(btn_center)

	# ── Layout: center card inside the full-screen bg ─────────────────────────
	var screen_center = CenterContainer.new()
	screen_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_center.add_child(card)
	bg.add_child(screen_center)

	if hud:
		hud.add_child(bg)

	# ── Button action ─────────────────────────────────────────────────────────
	btn.pressed.connect(func() -> void:
		bg.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if hud and hud.has_method("fade_from_black"):
			hud.fade_from_black(0.6)
		_begin_intro_countdown()
	)

func _get_round_objective() -> String:
	var name_lower = round_name.to_lower()
	if "climb" in name_lower:
		return "Climb up the steep Himalayan slopes, dodge the rolling boulders, and reach the summit shrine!"
	elif "spinner" in name_lower:
		return "Navigate through the spinning prayer wheels of Boudha, grab Momos, and reach the temple!"
	elif "crossing" in name_lower:
		return "Surpass every hurdle, jump across spinning prayer wheels and wooden boats, and reach the finish shrine!"
	elif "dash" in name_lower:
		return "Dash through the chaotic alleyways, weave around street stalls, and jump rooftops while dodging swooping kites!"
	elif "summit" in name_lower or "death" in name_lower:
		return "Survive the collapsing ice tiles until the timer runs out!"
	elif "memory" in name_lower:
		return "Memorize the pattern of the tiles and step only on the safe path to reach the finish!"
	elif "lava" in name_lower:
		return "Dodge the lava flows and choose the correct doors to progress!"
	elif "snowfield" in name_lower:
		return "Evade the wild Yeti and reach the final sanctuary!"
	else:
		return "Reach the finish line within the time limit!"

func _get_round_fact() -> String:
	var name_lower = round_name.to_lower()
	if "climb" in name_lower:
		return "Nepal is home to 8 of the world's 14 highest peaks, including Mt. Everest. The Himalayas were formed by the collision of the Indian and Eurasian tectonic plates."
	elif "spinner" in name_lower:
		return "Boudhanath Stupa is one of the largest unique spherical stupas in the world. The eyes painted on the stupa represent the all-seeing eyes of Buddha."
	elif "crossing" in name_lower:
		return "Trishuli River is one of the most famous rivers in Nepal for white-water rafting, named after the trishula (trident) of Lord Shiva."
	elif "dash" in name_lower:
		return "Kathmandu Valley has seven UNESCO World Heritage sites. The valley is known for its historical red-brick architecture and vibrant street life."
	elif "summit" in name_lower or "death" in name_lower:
		return "The Everest 'Death Zone' refers to altitudes above 8,000 meters. The oxygen level there is only about one-third of that at sea level."
	elif "memory" in name_lower:
		return "Traditional Nepali art includes Mithila paintings and Thanka scrolls, which require immense focus, memory, and precision."
	elif "lava" in name_lower:
		return "Nepal lies in a seismically active zone, with geothermal hot springs (Tato Pani) scattered across the mountainous regions."
	elif "snowfield" in name_lower:
		return "The Yeti, or Abominable Snowman, is a legendary ape-like creature said to inhabit the high Himalayan regions of Nepal."
	else:
		return "Nepal is a beautiful South Asian country known for its rich culture, diverse geography, and the warm hospitality of its people."
