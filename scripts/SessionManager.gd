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

var pending_level_ups: Array[Dictionary] = []

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

var backend_ip: String = "127.0.0.1"

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	pass

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

	if not APIManager:
		result["message"] = "APIManager not found!"
		return result
		
	var payload = {"username": username, "password": password}
	var res_data: Dictionary = await _make_api_call("/register", HTTPClient.METHOD_POST, payload)
	
	if res_data.get("success", false):
		result["success"] = true
		result["message"] = "Account created! You can now log in."
	else:
		result["message"] = res_data.get("message", "Registration failed.")
		
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

	if not APIManager:
		result["message"] = "APIManager not found!"
		return result
		
	var payload = {"username": username, "password": password}
	var res_data: Dictionary = await _make_api_call("/login", HTTPClient.METHOD_POST, payload)
	
	if res_data.get("success", false):
		_is_logged_in = true
		_current_user = username
		_current_uid = res_data.get("uid", "")
		_session_token = _generate_token()
		
		# Fetch initial stats
		var stats_res = await _make_api_call("/stats/" + username, HTTPClient.METHOD_GET)
		if stats_res:
			_stats[username.to_lower()] = stats_res
		
		# Fetch profile data (profile pic, hat, color) from backend DB
		var profile_res = await _make_api_call("/user/profile/" + username, HTTPClient.METHOD_GET)
		if profile_res.get("success", false):
			var lower_key = username.to_lower()
			if not _users.has(lower_key):
				_users[lower_key] = {}
			_users[lower_key]["profile_pic_b64"] = profile_res.get("profile_pic_b64", "")
			if profile_res.has("equipped_hat"):
				_users[lower_key]["equipped_hat"] = profile_res.get("equipped_hat", "none")
			if profile_res.has("equipped_color"):
				_users[lower_key]["equipped_color"] = profile_res.get("equipped_color", "#FFFFFF")
			if profile_res.has("owned_hats"):
				_users[lower_key]["owned_hats"] = profile_res.get("owned_hats", [])
		
		await fetch_friends_async()
		emit_signal("session_started", _current_user)
		result["success"] = true
		result["message"] = "Login successful! Welcome, %s." % username
	else:
		result["message"] = res_data.get("message", "Login failed.")
		
	return result

func _make_api_call(endpoint: String, method: int, payload: Dictionary = {}) -> Dictionary:
	var req = HTTPRequest.new()
	add_child(req)
	var url = "http://" + backend_ip + ":5000" + endpoint
	var headers = ["Content-Type: application/json"]
	
	var err
	if method == HTTPClient.METHOD_GET:
		err = req.request(url, headers, method)
	else:
		err = req.request(url, headers, method, JSON.stringify(payload))
		
	if err != OK:
		req.queue_free()
		return {"success": false, "message": "Connection error."}
		
	var response = await req.request_completed
	req.queue_free()
	
	var res_result = response[0]
	var res_code = response[1]
	var body = response[3]
	
	if res_result == HTTPRequest.RESULT_SUCCESS:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				return data
	return {"success": false, "message": "Server error (Code %d)." % res_code}


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
# PRIVATE — ENCRYPTED DATABASE I/O (Removed, logic moved to Python server)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC — FRIENDS & UID
# ─────────────────────────────────────────────────────────────────────────────
var _current_uid: String = ""
func get_uid(username: String = _current_user) -> String:
	return _current_uid

func _generate_uid_for(username: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((username + "UID_SALT").to_utf8_buffer())
	var hash_bytes = ctx.finish()
	var hex = hash_bytes.hex_encode()
	# UID format: 8 characters
	return hex.substr(0, 8).to_upper()

var _friends_cache: Array = []
var _requests_cache: Array = []

func fetch_friends_async() -> void:
	if not _is_logged_in: return
	var res = await _make_api_call("/friends/list/" + _current_user, HTTPClient.METHOD_GET)
	if res.has("friends"):
		_friends_cache = res["friends"]
		_requests_cache = res["requests"]

func get_friends() -> Array:
	return _friends_cache

func get_friend_requests() -> Array:
	return _requests_cache

func send_friend_request(target_uid: String) -> Dictionary:
	var payload = {"sender": _current_user, "target_uid": target_uid}
	var res = await _make_api_call("/friends/send_request", HTTPClient.METHOD_POST, payload)
	await fetch_friends_async()
	return res

func accept_friend_request(requester_uid: String) -> Dictionary:
	var payload = {"username": _current_user, "requester_uid": requester_uid}
	var res = await _make_api_call("/friends/accept_request", HTTPClient.METHOD_POST, payload)
	await fetch_friends_async()
	return res

func reject_friend_request(requester_uid: String) -> Dictionary:
	var payload = {"username": _current_user, "requester_uid": requester_uid}
	var res = await _make_api_call("/friends/reject_request", HTTPClient.METHOD_POST, payload)
	await fetch_friends_async()
	return res

func get_username_by_uid(uid: String) -> String:
	for f in _friends_cache:
		if f.get("uid") == uid: return f.get("username", "Unknown")
	return "Unknown"

# ─────────────────────────────────────────────────────────────────────────────
# USER STATS  (server-backed — no local storage)
# ─────────────────────────────────────────────────────────────────────────────
var _stats: Dictionary = {}

func get_user_stats(username: String) -> Dictionary:
	var lower_name = username.to_lower()
	if not _stats.has(lower_name):
		_stats[lower_name] = {
			"matches_played": 0, "wins": 0, "momos": 0, "xp": 0, "level": 1,
			"last_login_time": 0.0, "active_days_streak": 0, "badges": [], "match_history": []
		}
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
		pending_level_ups.append({"level": new_level, "gift": 50})

	_stats[lower_name] = s
	# Persist to server
	var payload = {"username": lower_name, "xp": s["xp"], "level": s["level"], "momos_delta": 0}
	if leveled_up: payload["momos_delta"] = 50
	_make_api_call("/stats/sync", HTTPClient.METHOD_POST, {
		"username": lower_name, "xp": s["xp"], "level": s["level"], "momos": s["momos"]
	})

func consume_pending_level_ups() -> Array:
	var pending = pending_level_ups.duplicate()
	pending_level_ups.clear()
	return pending

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
	_make_api_call("/stats/update", HTTPClient.METHOD_POST, {
		"username": lower_name,
		"last_login_time": current_time,
		"active_days_streak": s["active_days_streak"],
		"badges": badges
	})


func increment_matches_played(username: String) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["matches_played"] += 1
	_stats[lower_name] = s
	_make_api_call("/stats/update", HTTPClient.METHOD_POST, {"username": lower_name, "matches_played_delta": 1})

func increment_wins(username: String) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["wins"] += 1
	_stats[lower_name] = s
	_make_api_call("/stats/update", HTTPClient.METHOD_POST, {"username": lower_name, "wins_delta": 1})

func add_user_momos(username: String, amount: int) -> void:
	var lower_name = username.to_lower()
	var s = get_user_stats(username)
	s["momos"] += amount
	_stats[lower_name] = s
	_make_api_call("/stats/update", HTTPClient.METHOD_POST, {"username": lower_name, "momos_delta": amount})

func spend_momos(amount: int) -> bool:
	if not _is_logged_in:
		return false
	var lower_name = _current_user.to_lower()
	var s = get_user_stats(_current_user)
	if s["momos"] >= amount:
		s["momos"] -= amount
		_stats[lower_name] = s
		_make_api_call("/stats/update", HTTPClient.METHOD_POST, {"username": lower_name, "momos_delta": -amount})
		return true
	return false

# _save_stats and _load_stats removed — all stats are now stored on the backend server.

# ─────────────────────────────────────────────────────────────────────────────
# NEW SYSTEMS — COSMETICS, MATCH HISTORY, TITLES & LOCAL LEADERBOARD
# ─────────────────────────────────────────────────────────────────────────────
func equip_hat(hat_id: String) -> void:
	if not _is_logged_in:
		return
	var lower_key = _current_user.to_lower()
	# Update local cache for immediate display
	var user_data = _users.get(lower_key, {})
	user_data["equipped_hat"] = hat_id
	_users[lower_key] = user_data
	# Persist to server
	_make_api_call("/user/equip_hat", HTTPClient.METHOD_POST, {"username": lower_key, "hat_id": hat_id})

func unlock_hat(hat_id: String) -> void:
	if not _is_logged_in:
		return
	var lower_key = _current_user.to_lower()
	# Update local cache
	var user_data = _users.get(lower_key, {})
	var owned: Array = user_data.get("owned_hats", [])
	if not hat_id in owned:
		owned.append(hat_id)
	user_data["owned_hats"] = owned
	_users[lower_key] = user_data
	# Persist to server
	_make_api_call("/user/unlock_hat", HTTPClient.METHOD_POST, {"username": lower_key, "hat_id": hat_id})

func get_owned_items() -> Array:
	if not _is_logged_in:
		return []
	var lower_key = _current_user.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		return user_data.get("owned_hats", [])
	return []

func change_password(old_password: String, new_password: String) -> Dictionary:
	if not _is_logged_in:
		return {"ok": false, "msg": "Not logged in."}
	if new_password.length() < 6:
		return {"ok": false, "msg": "New password must be at least 6 characters."}
	
	var payload = {
		"username": _current_user.to_lower(),
		"old_password": old_password,
		"new_password": new_password
	}
	var res = await _make_api_call("/change_password", HTTPClient.METHOD_POST, payload)
	if res.get("success", false):
		return {"ok": true, "msg": res.get("message", "Password changed successfully!")}
	else:
		return {"ok": false, "msg": res.get("message", "Password change failed.")}

func get_equipped_hat(username: String = _current_user) -> String:
	var lower_key = username.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		return user_data.get("equipped_hat", "none")
	return "none"

func get_player_color(username: String = _current_user) -> Color:
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
	var lower_key = _current_user.to_lower()
	var user_data = _users.get(lower_key)
	if user_data and typeof(user_data) == TYPE_DICTIONARY:
		user_data["equipped_color"] = hex_color
		_make_api_call("/user/update_color", HTTPClient.METHOD_POST, {"username": lower_key, "color": hex_color})

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

	# Send match entry to server
	_make_api_call("/stats/update", HTTPClient.METHOD_POST, {
		"username": lower_name,
		"match_history_entry": entry
	})

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
	
	# Stats migration is server-side; the server retains the old username's stats
	# until a dedicated rename endpoint is added.
	_current_user = new_username
	result["success"] = true
	result["message"] = "Username updated successfully."
	return result

func set_profile_pic_b64(b64_string: String) -> void:
	if not _is_logged_in: return
	var lower_key = _current_user.to_lower()
	if _users.has(lower_key):
		_users[lower_key]["profile_pic_b64"] = b64_string
	# Push base64 string to Flask backend
	var payload = {"username": _current_user, "profile_pic_b64": b64_string}
	_make_api_call("/user/set_profile_pic", HTTPClient.METHOD_POST, payload)

func get_profile_pic_b64(username: String = _current_user) -> String:
	var lower_key = username.to_lower()
	if _users.has(lower_key) and _users[lower_key].has("profile_pic_b64"):
		return _users[lower_key]["profile_pic_b64"]
	return ""
