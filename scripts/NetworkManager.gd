extends Node

const DEFAULT_PORT = 8910
const MAX_CLIENTS = 4 # Host + 4 clients = 5 players max

var peer: ENetMultiplayerPeer
var room_code: String = ""
var is_host: bool = false
var players: Dictionary = {} # peer_id (int) -> {"username": String, "uid": String}

signal player_list_changed
signal room_created(code)
signal join_failed(reason)
signal game_started

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_room() -> void:
	leave_room()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		join_failed.emit("Failed to host on port " + str(DEFAULT_PORT))
		return
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	# Generate room code from local IP for the prototype
	var ip = _get_local_ip()
	room_code = Marshalls.utf8_to_base64(ip).replace("=", "")
	
	# Add self to players
	players[1] = {"username": SessionManager.get_current_user(), "uid": SessionManager.get_uid()}
	
	room_created.emit(room_code)
	player_list_changed.emit()

func join_room(code: String) -> void:
	leave_room()
	
	var padded_code = code
	while padded_code.length() % 4 != 0:
		padded_code += "="
		
	var ip = Marshalls.base64_to_utf8(padded_code)
	if ip.is_empty():
		join_failed.emit("Invalid Room Code format")
		return
		
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		join_failed.emit("Failed to connect to room")
		return
		
	multiplayer.multiplayer_peer = peer
	is_host = false
	room_code = code

func leave_room() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	room_code = ""

func start_match() -> void:
	if is_host:
		rpc("start_match_rpc")

func _get_local_ip() -> String:
	var ips = IP.get_local_addresses()
	for ip in ips:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

# --- Callbacks ---
func _on_peer_connected(id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_changed.emit()

func _on_connected_to_server() -> void:
	# Send our info to the server
	var username = SessionManager.get_current_user()
	var uid = SessionManager.get_uid()
	rpc_id(1, "register_player", username, uid)

func _on_connection_failed() -> void:
	join_failed.emit("Connection timed out.")
	leave_room()

func _on_server_disconnected() -> void:
	leave_room()
	get_tree().change_scene_to_file("res://Dashboard.tscn")

@rpc("any_peer", "call_local", "reliable")
func register_player(username: String, uid: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	players[id] = {"username": username, "uid": uid}
	player_list_changed.emit()
	
	# If we are host, broadcast the full player list to everyone
	if is_host:
		rpc("sync_players", players)

@rpc("authority", "call_remote", "reliable")
func sync_players(host_players: Dictionary) -> void:
	players = host_players
	player_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func start_match_rpc() -> void:
	game_started.emit()
