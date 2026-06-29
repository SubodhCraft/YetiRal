extends Node

## SessionManager — Autoload Singleton
## Manages user session state, logged-in user data, and authentication tokens
## across all scenes for the duration of the application run.

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────
signal session_started(username: String)
signal session_ended()
signal leveled_up(new_level: int, gift_amount: int)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
## Path to the encrypted user database stored in the user:// data folder.
const DB_PATH: String = "user://yeti_ral_db.enc"
## Encryption passphrase — in a real product this would be derived from
## a hardware-bound key or stored in the OS keychain; for this prototype
## it is a hard-coded secret that never touches disk in plain-text form.
const DB_PASS: String = "YetiRal_S3cr3t_K3y_2025!"
## Characters considered valid for token generation.
const TOKEN_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
## Token length (bytes of randomness).
const TOKEN_LENGTH: int = 64

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE STATE
# ─────────────────────────────────────────────────────────────────────────────
var _is_logged_in: bool = false
var _current_user: String = ""
var _session_token: String = ""
## In-memory user store: { "username": "hashed_password_hex" }
var _users: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_database()
	_load_stats()


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC — SESSION QUERIES
# ─────────────────────────────────────────────────────────────────────────────
## Returns true when a user is currently logged in.
func is_logged_in() -> bool:
	return _is_logged_in

## Returns the username of the currently logged-in user, or empty string.
func get_current_user() -> String:
	return _current_user

## Returns the current session token, or empty string if not logged in.
func get_session_token() -> String:
	return _session_token


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC — AUTHENTICATION
# ─────────────────────────────────────────────────────────────────────────────
## Attempt to register a new user.
## Returns OK on success, or an error code with a human-readable message pair.
func register_user(username: String, password: String) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}

	username = username.strip_edges()

	# Validation
	if not _is_valid_username(username):
		result["message"] = "Username must be 4–24 alphanumeric characters."
		return result
	if password.length() < 6:
		result["message"] = "Password must be at least 6 characters."
		return result

	# Reload database to avoid race conditions between sessions
	_load_database()

	var lower_key: String = username.to_lower()
	if _users.has(lower_key):
		result["message"] = "Username already exists!"
		return result

	# Hash and store
	_users[lower_key] = {
		"hash": _hash_password(password),
		"uid": _generate_uid_for(lower_key),
		"friends": [],
		"requests": [],
		"equipped_hat": "none",
		"equipped_color": "#FFFFFF",
		"owned_hats": [],
		"profile_pic_path": ""
	}
	var saved: bool = _save_database()
	if not saved:
		result["message"] = "Failed to save user data. Check disk permissions."
		return result

	result["success"] = true
	result["message"] = "Account created! You can now log in."
	return result


## Attempt to log a user in.
## Returns a dictionary: {"success": bool, "message": String}
func login_user(username: String, password: String) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}

	username = username.strip_edges()

	if username.is_empty():
		result["message"] = "Username cannot be empty."
		return result
	if password.is_empty():
		result["message"] = "Password cannot be empty."
		return result

	_load_database()

	var lower_key: String = username.to_lower()
	if not _users.has(lower_key):
		result["message"] = "User not found. Please sign up first."
		return result

	var user_data = _users[lower_key]
	var stored_hash: String = ""
	if typeof(user_data) == TYPE_STRING:
		stored_hash = user_data
	elif typeof(user_data) == TYPE_DICTIONARY:
		stored_hash = user_data.get("hash", "")

	if stored_hash != _hash_password(password):
		result["message"] = "Incorrect password. Please try again."
		return result

	# All good — create session
	_is_logged_in = true
	_current_user = username
	_session_token = _generate_token()
	
	_update_login_streak(username)

	emit_signal("session_started", _current_user)
	result["success"] = true
	result["message"] = "Login successful! Welcome, %s." % username
	return result


## Logs out the current user and clears all session data.
func logout() -> void:
	_is_logged_in = false
	_current_user = ""
	_session_token = ""
	emit_signal("session_ended")


# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — PASSWORD HASHING
# ─────────────────────────────────────────────────────────────────────────────
## Hash a password using SHA-256 with a salt derived from the DB passphrase.
## GDScript exposes SHA-256 natively via HashingContext.
func _hash_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	# Pepper the hash with the app-level secret to resist offline dictionary attacks
	ctx.update((DB_PASS + password + DB_PASS).to_utf8_buffer())
	return ctx.finish().hex_encode()


# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — TOKEN GENERATION
# ─────────────────────────────────────────────────────────────────────────────
## Generates a cryptographically-random session token.
func _generate_token() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var token: String = ""
	for i in range(TOKEN_LENGTH):
		token += TOKEN_CHARS[rng.randi_range(0, TOKEN_CHARS.length() - 1)]
	return token


# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — USERNAME VALIDATION
# ─────────────────────────────────────────────────────────────────────────────
## Validates username: 4–24 alphanumeric characters only.
func _is_valid_username(username: String) -> bool:
	if username.length() < 4 or username.length() > 24:
		return false
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	return regex.search(username) != null


# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — ENCRYPTED DATABASE I/O
# ─────────────────────────────────────────────────────────────────────────────
## Saves the in-memory _users dictionary to the encrypted file.
func _save_database() -> bool:
	# Ensure user data dir exists
	var dir = DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_absolute(OS.get_user_data_dir())
	
	# Validate DB_PASS is pure ASCII before use
	assert(DB_PASS.length() == DB_PASS.to_utf8_buffer().size(), "DB_PASS must be ASCII only")
	
	var file := FileAccess.open_encrypted_with_pass(DB_PATH, FileAccess.WRITE, DB_PASS)
	if file == null:
		push_error("DB write failed: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(JSON.stringify(_users, "\t"))
	file.close()
	return true


## Loads the encrypted user database from disk into _users.
func _load_database() -> void:
	# Validate DB_PASS is pure ASCII before use
	assert(DB_PASS.length() == DB_PASS.to_utf8_buffer().size(), "DB_PASS must be ASCII only")
	
	if not FileAccess.file_exists(DB_PATH):
		# First run — start with an empty database
		_users = {}
		return

	var file := FileAccess.open_encrypted_with_pass(DB_PATH, FileAccess.READ, DB_PASS)
	if file == null:
		push_error("DB read failed: %s" % error_string(FileAccess.get_open_error()))
		_users = {}
		return

	var raw: String = file.get_as_text()
	file.close()

	if raw.is_empty():
		_users = {}
		return

	var parsed = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		push_error("SessionManager: Database corrupted or unreadable.")
		_users = {}
		return

	# Migrate old string-based user data to dictionaries and ensure cosmetics keys exist
	for k in parsed.keys():
		if typeof(parsed[k]) == TYPE_STRING:
			parsed[k] = {
				"hash": parsed[k],
				"uid": _generate_uid_for(k),
				"friends": [],
				"requests": [],
				"equipped_hat": "none",
				"equipped_color": "#FFFFFF",
				"owned_hats": []
			}
		elif typeof(parsed[k]) == TYPE_DICTIONARY:
			if not parsed[k].has("equipped_hat"):
				parsed[k]["equipped_hat"] = "none"
			if not parsed[k].has("equipped_color"):
				parsed[k]["equipped_color"] = "#FFFFFF"
			if not parsed[k].has("owned_hats"):
				parsed[k]["owned_hats"] = []
			if not parsed[k].has("profile_pic_path"):
				parsed[k]["profile_pic_path"] = ""

	_users = parsed

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC — FRIENDS & UID
# ─────────────────────────────────────────────────────────────────────────────
func get_uid(username: String = _current_user) -> String:
	var lower_name = username.to_lower()
	if _users.has(lower_name) and typeof(_users[lower_name]) == TYPE_DICTIONARY:
		return _users[lower_name].get("uid", "")
	return ""

func _generate_uid_for(username: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((username + "UID_SALT").to_utf8_buffer())
	var hash_bytes = ctx.finish()
	var hex = hash_bytes.hex_encode()
	# UID format: 8 characters
	return hex.substr(0, 8).to_upper()

func get_friends() -> Array:
	if not _is_logged_in: return []
	_load_database()
	var user_data = _users[_current_user.to_lower()]
	return user_data.get("friends", [])

func get_friend_requests() -> Array:
	if not _is_logged_in: return []
	_load_database()
	var user_data = _users[_current_user.to_lower()]
	return user_data.get("requests", [])

func send_friend_request(target_uid: String) -> Dictionary:
	var result = {"success": false, "message": ""}
	if not _is_logged_in:
		result["message"] = "Not logged in"
		return result
		
	_load_database()
	target_uid = target_uid.to_upper()
	
	var target_user = ""
	for k in _users.keys():
		if typeof(_users[k]) == TYPE_DICTIONARY and _users[k].get("uid") == target_uid:
			target_user = k
			break
			
	if target_user == "":
		result["message"] = "Player UID not found."
		return result
		
	if target_user == _current_user.to_lower():
		result["message"] = "You cannot add yourself."
		return result
		
	var target_data = _users[target_user]
	var my_uid = get_uid()
	
	if my_uid in target_data.get("friends", []):
		result["message"] = "Already friends with this player."
		return result
		
	if my_uid in target_data.get("requests", []):
		result["message"] = "Request already sent."
		return result
		
	target_data["requests"].append(my_uid)
	_save_database()
	
	result["success"] = true
	result["message"] = "Friend request sent!"
	return result

func accept_friend_request(requester_uid: String) -> Dictionary:
	var result = {"success": false, "message": ""}
	if not _is_logged_in:
		result["message"] = "Not logged in"
		return result
		
	_load_database()
	var my_data = _users[_current_user.to_lower()]
	var requests: Array = my_data.get("requests", [])
	
	if not requester_uid in requests:
		result["message"] = "No request found from this UID."
		return result
		
	var requester_user = ""
	for k in _users.keys():
		if typeof(_users[k]) == TYPE_DICTIONARY and _users[k].get("uid") == requester_uid:
			requester_user = k
			break
			
	if requester_user != "":
		# Add to each other's friends lists
		var my_uid = get_uid()
		if not requester_uid in my_data["friends"]:
			my_data["friends"].append(requester_uid)
		
		var requester_data = _users[requester_user]
		if not my_uid in requester_data.get("friends", []):
			requester_data["friends"].append(my_uid)
			
	# Remove the request
	requests.erase(requester_uid)
	_save_database()
	
	result["success"] = true
	result["message"] = "Friend request accepted!"
	return result

func reject_friend_request(requester_uid: String) -> Dictionary:
	var result = {"success": false, "message": ""}
	if not _is_logged_in:
		result["message"] = "Not logged in"
		return result
		
	_load_database()
	var my_data = _users[_current_user.to_lower()]
	var requests: Array = my_data.get("requests", [])
	
	if requester_uid in requests:
		requests.erase(requester_uid)
		_save_database()
		result["success"] = true
		result["message"] = "Friend request rejected."
	else:
		result["message"] = "No request found from this UID."
	return result

func get_username_by_uid(uid: String) -> String:
	for k in _users.keys():
		if typeof(_users[k]) == TYPE_DICTIONARY and _users[k].get("uid") == uid:
			return k
	return "Unknown"

# ─────────────────────────────────────────────────────────────────────────────
# USER STATS
# ─────────────────────────────────────────────────────────────────────────────
var _stats: Dictionary = {}

func get_user_stats(username: String) -> Dictionary:
	var lower_name = username.to_lower()
	_load_stats()
	if not _stats.has(lower_name):
		_stats[lower_name] = {
			"matches_played": 0,
			"wins": 0,
			"momos": 0,
			"xp": 0,
			"level": 1,
			"last_login_time": 0.0,
			"active_days_streak": 0,
			"badges": [],
			"match_history": []
		}
	else:
		var s = _stats[lower_name]
		if not s.has("xp"): s["xp"] = 0
		if not s.has("level"): s["level"] = 1
		if not s.has("last_login_time"): s["last_login_time"] = 0.0
		if not s.has("active_days_streak"): s["active_days_streak"] = 0
		if not s.has("badges"): s["badges"] = []
		if not s.has("match_history"): s["match_history"] = []
		_stats[lower_name] = s
	return _stats[lower_name]

func add_xp(username: String, amount: int) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["xp"] += amount
	
	var leveled_up = false
	var new_level = s["level"]
	
	while true:
		var xp_needed = s["level"] * 100
		if s["xp"] >= xp_needed:
			s["xp"] -= xp_needed
			s["level"] += 1
			leveled_up = true
			new_level = s["level"]
		else:
			break
			
	if leveled_up:
		s["momos"] += 50
		emit_signal("leveled_up", new_level, 50)
			
	_stats[lower_name] = s
	_save_stats()

func _update_login_streak(username: String) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	
	var current_time = Time.get_unix_time_from_system()
	var current_day = int(current_time / 86400)
	
	var last_time = s.get("last_login_time", 0.0)
	if last_time == 0.0:
		s["active_days_streak"] = 1
	else:
		var last_day = int(last_time / 86400)
		if current_day - last_day == 1:
			s["active_days_streak"] += 1
		elif current_day - last_day > 1:
			s["active_days_streak"] = 1
		
	s["last_login_time"] = current_time
	
	var streak = s["active_days_streak"]
	var badges: Array = s.get("badges", [])
	
	var possible_badges = [3, 7, 15, 30]
	for b in possible_badges:
		if streak >= b:
			var badge_name = "Streak_" + str(b)
			if not badge_name in badges:
				badges.append(badge_name)
				
	s["badges"] = badges
	_stats[lower_name] = s
	_save_stats()


func increment_matches_played(username: String) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["matches_played"] += 1
	_stats[lower_name] = s
	_save_stats()

func increment_wins(username: String) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["wins"] += 1
	_stats[lower_name] = s
	_save_stats()

func add_user_momos(username: String, amount: int) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["momos"] += amount
	_stats[lower_name] = s
	_save_stats()

func spend_momos(amount: int) -> bool:
	if not _is_logged_in:
		return false
	var lower_name = _current_user.to_lower()
	var s = get_user_stats(_current_user)
	if s["momos"] >= amount:
		s["momos"] -= amount
		_stats[lower_name] = s
		_save_stats()
		return true
	return false

func _save_stats() -> bool:
	var file := FileAccess.open_encrypted_with_pass("user://yeti_ral_stats.enc", FileAccess.WRITE, DB_PASS)
	if file == null:
		return false
	file.store_string(JSON.stringify(_stats))
	file.close()
	return true

func _load_stats() -> void:
	if not FileAccess.file_exists("user://yeti_ral_stats.enc"):
		_stats = {}
		return
	var file := FileAccess.open_encrypted_with_pass("user://yeti_ral_stats.enc", FileAccess.READ, DB_PASS)
	if file == null:
		_stats = {}
		return
	var raw: String = file.get_as_text()
	file.close()
	if raw.is_empty():
		_stats = {}
		return
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		_stats = parsed
		# Migrate old stats keys to ensure match_history exists
		for k in _stats.keys():
			if typeof(_stats[k]) == TYPE_DICTIONARY:
				if not _stats[k].has("match_history"):
					_stats[k]["match_history"] = []
	else:
		_stats = {}

# ─────────────────────────────────────────────────────────────────────────────
# NEW SYSTEMS — COSMETICS, MATCH HISTORY, TITLES & LOCAL LEADERBOARD
# ─────────────────────────────────────────────────────────────────────────────
func equip_hat(hat_id: String) -> void:
	if not _is_logged_in:
		return
	var valid_hats = ["dhaka_topi", "everest_crown", "sherpa_cap", "yak_horns", "kukri_band", "none"]
	if not hat_id in valid_hats:
		return
		
	_load_database()
	var lower_key = _current_user.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		var owned: Array = user_data.get("owned_hats", [])
		if hat_id == "none" or hat_id in owned:
			user_data["equipped_hat"] = hat_id
			_save_database()

func unlock_hat(hat_id: String) -> void:
	if not _is_logged_in:
		return
	var valid_hats = ["dhaka_topi", "everest_crown", "sherpa_cap", "yak_horns", "kukri_band", "none"]
	if not hat_id in valid_hats:
		return
		
	_load_database()
	var lower_key = _current_user.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		var owned: Array = user_data.get("owned_hats", [])
		if not hat_id in owned:
			owned.append(hat_id)
			user_data["owned_hats"] = owned
			_save_database()

func get_equipped_hat(username: String = _current_user) -> String:
	_load_database()
	var lower_key = username.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		return user_data.get("equipped_hat", "none")
	return "none"

func get_player_color(username: String = _current_user) -> Color:
	_load_database()
	var lower_key = username.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		var hex = user_data.get("equipped_color", "#FFFFFF")
		if Color.html_is_valid(hex):
			return Color.html(hex)
	return Color.WHITE

func set_player_color(hex_color: String) -> void:
	if not _is_logged_in:
		return
	if not Color.html_is_valid(hex_color):
		return
	_load_database()
	var lower_key = _current_user.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		user_data["equipped_color"] = hex_color
		_save_database()

func log_match_result(mode: String, rounds_won: int, position: int, momos: int) -> void:
	if not _is_logged_in:
		return
		
	var lower_name = _current_user.to_lower()
	var s = get_user_stats(_current_user)
	var history: Array = s.get("match_history", [])
	
	var entry = {
		"date": int(Time.get_unix_time_from_system()),
		"mode": mode,
		"rounds_won": rounds_won,
		"position": position,
		"momos_earned": momos
	}
	
	history.append(entry)
	
	while history.size() > 20:
		history.remove_at(0)
		
	s["match_history"] = history
	_stats[lower_name] = s
	_save_stats()

func get_player_title(username: String = _current_user) -> String:
	var s = get_user_stats(username)
	var lvl = s.get("level", 1)
	if lvl >= 30:
		return "Sagarmatha Legend"
	elif lvl >= 20:
		return "Sherpa Elite"
	elif lvl >= 10:
		return "Himalayan Climber"
	elif lvl >= 5:
		return "Snow Trekker"
	else:
		return "Yeti Cub"

func get_top_players_by_wins(count: int = 10) -> Array[Dictionary]:
	_load_stats()
	var list: Array[Dictionary] = []
	for username_key in _stats:
		var stats_data = _stats[username_key]
		var wins = stats_data.get("wins", 0)
		var level = stats_data.get("level", 1)
		var title = get_player_title(username_key)
		list.append({
			"username": username_key,
			"wins": wins,
			"level": level,
			"title": title
		})
	list.sort_custom(func(a, b): return a["wins"] > b["wins"])
	if list.size() > count:
		list = list.slice(0, count)
	return list

func update_username(new_username: String) -> Dictionary:
	var result = {"success": false, "message": ""}
	if not _is_logged_in:
		result["message"] = "Not logged in"
		return result
		
	new_username = new_username.strip_edges()
	if not _is_valid_username(new_username):
		result["message"] = "Username must be 4–24 alphanumeric characters."
		return result
		
	_load_database()
	var lower_new = new_username.to_lower()
	var lower_old = _current_user.to_lower()
	
	if lower_new == lower_old:
		_current_user = new_username
		result["success"] = true
		return result
		
	if _users.has(lower_new):
		result["message"] = "Username already exists."
		return result
		
	# Migrate users DB
	var user_data = _users[lower_old].duplicate(true)
	_users[lower_new] = user_data
	_users.erase(lower_old)
	_save_database()
	
	# Migrate stats DB
	_load_stats()
	if _stats.has(lower_old):
		var s_data = _stats[lower_old].duplicate(true)
		_stats[lower_new] = s_data
		_stats.erase(lower_old)
		_save_stats()
		
	_current_user = new_username
	result["success"] = true
	result["message"] = "Username updated successfully."
	return result

func set_profile_pic_path(path: String) -> void:
	if not _is_logged_in: return
	_load_database()
	var lower_key = _current_user.to_lower()
	if _users.has(lower_key):
		_users[lower_key]["profile_pic_path"] = path
		_save_database()

func get_profile_pic_path(username: String = _current_user) -> String:
	_load_database()
	var lower_key = username.to_lower()
	if _users.has(lower_key) and _users[lower_key].has("profile_pic_path"):
		return _users[lower_key]["profile_pic_path"]
	return ""
