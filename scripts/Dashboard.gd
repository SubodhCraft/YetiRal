extends Control

## Dashboard v2 — Full game hub with Lobby, Profile, Store, Settings
## Uses Scene Unique Nodes (%Name) for easy referencing.

# ─────────────────────────────────────────────────────────────────────────────
# NODE REFERENCES
# ─────────────────────────────────────────────────────────────────────────────
@onready var btn_lobby    = %NavBtnLobby
@onready var btn_profile  = %NavBtnProfile
@onready var btn_store    = %NavBtnStore
@onready var btn_settings = %NavBtnSettings
@onready var btn_social   = %NavBtnSocial
@onready var btn_logout   = %NavBtnLogout

@onready var view_lobby    = %LobbyView
@onready var view_profile  = %ProfileView
@onready var view_store    = %StoreView
@onready var view_settings = %SettingsView
@onready var view_social   = %SocialView

@onready var game_mode_modal   = %GameModeModal
@onready var btn_quick_play    = %QuickPlayBtn
@onready var btn_single_player = %SinglePlayerBtn
@onready var btn_multiplayer   = %MultiplayerBtn
@onready var btn_close_modal   = %CloseModalBtn

# Social Elements
@onready var label_my_uid = %MyUIDLabel
@onready var input_friend_uid = %FriendUIDInput
@onready var btn_add_friend = %AddFriendBtn
@onready var label_social_msg = %SocialMsg
@onready var vbox_friends = %FriendsVBox
@onready var vbox_requests = %RequestsVBox

# Multiplayer Modal Elements
@onready var box_mode_select = %ModeSelectBox
@onready var box_multiplayer = %MultiplayerBox
@onready var box_waiting_lobby = %WaitingLobbyBox

@onready var btn_create_room = %CreateRoomBtn
@onready var input_join_code = %JoinCodeInput
@onready var btn_join_room = %JoinRoomBtn
@onready var label_multiplayer_msg = %MultiplayerMsg

@onready var label_room_code = %RoomCodeDisplay
@onready var label_player_count = %PlayerCountLabel
@onready var list_lobby_players = %LobbyPlayersList
@onready var btn_start_match = %StartMatchBtn

@onready var label_top_profile       = %TopProfileName
@onready var label_side_profile      = %SideProfileName
@onready var label_profile_view_name = %ProfileViewName
@onready var label_stats             = %StatsLabel

const AUTH_SCENE: String = "res://AuthScreen.tscn"

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if not SessionManager.is_logged_in():
		get_tree().change_scene_to_file(AUTH_SCENE)
		return

	var username: String = SessionManager.get_current_user()
	
	# Populate dynamic username labels
	label_top_profile.text       = username
	label_side_profile.text      = username
	label_profile_view_name.text = username

	# Wire up Sidebar Navigation
	btn_lobby.pressed.connect(_show_view.bind(view_lobby))
	btn_profile.pressed.connect(_show_view.bind(view_profile))
	btn_store.pressed.connect(_show_view.bind(view_store))
	btn_settings.pressed.connect(_show_view.bind(view_settings))
	btn_social.pressed.connect(_show_view.bind(view_social))
	btn_logout.pressed.connect(_on_logout_pressed)

	# Wire up Game Mode Modal
	btn_quick_play.pressed.connect(_open_game_mode_modal)
	btn_close_modal.pressed.connect(_close_game_mode_modal)
	btn_single_player.pressed.connect(_on_single_player)
	btn_multiplayer.pressed.connect(_on_multiplayer)
	
	btn_add_friend.pressed.connect(_on_add_friend_pressed)
	btn_create_room.pressed.connect(_on_create_room_pressed)
	btn_join_room.pressed.connect(_on_join_room_pressed)
	btn_start_match.pressed.connect(_on_start_match_pressed)
	
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.player_list_changed.connect(_update_lobby_ui)
	NetworkManager.game_started.connect(_on_multiplayer_game_started)

	# Set initial view
	_show_view(view_lobby)
	game_mode_modal.hide()

# ─────────────────────────────────────────────────────────────────────────────
# NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────
func _show_view(view_to_show: Control) -> void:
	view_lobby.hide()
	view_profile.hide()
	view_store.hide()
	view_settings.hide()
	view_social.hide()
	
	view_to_show.show()
	
	if view_to_show == view_profile:
		_update_profile_stats()
	elif view_to_show == view_social:
		_update_social_view()

func _update_social_view() -> void:
	label_my_uid.text = "Your UID: " + SessionManager.get_uid()
	label_social_msg.text = ""
	
	for child in vbox_friends.get_children(): child.queue_free()
	for child in vbox_requests.get_children(): child.queue_free()
		
	var friends = SessionManager.get_friends()
	for f_uid in friends:
		var lbl = Label.new()
		lbl.text = "Friend: " + SessionManager.get_username_by_uid(f_uid) + " (" + f_uid + ")"
		vbox_friends.add_child(lbl)
		
	var requests = SessionManager.get_friend_requests()
	for r_uid in requests:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "Request from: " + SessionManager.get_username_by_uid(r_uid) + " (" + r_uid + ")"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn = Button.new()
		btn.text = "Accept"
		btn.pressed.connect(func():
			SessionManager.accept_friend_request(r_uid)
			_update_social_view()
		)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		vbox_requests.add_child(hbox)

func _on_add_friend_pressed() -> void:
	var target = input_friend_uid.text.strip_edges()
	if target.is_empty(): return
	var res = SessionManager.send_friend_request(target)
	label_social_msg.text = res["message"]
	input_friend_uid.text = ""
	_update_social_view()

func _update_profile_stats() -> void:
	if not SessionManager.is_logged_in():
		return
	var username = SessionManager.get_current_user()
	var stats = SessionManager.get_user_stats(username)
	var mp = stats.get("matches_played", 0)
	var wins = stats.get("wins", 0)
	var momos = stats.get("momos", 0)
	var win_rate = 0.0
	if mp > 0:
		win_rate = (float(wins) / float(mp)) * 100.0
		
	var xp = stats.get("xp", 0)
	var level = stats.get("level", 1)
	var xp_needed = level * 100
	var streak = stats.get("active_days_streak", 0)
	var badges: Array = stats.get("badges", [])
	
	var badges_str = ", ".join(badges) if badges.size() > 0 else "None"
	
	var text_str = "Level: %d\n" % level
	text_str += "XP: %d / %d\n" % [xp, xp_needed]
	text_str += "Login Streak: %d days\n" % streak
	text_str += "Badges: %s\n\n" % badges_str
	text_str += "Matches Played: %d\nWin Rate: %.1f%%\nMomos Collected: %d\nJoin Date: June 2026" % [mp, win_rate, momos]
	
	label_stats.text = text_str

func _on_logout_pressed() -> void:
	SessionManager.logout()
	get_tree().change_scene_to_file(AUTH_SCENE)

# ─────────────────────────────────────────────────────────────────────────────
# GAME MODES
# ─────────────────────────────────────────────────────────────────────────────
func _open_game_mode_modal() -> void:
	box_mode_select.show()
	box_multiplayer.hide()
	box_waiting_lobby.hide()
	label_multiplayer_msg.text = ""
	
	# Small animation for the modal
	game_mode_modal.modulate.a = 0.0
	game_mode_modal.show()
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(game_mode_modal, "modulate:a", 1.0, 0.2)

func _close_game_mode_modal() -> void:
	NetworkManager.leave_room()
	var tw = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(game_mode_modal, "modulate:a", 0.0, 0.15)
	tw.tween_callback(game_mode_modal.hide)

func _on_single_player() -> void:
	print("Starting Single Player Expedition...")
	_close_game_mode_modal()
	if GameManager:
		GameManager.start_game()

func _on_multiplayer() -> void:
	box_mode_select.hide()
	box_multiplayer.show()

func _on_create_room_pressed() -> void:
	NetworkManager.create_room()

func _on_join_room_pressed() -> void:
	var code = input_join_code.text.strip_edges()
	if code.is_empty(): return
	NetworkManager.join_room(code)

func _on_room_created(code: String) -> void:
	box_multiplayer.hide()
	box_waiting_lobby.show()
	label_room_code.text = "Code: " + code
	_update_lobby_ui()

func _on_join_failed(reason: String) -> void:
	label_multiplayer_msg.text = reason

func _update_lobby_ui() -> void:
	if not box_waiting_lobby.visible:
		if not NetworkManager.is_host and NetworkManager.peer != null:
			box_multiplayer.hide()
			box_mode_select.hide()
			box_waiting_lobby.show()
			label_room_code.text = "Code: " + NetworkManager.room_code
			
	var p_count = NetworkManager.players.size()
	label_player_count.text = "Players: %d / 5" % p_count
	
	for child in list_lobby_players.get_children():
		child.queue_free()
		
	for pid in NetworkManager.players:
		var pdata = NetworkManager.players[pid]
		var lbl = Label.new()
		lbl.text = pdata.get("username", "Unknown")
		if pid == 1:
			lbl.text += " (Host)"
		list_lobby_players.add_child(lbl)
		
	if NetworkManager.is_host:
		btn_start_match.disabled = p_count < 3
		btn_start_match.show()
	else:
		btn_start_match.hide()

func _on_start_match_pressed() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_match()

func _on_multiplayer_game_started() -> void:
	_close_game_mode_modal()
	if GameManager.has_method("start_multiplayer_game"):
		GameManager.start_multiplayer_game()
