extends Node

const DEFAULT_PORT: int = 8910
const MAX_CLIENTS: int = 4 # Host + 4 clients = 5 players max
const UDP_BROADCAST_PORT: int = 8911

@export var heartbeat_interval: float = 5.0
@export var heartbeat_timeout: float = 10.0
@export var search_timeout: float = 10.0
@export var udp_broadcast_interval: float = 2.0

var peer: ENetMultiplayerPeer
var room_code: String = ""
var is_host: bool = false
var players: Dictionary = {} # peer_id (int) -> {"username": String, "uid": String}
var last_pong: Dictionary = {} # peer_id (int) -> float (unix time)
var player_ready: Dictionary = {} # peer_id (int) -> bool

var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var udp_broadcast_timer: Timer
var join_target_code: String = ""
var is_searching: bool = false
var search_timeout_timer: Timer
var heartbeat_timer: Timer

signal player_list_changed
signal room_created(code: String)
signal join_failed(reason: String)
signal game_started
signal all_players_ready

func _ready() -> void:
	randomize()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	if is_searching and udp_listener:
		while udp_listener.get_available_packet_count() > 0:
			var packet = udp_listener.get_packet()
			var packet_str = packet.get_string_from_utf8()
			
			var json = JSON.new()
			var err = json.parse(packet_str)
			if err == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					var code = data.get("code", "")
					var ip = data.get("ip", "")
					var port = data.get("port", DEFAULT_PORT)
					
					if code.to_upper() == join_target_code:
						_stop_udp_listener()
						_connect_to_host(ip, port)
						return

func _generate_room_code() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

func create_room() -> void:
	leave_room()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		join_failed.emit("Failed to host on port " + str(DEFAULT_PORT))
		return
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	room_code = _generate_room_code()
	
	# Add self to players
	players[1] = {"username": SessionManager.get_current_user(), "uid": SessionManager.get_uid()}
	player_ready[1] = false
	
	room_created.emit(room_code)
	player_list_changed.emit()
	
	_start_udp_broadcast()
	_start_heartbeat()

func join_via_code(code: String) -> void:
	leave_room()
	join_target_code = code.strip_edges().to_upper()
	
	udp_listener = PacketPeerUDP.new()
	var err = udp_listener.bind(UDP_BROADCAST_PORT)
	if err != OK:
		join_failed.emit("Failed to bind UDP listener port " + str(UDP_BROADCAST_PORT))
		return
	
	is_searching = true
	
	search_timeout_timer = Timer.new()
	search_timeout_timer.wait_time = search_timeout
	search_timeout_timer.one_shot = true
	search_timeout_timer.timeout.connect(_on_search_timeout)
	add_child(search_timeout_timer)
	search_timeout_timer.start()

func join_room(code: String) -> void:
	join_via_code(code)

func _connect_to_host(ip: String, port: int) -> void:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		join_failed.emit("Failed to connect to room")
		return
		
	multiplayer.multiplayer_peer = peer
	is_host = false
	room_code = join_target_code

func leave_room() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	player_ready.clear()
	is_host = false
	room_code = ""
	_stop_udp_broadcast()
	_stop_udp_listener()
	_stop_heartbeat()

func start_match() -> void:
	if is_host:
		if players.size() < 2:
			join_failed.emit("Need at least 2 players to start")
			return
			
		var all_ready = true
		for p_id in players:
			if not player_ready.get(p_id, false):
				all_ready = false
				break
		if not all_ready:
			return
			
		rpc("start_match_rpc")

func _get_local_ip() -> String:
	var ips = IP.get_local_addresses()
	for ip in ips:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

# --- UDP Discovery Helper Methods ---
func _start_udp_broadcast() -> void:
	_stop_udp_broadcast()
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	var err = udp_broadcaster.bind(0)
	if err != OK:
		push_error("Failed to bind UDP broadcaster")
		return
	udp_broadcaster.set_dest_address("255.255.255.255", UDP_BROADCAST_PORT)
	
	udp_broadcast_timer = Timer.new()
	udp_broadcast_timer.wait_time = udp_broadcast_interval
	udp_broadcast_timer.one_shot = false
	udp_broadcast_timer.timeout.connect(_on_udp_broadcast_timeout)
	add_child(udp_broadcast_timer)
	udp_broadcast_timer.start()
	_on_udp_broadcast_timeout()

func _on_udp_broadcast_timeout() -> void:
	if not udp_broadcaster:
		return
	var ip = _get_local_ip()
	var packet_data = {
		"code": room_code,
		"ip": ip,
		"port": DEFAULT_PORT
	}
	var json_str = JSON.stringify(packet_data)
	var _err = udp_broadcaster.put_packet(json_str.to_utf8_buffer())

func _stop_udp_broadcast() -> void:
	if is_instance_valid(udp_broadcast_timer):
		udp_broadcast_timer.stop()
		udp_broadcast_timer.queue_free()
	udp_broadcast_timer = null
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null

func _on_search_timeout() -> void:
	if is_searching:
		_stop_udp_listener()
		join_failed.emit("Room not found or timed out")

func _stop_udp_listener() -> void:
	is_searching = false
	if is_instance_valid(search_timeout_timer):
		search_timeout_timer.stop()
		search_timeout_timer.queue_free()
	search_timeout_timer = null
	if udp_listener:
		udp_listener.close()
		udp_listener = null

# --- Heartbeat Mechanism ---
func _start_heartbeat() -> void:
	_stop_heartbeat()
	var current_time = Time.get_unix_time_from_system()
	for p_id in players:
		last_pong[p_id] = current_time
		
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = heartbeat_interval
	heartbeat_timer.one_shot = false
	heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(heartbeat_timer)
	heartbeat_timer.start()

func _send_heartbeat() -> void:
	if not is_host:
		return
		
	var current_time = Time.get_unix_time_from_system()
	var peers_to_kick = []
	for p_id in players:
		if p_id == 1:
			continue
		var last_active = last_pong.get(p_id, 0.0)
		if current_time - last_active > heartbeat_timeout:
			peers_to_kick.append(p_id)
			
	for p_id in peers_to_kick:
		_kick_inactive_peer(p_id)
		
	rpc("ping")

func _stop_heartbeat() -> void:
	if is_instance_valid(heartbeat_timer):
		heartbeat_timer.stop()
		heartbeat_timer.queue_free()
	heartbeat_timer = null
	last_pong.clear()

func _kick_inactive_peer(id: int) -> void:
	if is_host:
		rpc_id(id, "force_kick")
		if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			peer.disconnect_peer(id)
		players.erase(id)
		player_ready.erase(id)
		last_pong.erase(id)
		player_list_changed.emit()
		rpc("sync_players", players)
		rpc("sync_ready_states", player_ready)

# --- Ready-check & Kick API ---
func kick_player(peer_id: int) -> void:
	if is_host:
		rpc_id(peer_id, "on_kicked")
		if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			peer.disconnect_peer(peer_id)
		players.erase(peer_id)
		player_ready.erase(peer_id)
		last_pong.erase(peer_id)
		player_list_changed.emit()
		rpc("sync_players", players)
		rpc("sync_ready_states", player_ready)

# --- Callbacks ---
func _on_peer_connected(id: int) -> void:
	if is_host:
		last_pong[id] = Time.get_unix_time_from_system()
		player_ready[id] = false
		rpc_id(id, "sync_players", players)
		rpc_id(id, "sync_ready_states", player_ready)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_ready.erase(id)
	last_pong.erase(id)
	player_list_changed.emit()
	if is_host:
		rpc("sync_players", players)
		rpc("sync_ready_states", player_ready)

func _on_connected_to_server() -> void:
	var username = SessionManager.get_current_user()
	var uid = SessionManager.get_uid()
	rpc_id(1, "register_player", username, uid)

func _on_connection_failed() -> void:
	join_failed.emit("Connection timed out.")
	leave_room()

func _on_server_disconnected() -> void:
	leave_room()
	get_tree().change_scene_to_file("res://Dashboard.tscn")

# --- RPCs ---
@rpc("any_peer", "call_local", "reliable")
func register_player(username: String, uid: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	players[id] = {"username": username, "uid": uid}
	if is_host:
		player_ready[id] = false
	player_list_changed.emit()
	
	if is_host:
		rpc("sync_players", players)
		rpc("sync_ready_states", player_ready)

@rpc("authority", "call_remote", "reliable")
func sync_players(host_players: Dictionary) -> void:
	players = host_players
	player_list_changed.emit()

@rpc("authority", "call_remote", "reliable")
func sync_ready_states(host_ready_states: Dictionary) -> void:
	player_ready = host_ready_states
	player_list_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func set_ready(peer_id: int) -> void:
	player_ready[peer_id] = true
	player_list_changed.emit()
	
	var all_ready = true
	for p_id in players:
		if not player_ready.get(p_id, false):
			all_ready = false
			break
	if all_ready:
		all_players_ready.emit()

@rpc("authority", "call_remote", "unreliable")
func ping() -> void:
	rpc_id(1, "_on_heartbeat_received")

@rpc("any_peer", "call_remote", "unreliable")
func _on_heartbeat_received() -> void:
	if is_host:
		var sender_id = multiplayer.get_remote_sender_id()
		last_pong[sender_id] = Time.get_unix_time_from_system()

@rpc("authority", "call_remote", "reliable")
func force_kick() -> void:
	leave_room()
	get_tree().change_scene_to_file("res://Dashboard.tscn")

@rpc("authority", "call_remote", "reliable")
func on_kicked() -> void:
	leave_room()
	get_tree().change_scene_to_file("res://Dashboard.tscn")

@rpc("authority", "call_local", "reliable")
func start_match_rpc() -> void:
	game_started.emit()
