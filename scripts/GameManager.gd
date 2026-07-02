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
	"res://scenes/gameplay/rounds/Round7_LavaDoors.tscn",
	"res://scenes/gameplay/rounds/Round8_YetiSnowfield.tscn"
]

const VICTORY_SCENE: String = "res://scenes/ui/VictoryScreen.tscn"
const GAME_OVER_SCENE: String = "res://scenes/ui/GameOverScreen.tscn"
const DASHBOARD_SCENE: String = "res://Dashboard.tscn"

var is_transitioning: bool = false

# ─── MULTIPLAYER STATE ────────────────────────────────────────────────────────
var is_multiplayer: bool = false
var multiplayer_rounds: Array = []        # Shuffled for MP (synced from host)
var player_scores: Dictionary = {}        # peer_id -> score
var player_momos: Dictionary = {}         # peer_id -> momos count
var round_finishes: Array = []            # peer_ids in finish order this round
var player_finished_status: Dictionary = {} # peer_id -> bool (finished)
var mp_leaderboard: Array = []            # sorted [{"id": pid, "score": n, "username": s}]

# ─── FACT TRACKING ────────────────────────────────────────────────────────────
var shown_facts: Array[int] = []

func mark_fact_shown(index: int) -> void:
	if not shown_facts.has(index):
		shown_facts.append(index)

func has_fact_been_shown(index: int) -> bool:
	return shown_facts.has(index)

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
	shown_facts.clear()
	is_transitioning = false
	stats_changed.emit()
	# Track that a match was started
	if SessionManager and SessionManager.is_logged_in():
		SessionManager.increment_matches_played(SessionManager.get_current_user())
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
		if AudioManager and AudioManager.has_method("play_game_over_sfx"):
			AudioManager.play_game_over_sfx()
		show_game_over()
	else:
		if AudioManager and AudioManager.has_method("play_death_sfx"):
			AudioManager.play_death_sfx()
		
		# Wait 3 seconds for the Mario Death sound to finish playing
		await get_tree().create_timer(3.0).timeout
		
		_load_sp_round()  # Retry current round
	get_tree().create_timer(0.5).timeout.connect(func():
		is_transitioning = false
	)

func lose_life_instant() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	lives -= 1
	stats_changed.emit()
	if lives <= 0:
		if AudioManager and AudioManager.has_method("play_game_over_sfx"):
			AudioManager.play_game_over_sfx()
		show_game_over()
	else:
		_load_sp_round()  # Retry current round
	get_tree().create_timer(0.5).timeout.connect(func():
		is_transitioning = false
	)

func add_momo(amount: int = 1) -> void:
	momos += amount
	if SessionManager.is_logged_in():
		SessionManager.add_user_momos(SessionManager.get_current_user(), amount)
		SessionManager.add_xp(SessionManager.get_current_user(), amount * 5)
	stats_changed.emit()

func show_game_over() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", GAME_OVER_SCENE)

func show_victory() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Track win for the current user
	if SessionManager and SessionManager.is_logged_in():
		SessionManager.increment_wins(SessionManager.get_current_user())
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
	shown_facts.clear()
	player_scores.clear()
	player_momos.clear()
	mp_leaderboard.clear()

	for pid in NetworkManager.players:
		player_scores[pid] = 0
		player_momos[pid] = 0

	# Only the HOST generates and distributes the map order
	# Rounds play in fixed sequential order: Round 1 → Round 2 → ... → Round 8
	if multiplayer.is_server():
		var ordered = ROUNDS.duplicate()
		# Use string array for RPC compatibility
		rpc("sync_round_list", ordered)

func _load_mp_round() -> void:
	round_finishes.clear()
	player_finished_status.clear()
	for pid in NetworkManager.players:
		player_finished_status[pid] = false

	if current_round_index >= 0 and current_round_index < multiplayer_rounds.size():
		get_tree().call_deferred("change_scene_to_file", multiplayer_rounds[current_round_index])
	else:
		show_multiplayer_victory()

@rpc("authority", "call_local", "reliable")
func sync_round_list(shuffled_rounds: Array) -> void:
	multiplayer_rounds = shuffled_rounds
	_load_mp_round()

func add_momo_to_peer(peer_id: int, amount: int) -> void:
	player_momos[peer_id] = player_momos.get(peer_id, 0) + amount
	player_scores[peer_id] = player_scores.get(peer_id, 0) + amount
	if peer_id == multiplayer.get_unique_id() and SessionManager.is_logged_in():
		SessionManager.add_user_momos(SessionManager.get_current_user(), amount)
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
	# Award placement points for finishers only: 1st=10, 2nd=7, 3rd=5, 4th=3, 5th=1
	var placement_points = [10, 7, 5, 3, 1]
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
	# Build the sorted leaderboard before switching scene
	mp_leaderboard.clear()
	for pid in player_scores:
		var username = "Player"
		if NetworkManager.players.has(pid):
			username = NetworkManager.players[pid].get("username", "Player")
		mp_leaderboard.append({"id": pid, "score": player_scores[pid], "username": username})
	mp_leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Award XP/momos based on final placement
	if SessionManager and SessionManager.is_logged_in():
		var my_id = multiplayer.get_unique_id()
		var my_pos = 0
		for i in mp_leaderboard.size():
			if mp_leaderboard[i]["id"] == my_id:
				my_pos = i
				break
		var xp_rewards = [200, 100, 50]
		var momo_rewards = [30, 15, 5]
		var xp = xp_rewards[min(my_pos, xp_rewards.size() - 1)]
		var momos_reward = momo_rewards[min(my_pos, momo_rewards.size() - 1)]
		SessionManager.add_xp(SessionManager.get_current_user(), xp)
		SessionManager.add_user_momos(SessionManager.get_current_user(), momos_reward)
		SessionManager.increment_wins(SessionManager.get_current_user())
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", VICTORY_SCENE)
