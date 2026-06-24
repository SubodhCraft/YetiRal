extends Node

signal stats_changed

# ─── SINGLEPLAYER STATE ───────────────────────────────────────────────────────
var lives: int = 3
var momos: int = 0
var current_round_index: int = 0

# Singleplayer always plays rounds IN ORDER (Round1 → Round2 → Round3 → Round4 → Round5)
const ROUNDS: Array[String] = [
	"res://scenes/gameplay/rounds/Round1_HimalayanClimb.tscn",
	"res://scenes/gameplay/rounds/Round2_BoudhaSpinners.tscn",
	"res://scenes/gameplay/rounds/Round3_TrishuliCrossing.tscn",
	"res://scenes/gameplay/rounds/Round4_KathmanduDash.tscn",
	"res://scenes/gameplay/rounds/Round5_EverestSummit.tscn",
	"res://scenes/gameplay/rounds/Round6_MemoryTiles.tscn",
	"res://scenes/gameplay/rounds/Round7_LavaDoors.tscn"
]

const VICTORY_SCENE: String = "res://scenes/ui/VictoryScreen.tscn"
const GAME_OVER_SCENE: String = "res://scenes/ui/GameOverScreen.tscn"
const DASHBOARD_SCENE: String = "res://Dashboard.tscn"

var is_transitioning: bool = false

# ─── MULTIPLAYER STATE ────────────────────────────────────────────────────────
var is_multiplayer: bool = false
var multiplayer_rounds: Array = []        # Shuffled for MP (random order)
var player_scores: Dictionary = {}        # peer_id -> score
var player_momos: Dictionary = {}         # peer_id -> momos count
var round_finishes: Array = []            # peer_ids in finish order
var player_finished_status: Dictionary = {} # peer_id -> bool

# ─────────────────────────────────────────────────────────────────────────────
# SINGLEPLAYER FLOW
# Rounds always go in FIXED order: 1 → 2 → 3 → 4 → 5
# No shuffling. Player name tags are NOT shown in singleplayer.
# ─────────────────────────────────────────────────────────────────────────────
func start_game() -> void:
	is_multiplayer = false
	lives = 3
	momos = 0
	current_round_index = 0
	is_transitioning = false
	stats_changed.emit()
	_load_sp_round()

func _load_sp_round() -> void:
	if current_round_index >= 0 and current_round_index < ROUNDS.size():
		get_tree().call_deferred("change_scene_to_file", ROUNDS[current_round_index])
	else:
		show_victory()

func next_round() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	current_round_index += 1
	if SessionManager.is_logged_in():
		SessionManager.add_xp(SessionManager.get_current_user(), 50)
	stats_changed.emit()
	if current_round_index >= ROUNDS.size():
		show_victory()
	else:
		_load_sp_round()
	get_tree().create_timer(0.5).timeout.connect(func():
		is_transitioning = false
	)

func lose_life() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	lives -= 1
	stats_changed.emit()
	if lives <= 0:
		show_game_over()
	else:
		_load_sp_round()  # Retry current round
	get_tree().create_timer(0.5).timeout.connect(func():
		is_transitioning = false
	)

func add_momo(amount: int = 1) -> void:
	momos += amount
	if SessionManager.is_logged_in():
		SessionManager.add_xp(SessionManager.get_current_user(), amount * 5)
	stats_changed.emit()

func show_game_over() -> void:
	get_tree().call_deferred("change_scene_to_file", GAME_OVER_SCENE)

func show_victory() -> void:
	get_tree().call_deferred("change_scene_to_file", VICTORY_SCENE)

func return_to_dashboard() -> void:
	is_multiplayer = false
	get_tree().call_deferred("change_scene_to_file", DASHBOARD_SCENE)

# ─────────────────────────────────────────────────────────────────────────────
# MULTIPLAYER FLOW
# Rounds are RANDOMISED in order (all 5 rounds played, in a shuffled sequence).
# Player name tags ARE shown in multiplayer (handled by BaseRound).
# ─────────────────────────────────────────────────────────────────────────────
func start_multiplayer_game() -> void:
	is_multiplayer = true
	current_round_index = 0
	player_scores.clear()
	player_momos.clear()

	# Shuffle all rounds for random order in multiplayer
	multiplayer_rounds = ROUNDS.duplicate()
	multiplayer_rounds.shuffle()

	for pid in NetworkManager.players:
		player_scores[pid] = 0
		player_momos[pid] = 0

	_load_mp_round()

func _load_mp_round() -> void:
	round_finishes.clear()
	player_finished_status.clear()
	for pid in NetworkManager.players:
		player_finished_status[pid] = false

	if current_round_index >= 0 and current_round_index < multiplayer_rounds.size():
		get_tree().call_deferred("change_scene_to_file", multiplayer_rounds[current_round_index])
	else:
		show_multiplayer_victory()

func add_momo_to_peer(peer_id: int, amount: int) -> void:
	player_momos[peer_id] = player_momos.get(peer_id, 0) + amount
	player_scores[peer_id] = player_scores.get(peer_id, 0) + amount
	if peer_id == multiplayer.get_unique_id() and SessionManager.is_logged_in():
		SessionManager.add_xp(SessionManager.get_current_user(), amount * 5)
	stats_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func submit_finish(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not player_finished_status.get(peer_id, false):
		player_finished_status[peer_id] = true
		round_finishes.append(peer_id)
		rpc("sync_round_finishes", round_finishes)

		var all_finished = true
		for pid in NetworkManager.players:
			if not player_finished_status.get(pid, false):
				all_finished = false
				break
		if all_finished:
			get_tree().create_timer(3.0).timeout.connect(func():
				host_advance_round()
			)

@rpc("authority", "call_local", "reliable")
func sync_round_finishes(updated_finishes: Array) -> void:
	round_finishes = updated_finishes
	stats_changed.emit()

func host_advance_round() -> void:
	if not multiplayer.is_server():
		return
	# Award placement points: 1st=10, 2nd=8, 3rd=6, 4th=4, 5th=2
	var placement_points = [10, 8, 6, 4, 2]
	for i in range(round_finishes.size()):
		var pid = round_finishes[i]
		var pts = placement_points[min(i, placement_points.size() - 1)]
		player_scores[pid] = player_scores.get(pid, 0) + pts
	var next_idx = current_round_index + 1
	rpc("goto_multiplayer_round", next_idx, player_scores)

@rpc("authority", "call_local", "reliable")
func goto_multiplayer_round(next_index: int, synced_scores: Dictionary) -> void:
	player_scores = synced_scores
	if multiplayer.get_unique_id() in round_finishes:
		if SessionManager.is_logged_in():
			SessionManager.add_xp(SessionManager.get_current_user(), 50)
	current_round_index = next_index
	if current_round_index >= multiplayer_rounds.size():
		show_multiplayer_victory()
	else:
		_load_mp_round()

func show_multiplayer_victory() -> void:
	get_tree().call_deferred("change_scene_to_file", VICTORY_SCENE)
