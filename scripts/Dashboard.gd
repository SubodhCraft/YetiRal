extends Control

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const AUTH_SCENE: String = "res://AuthScreen.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/SettingsScreen.tscn"

# ─────────────────────────────────────────────────────────────────────────────
# TOP BAR
# ─────────────────────────────────────────────────────────────────────────────
const STORE_ITEMS_DB = [
	{"id": "dhaka_topi", "name": "Dhaka Topi", "cost": 100, "image": "res://assets/store_items/DhakaTopi.png"},
	{"id": "everest_crown", "name": "Everest Crown", "cost": 250, "image": "res://assets/store_items/EverestCrown.png"},
	{"id": "sherpa_cap", "name": "Sherpa Cap", "cost": 150, "image": "res://assets/store_items/SherpaCap.png"},
	{"id": "yak_horns", "name": "Yak Horns", "cost": 300, "image": "res://assets/store_items/YakHorns.png"},
	{"id": "kukri_band", "name": "Kukri Band", "cost": 200, "image": "res://assets/store_items/Kukuri.png"},
	{"id": "mountain_glasses", "name": "Mountain Glasses", "cost": 150, "image": "res://assets/store_items/MountainGlasses.png"},
	{"id": "apple", "name": "Apple", "cost": 20, "image": "res://assets/fruits/apple.svg"},
	{"id": "banana", "name": "Banana", "cost": 20, "image": "res://assets/fruits/banana.svg"},
	{"id": "cherry", "name": "Cherry", "cost": 25, "image": "res://assets/fruits/cherry.svg"},
	{"id": "grape", "name": "Grape", "cost": 30, "image": "res://assets/fruits/grape.svg"},
	{"id": "kiwi", "name": "Kiwi", "cost": 25, "image": "res://assets/fruits/kiwi.svg"}
]

@onready var top_profile_name: Label = %TopProfileName

# --- NEW UI REFS ---
@onready var money_label: Label = $MainVBox/TopBar/Margin/HBox/RightSide/Money
var file_dialog: FileDialog
var level_up_modal: ColorRect
var level_up_msg: Label
var xp_progress: ProgressBar
var xp_text_label: Label
var profile_avatar: TextureRect
var username_edit: LineEdit

var top_avatar: TextureRect
var side_avatar: TextureRect
var daily_reward_modal: ColorRect
var store_success_modal: ColorRect
var store_success_msg: Label

# ─────────────────────────────────────────────────────────────────────────────
# SIDEBAR NODES
# ─────────────────────────────────────────────────────────────────────────────
@onready var side_profile_name: Label = %SideProfileName
@onready var nav_btn_lobby: Button = %NavBtnLobby
@onready var nav_btn_profile: Button = %NavBtnProfile
@onready var nav_btn_store: Button = %NavBtnStore
@onready var nav_btn_social: Button = %NavBtnSocial
@onready var nav_btn_settings: Button = %NavBtnSettings
@onready var nav_btn_logout: Button = %NavBtnLogout

# ─────────────────────────────────────────────────────────────────────────────
# CONTENT VIEWS
# ─────────────────────────────────────────────────────────────────────────────
@onready var lobby_view: HBoxContainer = %LobbyView
@onready var profile_view: VBoxContainer = %ProfileView
@onready var store_view: VBoxContainer = %StoreView
@onready var settings_view: VBoxContainer = %SettingsView
@onready var social_view: VBoxContainer = %SocialView

var vault_view: VBoxContainer
var nav_btn_vault: Button

# Profile view
@onready var profile_view_name: Label = %ProfileViewName
@onready var stats_label: Label = %StatsLabel

# Social view
@onready var my_uid_label: Label = %MyUIDLabel
@onready var friend_uid_input: LineEdit = %FriendUIDInput
@onready var add_friend_btn: Button = %AddFriendBtn
@onready var social_msg: Label = %SocialMsg
@onready var requests_v_box: VBoxContainer = %RequestsVBox
@onready var friends_v_box: VBoxContainer = %FriendsVBox
@onready var refresh_social_btn: Button = %RefreshSocialBtn

# ─────────────────────────────────────────────────────────────────────────────
# GAME MODE MODAL
# ─────────────────────────────────────────────────────────────────────────────
@onready var game_mode_modal: ColorRect = %GameModeModal
@onready var mode_select_box: VBoxContainer = %ModeSelectBox
@onready var single_player_btn: Button = %SinglePlayerBtn
@onready var multiplayer_btn: Button = %MultiplayerBtn
@onready var multiplayer_box: VBoxContainer = %MultiplayerBox
@onready var create_room_btn: Button = %CreateRoomBtn
@onready var join_code_input: LineEdit = %JoinCodeInput
@onready var join_room_btn: Button = %JoinRoomBtn
@onready var multiplayer_msg: Label = %MultiplayerMsg
@onready var waiting_lobby_box: VBoxContainer = %WaitingLobbyBox
@onready var room_code_display: Label = %RoomCodeDisplay
@onready var player_count_label: Label = %PlayerCountLabel
@onready var lobby_players_list: VBoxContainer = %LobbyPlayersList
@onready var start_match_btn: Button = %StartMatchBtn
@onready var close_modal_btn: Button = %CloseModalBtn

# Lobby QuickPlay
@onready var quick_play_btn: Button = %QuickPlayBtn

# ─────────────────────────────────────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_connect_nav_buttons()
	_connect_modal_buttons()
	_connect_social_buttons()
	
	_setup_profile_extras()
	_setup_store_ui()
	_setup_level_up_modal()
	_setup_avatars()
	_setup_daily_reward_modal()
	_setup_store_success_modal()
	_setup_vault_ui()
	_setup_daily_challenges()
	_setup_streak_rewards()
	_setup_settings_ui()
	_setup_level_up_banner()
	
	_populate_user_data()
	_show_view(lobby_view)
	
	# Load friends list into the lobby social card on startup
	_refresh_friends_lists()
	
	# Auto-poll for new friend requests every 10 seconds
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 10.0
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_refresh_friends_lists)
	add_child(_poll_timer)

	if NetworkManager:
		NetworkManager.room_created.connect(_on_room_created)
		NetworkManager.join_failed.connect(_on_join_failed)
		NetworkManager.player_list_changed.connect(_refresh_lobby_player_list)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		
	if SessionManager:
		if not SessionManager.leveled_up.is_connected(_on_leveled_up):
			SessionManager.leveled_up.connect(_on_leveled_up)
		
		# Consume any level ups that happened while dashboard wasn't active
		if SessionManager.has_method("consume_pending_level_ups"):
			var pending = SessionManager.consume_pending_level_ups()
			for p in pending:
				_on_leveled_up(p["level"], p["gift"])

# ─────────────────────────────────────────────────────────────────────────────
# NAV
# ─────────────────────────────────────────────────────────────────────────────
func _connect_nav_buttons() -> void:
	if nav_btn_lobby:    nav_btn_lobby.pressed.connect(func(): _show_view(lobby_view))
	if nav_btn_profile:  nav_btn_profile.pressed.connect(func(): _show_view(profile_view); _populate_profile_view())
	if nav_btn_store:    nav_btn_store.pressed.connect(func(): _show_view(store_view))
	if nav_btn_settings: nav_btn_settings.pressed.connect(func(): _show_view(settings_view))
	if nav_btn_social:
		nav_btn_social.text = "Vault"
		nav_btn_social.pressed.connect(func(): _show_view(vault_view); _populate_vault_view())
	if nav_btn_logout:   nav_btn_logout.pressed.connect(_on_logout_pressed)

func _show_view(target: Control) -> void:
	var views: Array[Control] = [lobby_view, profile_view, store_view, settings_view, social_view, vault_view]
	for v in views:
		if is_instance_valid(v):
			v.visible = (v == target)
			if v == target:
				v.modulate.a = 0.0
				var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(v, "modulate:a", 1.0, 0.25)

# ─────────────────────────────────────────────────────────────────────────────
# MODAL — GAME MODE SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _connect_modal_buttons() -> void:
	if quick_play_btn:    quick_play_btn.pressed.connect(_open_modal)
	if close_modal_btn:   close_modal_btn.pressed.connect(_close_modal)
	if single_player_btn: single_player_btn.pressed.connect(_on_single_player)
	if multiplayer_btn:   multiplayer_btn.pressed.connect(_on_multiplayer_tab)
	if create_room_btn:   create_room_btn.pressed.connect(_on_create_room)
	if join_room_btn:     join_room_btn.pressed.connect(_on_join_room)
	if start_match_btn:   start_match_btn.pressed.connect(_on_start_match)

func _open_modal() -> void:
	if game_mode_modal:
		game_mode_modal.visible = true
		_set_modal_state("mode_select")

func _close_modal() -> void:
	if game_mode_modal:
		game_mode_modal.visible = false
	NetworkManager.leave_room()

func _set_modal_state(state: String) -> void:
	if mode_select_box:   mode_select_box.visible = (state == "mode_select")
	if multiplayer_box:   multiplayer_box.visible = (state == "multiplayer")
	if waiting_lobby_box: waiting_lobby_box.visible = (state == "waiting")

func _on_single_player() -> void:
	_close_modal()
	if GameManager:
		GameManager.start_game()

func _on_multiplayer_tab() -> void:
	_set_modal_state("multiplayer")
	if multiplayer_msg: multiplayer_msg.text = ""

func _on_create_room() -> void:
	if NetworkManager:
		NetworkManager.create_room()

func _on_join_room() -> void:
	if not join_code_input: return
	var code = join_code_input.text.strip_edges().to_upper()
	if code.is_empty():
		if multiplayer_msg: multiplayer_msg.text = "Please enter a room code."
		return
	if multiplayer_msg: multiplayer_msg.text = "Searching…"
	if NetworkManager:
		NetworkManager.join_via_code(code)

func _on_start_match() -> void:
	if NetworkManager:
		NetworkManager.start_match()

func _on_room_created(code: String) -> void:
	_set_modal_state("waiting")
	if room_code_display: room_code_display.text = "Code: %s" % code
	_refresh_lobby_player_list()

func _on_connected_to_server() -> void:
	_set_modal_state("waiting")
	if room_code_display: room_code_display.text = "Code: %s" % NetworkManager.room_code
	_refresh_lobby_player_list()

func _on_join_failed(reason: String) -> void:
	if multiplayer_msg: multiplayer_msg.text = "Failed: %s" % reason

func _refresh_lobby_player_list() -> void:
	if not is_instance_valid(lobby_players_list): return
	for c in lobby_players_list.get_children():
		c.queue_free()
	if not NetworkManager: return
	var count = NetworkManager.players.size()
	if player_count_label:
		player_count_label.text = "Players: %d / 5" % count
	for pid in NetworkManager.players:
		var pdata = NetworkManager.players[pid]
		var lbl = Label.new()
		var ready_icon = "✅" if NetworkManager.player_ready.get(pid, false) else "⏳"
		lbl.text = "%s %s" % [ready_icon, pdata.get("username", "Player")]
		lbl.theme_override_font_sizes["font_size"] = 16
		lobby_players_list.add_child(lbl)
	if start_match_btn:
		start_match_btn.disabled = (count < 2) or not NetworkManager.is_host

# ─────────────────────────────────────────────────────────────────────────────
# USER DATA
# ─────────────────────────────────────────────────────────────────────────────
func _populate_user_data() -> void:
	if not SessionManager or not SessionManager.is_logged_in():
		if top_profile_name: top_profile_name.text = "Guest"
		if side_profile_name: side_profile_name.text = "Guest"
		return

	var username = SessionManager.get_current_user()
	var stats = SessionManager.get_user_stats(username)
	var level = stats.get("level", 1)
	var title = SessionManager.get_player_title(username)

	if top_profile_name:  top_profile_name.text = username
	if side_profile_name: side_profile_name.text = "%s\nLv.%d — %s" % [username, level, title]
	if my_uid_label:      my_uid_label.text = "Your UID: %s" % SessionManager.get_uid(username)
	if money_label:       money_label.text = "%d Momos 🥟" % stats.get("momos", 0)
	
	_update_avatars(username)

func _populate_profile_view() -> void:
	if not SessionManager or not SessionManager.is_logged_in(): return
	var username = SessionManager.get_current_user()
	var stats = SessionManager.get_user_stats(username)

	if profile_view_name:
		profile_view_name.text = username

	if stats_label:
		var played = stats.get("matches_played", 0)
		var wins   = stats.get("wins", 0)
		var rate   = (float(wins) / float(played) * 100.0) if played > 0 else 0.0
		stats_label.text = "Matches Played: %d\nWin Rate: %.0f%%\nMomos: %d 🥟\nLevel: %d" % [
			played, rate, stats.get("momos", 0), stats.get("level", 1)
		]

	if xp_progress:
		var lvl = stats.get("level", 1)
		var xp = stats.get("xp", 0)
		var needed = lvl * 100
		xp_progress.max_value = needed
		xp_progress.value = xp
		if xp_text_label:
			xp_text_label.text = "%d out of %d XP" % [xp, needed]
		
	var pic_path = SessionManager.get_profile_pic_path(username)
	if pic_path != "" and profile_avatar:
		var img = Image.load_from_file(pic_path)
		if img:
			profile_avatar.texture = ImageTexture.create_from_image(img)
			
	# Update vault
	if %ProfileView:
		var margin = %ProfileView.get_node_or_null("ProfileCard/Margin")
		if margin:
			var vault_vbox = margin.get_node_or_null("VBox/VaultVBox")
			if vault_vbox:
				for c in vault_vbox.get_children():
					c.queue_free()
				var owned = stats.get("owned_hats", [])
				if owned.is_empty():
					var l = Label.new()
					l.text = "No items in vault yet."
					vault_vbox.add_child(l)
				else:
					for hat_id in owned:
						var row = HBoxContainer.new()
						var ln = Label.new()
						var eq_status = " (Equipped)" if stats.get("equipped_hat", "none") == hat_id else ""
						ln.text = "Hat: " + hat_id + eq_status
						ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						var eq = Button.new()
						eq.text = "Equip"
						eq.pressed.connect(func(): SessionManager.equip_hat(hat_id); _populate_profile_view())
						row.add_child(ln)
						row.add_child(eq)
						vault_vbox.add_child(row)


var _poll_timer: Timer = null

func _refresh_friends_lists() -> void:
	if not SessionManager or not SessionManager.is_logged_in(): return
	
	# Always update the UID label
	if my_uid_label:
		my_uid_label.text = "Your UID: %s" % SessionManager.get_uid()
	
	# Show loading indicator in the requests box
	if requests_v_box:
		for c in requests_v_box.get_children(): c.queue_free()
		var loading_lbl = Label.new()
		loading_lbl.text = "Loading..."
		requests_v_box.add_child(loading_lbl)
	
	# Fetch fresh data from server
	await SessionManager.fetch_friends_async()
	
	# Clear and repopulate
	if requests_v_box:
		for c in requests_v_box.get_children(): c.queue_free()
	if friends_v_box:
		for c in friends_v_box.get_children(): c.queue_free()

	var requests: Array = SessionManager.get_friend_requests()
	if requests.is_empty():
		var lbl = Label.new()
		lbl.text = "No pending requests."
		lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if requests_v_box: requests_v_box.add_child(lbl)
	else:
		for req_dict in requests:
			var uid = req_dict.get("uid", "")
			var uname = req_dict.get("username", "Unknown")
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "👤 %s (%s)" % [uname, uid]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var accept_btn = Button.new()
			accept_btn.text = "✅ Accept"
			accept_btn.pressed.connect(func(): _accept_request(uid))
			var reject_btn = Button.new()
			reject_btn.text = "❌ Decline"
			reject_btn.pressed.connect(func(): _reject_request(uid))
			row.add_child(lbl)
			row.add_child(accept_btn)
			row.add_child(reject_btn)
			if requests_v_box: requests_v_box.add_child(row)

	var friends: Array = SessionManager.get_friends()
	if friends.is_empty():
		var lbl = Label.new()
		lbl.text = "No friends yet. Add one above!"
		lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if friends_v_box: friends_v_box.add_child(lbl)
	else:
		for f_dict in friends:
			var uname = f_dict.get("username", "Unknown")
			var lbl = Label.new()
			lbl.text = "🏔 %s" % uname
			if friends_v_box: friends_v_box.add_child(lbl)

# ─────────────────────────────────────────────────────────────────────────────
# SOCIAL BUTTON HANDLERS
# ─────────────────────────────────────────────────────────────────────────────
func _connect_social_buttons() -> void:
	if add_friend_btn:
		add_friend_btn.pressed.connect(_on_add_friend)
	if refresh_social_btn:
		refresh_social_btn.pressed.connect(_refresh_friends_lists)

func _on_add_friend() -> void:
	if not friend_uid_input or not SessionManager: return
	var uid = friend_uid_input.text.strip_edges().to_upper()
	if uid.is_empty():
		if social_msg: social_msg.text = "Enter a UID first."
		return
	var result = await SessionManager.send_friend_request(uid)
	if social_msg:
		social_msg.text = result.get("message", "")
	if result.get("success", false):
		friend_uid_input.text = ""
		_refresh_friends_lists()

func _accept_request(uid: String) -> void:
	await SessionManager.accept_friend_request(uid)
	_refresh_friends_lists()

func _reject_request(uid: String) -> void:
	await SessionManager.reject_friend_request(uid)
	_refresh_friends_lists()

# ─────────────────────────────────────────────────────────────────────────────
# LOGOUT
# ─────────────────────────────────────────────────────────────────────────────
func _on_logout_pressed() -> void:
	var confirm_modal = ColorRect.new()
	confirm_modal.color = Color(0, 0, 0, 0.85)
	confirm_modal.set_anchors_preset(PRESET_FULL_RECT)
	add_child(confirm_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	confirm_modal.add_child(center)
	
	var p = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	p.add_theme_stylebox_override("panel", style)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	
	var title = Label.new()
	title.text = "LOGOUT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	
	var msg = Label.new()
	msg.text = "Are you sure you want to log out?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var yes_btn = Button.new()
	yes_btn.text = "Yes, Logout"
	yes_btn.custom_minimum_size = Vector2(120, 40)
	yes_btn.pressed.connect(func():
		if NetworkManager: NetworkManager.leave_room()
		if SessionManager: SessionManager.logout()
		get_tree().change_scene_to_file(AUTH_SCENE)
	)
	
	var no_btn = Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(120, 40)
	no_btn.pressed.connect(func(): confirm_modal.queue_free())
	
	hbox.add_child(no_btn)
	hbox.add_child(yes_btn)
	v.add_child(hbox)
	
	p.add_child(v)
	center.add_child(p)

# ─────────────────────────────────────────────────────────────────────────────
# NEW UI (PROFILE, STORE, VAULT, LEVEL UP)
# ─────────────────────────────────────────────────────────────────────────────
func _setup_profile_extras() -> void:
	if not %ProfileView: return
	var margin = %ProfileView.get_node_or_null("ProfileCard/Margin")
	if not margin: return
	var vbox = margin.get_node_or_null("VBox")
	if not vbox: return
	
	# HBox for avatar and name
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)
	vbox.move_child(hbox, 0)
	
	var avatar_vbox = VBoxContainer.new()
	var profile_badge = _make_avatar_badge(100.0)
	profile_avatar = profile_badge.get_node("AvatarTex") as TextureRect
	avatar_vbox.add_child(profile_badge)
	
	var upload_btn = Button.new()
	upload_btn.text = "Upload Pic"
	upload_btn.pressed.connect(_on_upload_pic_pressed)
	avatar_vbox.add_child(upload_btn)
	hbox.add_child(avatar_vbox)
	
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	if %ProfileViewName.get_parent():
		%ProfileViewName.get_parent().remove_child(%ProfileViewName)
		name_vbox.add_child(%ProfileViewName)
		
	var name_edit_hbox = HBoxContainer.new()
	username_edit = LineEdit.new()
	username_edit.placeholder_text = "New Username"
	username_edit.custom_minimum_size = Vector2(150, 0)
	var update_name_btn = Button.new()
	update_name_btn.text = "Update"
	update_name_btn.pressed.connect(_on_update_username_pressed)
	name_edit_hbox.add_child(username_edit)
	name_edit_hbox.add_child(update_name_btn)
	name_vbox.add_child(name_edit_hbox)
	hbox.add_child(name_vbox)
	
	var xp_label = Label.new()
	xp_label.text = "Experience Progress"
	vbox.add_child(xp_label)
	var xp_hbox = HBoxContainer.new()
	xp_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_progress = ProgressBar.new()
	xp_progress.custom_minimum_size = Vector2(0, 20)
	xp_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_progress.show_percentage = false
	xp_hbox.add_child(xp_progress)
	
	var xp_spacer = Control.new()
	xp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_hbox.add_child(xp_spacer)
	vbox.add_child(xp_hbox)
	
	xp_text_label = Label.new()
	xp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(xp_text_label)
	
	var vault_label = Label.new()
	vault_label.text = "\nVAULT (Owned Items)"
	vault_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(vault_label)
	var vault_vbox = VBoxContainer.new()
	vault_vbox.name = "VaultVBox"
	vbox.add_child(vault_vbox)

func _setup_store_ui() -> void:
	if not %StoreView: return
	for c in %StoreView.get_children():
		if c.name != "Title":
			c.queue_free()
			
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	%StoreView.add_child(grid)
	
	for h in STORE_ITEMS_DB:
		var p = PanelContainer.new()
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_right", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		var v = VBoxContainer.new()
		
		# Add image
		if ResourceLoader.exists(h["image"]):
			var tex = TextureRect.new()
			tex.texture = load(h["image"])
			tex.custom_minimum_size = Vector2(80, 80)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			v.add_child(tex)
			
		var n = Label.new()
		n.text = h["name"]
		n.add_theme_font_size_override("font_size", 18)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var c = Label.new()
		c.text = "Cost: %d Momos" % h["cost"]
		c.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b = Button.new()
		b.text = "Buy"
		b.pressed.connect(func(): _on_buy_item(h["id"], h["cost"]))
		v.add_child(n)
		v.add_child(c)
		v.add_child(b)
		m.add_child(v)
		p.add_child(m)
		grid.add_child(p)

func _setup_level_up_modal() -> void:
	level_up_modal = ColorRect.new()
	level_up_modal.color = Color(0.03, 0.02, 0.08, 0.92)
	level_up_modal.set_anchors_preset(PRESET_FULL_RECT)
	level_up_modal.visible = false
	level_up_modal.z_index = 200
	add_child(level_up_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	level_up_modal.add_child(center)
	
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(480, 0)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.10, 0.18, 1.0)
	card_style.corner_radius_top_left = 20
	card_style.corner_radius_top_right = 20
	card_style.corner_radius_bottom_right = 20
	card_style.corner_radius_bottom_left = 20
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(1.0, 0.75, 0.1)
	p.add_theme_stylebox_override("panel", card_style)
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 50)
	m.add_theme_constant_override("margin_top", 45)
	m.add_theme_constant_override("margin_right", 50)
	m.add_theme_constant_override("margin_bottom", 45)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# ── Star / emoji decoration ───────────────────────────────────────────────
	var deco = Label.new()
	deco.text = "⭐ 🎉 ⭐"
	deco.add_theme_font_size_override("font_size", 32)
	deco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(deco)
	
	# ── Main title ────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	
	v.add_child(HSeparator.new())
	
	# ── Dynamic message ───────────────────────────────────────────────────────
	level_up_msg = Label.new()
	level_up_msg.text = "Congratulations!\nYou reached Level X!\n"
	level_up_msg.add_theme_font_size_override("font_size", 18)
	level_up_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(level_up_msg)
	
	# ── Momo bonus highlight box ─────────────────────────────────────────────
	var bonus_panel = PanelContainer.new()
	var bp_style = StyleBoxFlat.new()
	bp_style.bg_color = Color(0.1, 0.25, 0.1, 0.9)
	bp_style.corner_radius_top_left = 10
	bp_style.corner_radius_top_right = 10
	bp_style.corner_radius_bottom_right = 10
	bp_style.corner_radius_bottom_left = 10
	bp_style.border_width_left = 2
	bp_style.border_width_top = 2
	bp_style.border_width_right = 2
	bp_style.border_width_bottom = 2
	bp_style.border_color = Color(0.2, 0.9, 0.4)
	bp_style.content_margin_left = 20
	bp_style.content_margin_right = 20
	bp_style.content_margin_top = 12
	bp_style.content_margin_bottom = 12
	bonus_panel.add_theme_stylebox_override("panel", bp_style)
	
	var bonus_lbl = Label.new()
	bonus_lbl.text = "🥟 +50 Momos  Bonus Awarded!"
	bonus_lbl.add_theme_font_size_override("font_size", 20)
	bonus_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_panel.add_child(bonus_lbl)
	v.add_child(bonus_panel)
	
	# ── Confirm button ────────────────────────────────────────────────────────
	var btn_center = CenterContainer.new()
	var btn = Button.new()
	btn.text = "  Claim & Continue  "
	btn.custom_minimum_size = Vector2(180, 48)
	btn.pressed.connect(func(): level_up_modal.visible = false)
	btn_center.add_child(btn)
	v.add_child(btn_center)
	
	m.add_child(v)
	p.add_child(m)
	center.add_child(p)

func _on_leveled_up(new_level: int, gift: int) -> void:
	if level_up_msg:
		level_up_msg.text = "Congratulations!\nYou reached Level %d!" % new_level
	level_up_modal.visible = true
	_populate_user_data()
	_populate_profile_view()
	_show_level_up_banner(new_level)

func _on_upload_pic_pressed() -> void:
	if not file_dialog:
		file_dialog = FileDialog.new()
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.png, *.jpg, *.jpeg ; Images"]
		file_dialog.size = Vector2(600, 400)
		file_dialog.use_native_dialog = true
		file_dialog.file_selected.connect(_on_file_selected)
		add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	var img = Image.load_from_file(path)
	if img:
		var tex = ImageTexture.create_from_image(img)
		var user_name = SessionManager.get_current_user()
		var save_path = "user://profile_pic_" + user_name + ".png"
		img.save_png(save_path)
		SessionManager.set_profile_pic_path(save_path)
		_update_avatars(user_name)
			
func _on_update_username_pressed() -> void:
	if not username_edit or username_edit.text.is_empty(): return
	var res = SessionManager.update_username(username_edit.text)
	if res.get("success", false):
		username_edit.text = ""
		_populate_user_data()
		_populate_profile_view()

func _on_buy_item(hat_id: String, cost: int) -> void:
	if SessionManager.spend_momos(cost):
		SessionManager.unlock_hat(hat_id)
		_populate_user_data()
		_populate_profile_view()
		_populate_vault_view()
		_show_store_success(hat_id)

## Creates a circular avatar badge (Panel + TextureRect + Label for initials)
## Size: diameter in pixels. Returns the Panel (badge root).
func _make_avatar_badge(diameter: float) -> Panel:
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	
	var style = StyleBoxFlat.new()
	var radius = int(diameter / 2.0)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.bg_color = Color(0.20, 0.42, 0.72)  # Google-blue fallback
	badge.add_theme_stylebox_override("panel", style)
	badge.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	
	# TextureRect fills the badge (hidden until photo is loaded)
	var tex_rect = TextureRect.new()
	tex_rect.name = "AvatarTex"
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.visible = false
	badge.add_child(tex_rect)
	
	# Initial letter label (shown when no photo)
	var initial_lbl = Label.new()
	initial_lbl.name = "InitialLabel"
	initial_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_lbl.add_theme_font_size_override("font_size", int(diameter * 0.4))
	initial_lbl.add_theme_color_override("font_color", Color.WHITE)
	initial_lbl.text = "?"
	badge.add_child(initial_lbl)
	
	return badge

func _setup_avatars() -> void:
	# ── TOP BAR circular badge (40px) ────────────────────────────────────────
	var top_badge = _make_avatar_badge(40.0)
	top_badge.name = "TopAvatarBadge"
	if top_profile_name and top_profile_name.get_parent():
		top_profile_name.get_parent().add_child(top_badge)
		top_profile_name.get_parent().move_child(top_badge, top_profile_name.get_index())
	top_avatar = top_badge.get_node("AvatarTex") as TextureRect
	
	# ── SIDEBAR circular badge (56px) ────────────────────────────────────────
	var side_badge = _make_avatar_badge(56.0)
	side_badge.name = "SideAvatarBadge"
	side_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if side_profile_name and side_profile_name.get_parent():
		side_profile_name.get_parent().add_child(side_badge)
		side_profile_name.get_parent().move_child(side_badge, side_profile_name.get_index())
	side_avatar = side_badge.get_node("AvatarTex") as TextureRect

func _update_avatars(username: String) -> void:
	# Update the initial letter fallback in all badges
	var initial = username.substr(0, 1).to_upper() if username.length() > 0 else "?"
	for avatar_node in [top_avatar, side_avatar, profile_avatar]:
		if avatar_node and avatar_node.get_parent() and avatar_node.get_parent().has_node("InitialLabel"):
			avatar_node.get_parent().get_node("InitialLabel").text = initial
	
	var pic_path = SessionManager.get_profile_pic_path(username)
	
	# Also try loading from user:// directly if path is relative
	var img: Image = null
	if pic_path != "":
		img = Image.new()
		var err = img.load(pic_path)
		if err != OK:
			# Try the standard user:// path as fallback
			var fallback_path = "user://profile_pic_" + username.to_lower() + ".png"
			var err2 = img.load(fallback_path)
			if err2 != OK:
				img = null
	
	if img:
		var tex = ImageTexture.create_from_image(img)
		# Show photo, hide initial letter
		for avatar_node in [top_avatar, side_avatar, profile_avatar]:
			if avatar_node:
				avatar_node.texture = tex
				avatar_node.visible = true
				if avatar_node.get_parent() and avatar_node.get_parent().has_node("InitialLabel"):
					avatar_node.get_parent().get_node("InitialLabel").visible = false
	else:
		# No photo: show initial letter, hide photo
		for avatar_node in [top_avatar, side_avatar, profile_avatar]:
			if avatar_node:
				avatar_node.visible = false
				if avatar_node.get_parent() and avatar_node.get_parent().has_node("InitialLabel"):
					avatar_node.get_parent().get_node("InitialLabel").visible = true

func _setup_daily_reward_modal() -> void:
	daily_reward_modal = ColorRect.new()
	daily_reward_modal.color = Color(0, 0, 0, 0.85)
	daily_reward_modal.set_anchors_preset(PRESET_FULL_RECT)
	daily_reward_modal.visible = false
	add_child(daily_reward_modal)
	
	var c = CenterContainer.new()
	c.set_anchors_preset(PRESET_FULL_RECT)
	daily_reward_modal.add_child(c)
	var p = PanelContainer.new()
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	
	var t = Label.new()
	t.text = "DAILY LOGIN REWARD"
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	
	var msg = Label.new()
	msg.text = "Welcome back! Here is your daily gift:\n+25 Momos 🥟\n+100 XP ⭐"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	
	var btn = Button.new()
	btn.text = "Claim Reward"
	btn.custom_minimum_size = Vector2(150, 50)
	btn.pressed.connect(func():
		var user = SessionManager.get_current_user()
		SessionManager.add_user_momos(user, 25)
		SessionManager.add_xp(user, 100)
		_populate_user_data()
		_populate_profile_view()
		daily_reward_modal.visible = false
	)
	var bc = CenterContainer.new()
	bc.add_child(btn)
	v.add_child(bc)
	
	m.add_child(v)
	p.add_child(m)
	c.add_child(p)
	
	# Check if we should show it
	if SessionManager.is_logged_in():
		var username = SessionManager.get_current_user()
		var stats = SessionManager.get_user_stats(username)
		var last_claim = stats.get("last_daily_claim_day", -1)
		var current_day = int(Time.get_unix_time_from_system() / 86400)
		if current_day > last_claim:
			stats["last_daily_claim_day"] = current_day
			SessionManager._stats[username.to_lower()] = stats
			SessionManager._save_stats()
			daily_reward_modal.visible = true

func _setup_store_success_modal() -> void:
	store_success_modal = ColorRect.new()
	store_success_modal.color = Color(0, 0, 0, 0.8)
	store_success_modal.set_anchors_preset(PRESET_FULL_RECT)
	store_success_modal.visible = false
	add_child(store_success_modal)
	
	var c = CenterContainer.new()
	c.set_anchors_preset(PRESET_FULL_RECT)
	store_success_modal.add_child(c)
	var p = PanelContainer.new()
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	
	var t = Label.new()
	t.text = "CONGRATULATIONS!"
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	
	var icon = Label.new()
	icon.text = "🎉 📦 🎉"
	icon.add_theme_font_size_override("font_size", 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)
	
	store_success_msg = Label.new()
	store_success_msg.text = "You successfully purchased:\nItem Name"
	store_success_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(store_success_msg)
	
	var btn = Button.new()
	btn.text = "Awesome"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.pressed.connect(func(): store_success_modal.visible = false)
	var bc = CenterContainer.new()
	bc.add_child(btn)
	v.add_child(bc)
	
	m.add_child(v)
	p.add_child(m)
	c.add_child(p)

func _show_store_success(item_id: String) -> void:
	if store_success_msg:
		store_success_msg.text = "You successfully purchased:\n" + item_id.capitalize()
	if store_success_modal:
		store_success_modal.visible = true

func _setup_vault_ui() -> void:
	# Create Vault View Container next to other views
	var views_parent = lobby_view.get_parent()
	vault_view = VBoxContainer.new()
	vault_view.name = "VaultView"
	vault_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	vault_view.visible = false
	views_parent.add_child(vault_view)
	
	var title = Label.new()
	title.text = "YOUR VAULT"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	vault_view.add_child(title)
	
	vault_view.add_child(HSeparator.new())
	
	var grid = GridContainer.new()
	grid.name = "VaultGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	vault_view.add_child(grid)

func _populate_vault_view() -> void:
	if not is_instance_valid(vault_view): return
	var grid = vault_view.get_node_or_null("VaultGrid")
	if not grid: return
	
	for c in grid.get_children():
		c.queue_free()
		
	if not SessionManager or not SessionManager.is_logged_in():
		var msg = Label.new()
		msg.text = "Please log in to see your vault."
		grid.add_child(msg)
		return
		
	var username = SessionManager.get_current_user()
	
	# Owned hats are stored in the user DB (not stats), so fetch directly
	var owned: Array = []
	if SessionManager.has_method("get_owned_items"):
		owned = SessionManager.get_owned_items()
	else:
		# Fallback: read from stats
		var stats = SessionManager.get_user_stats(username)
		owned = stats.get("owned_hats", [])
	
	if owned.is_empty():
		var msg = Label.new()
		msg.text = "You do not own any items. Visit the store!"
		msg.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		msg.add_theme_font_size_override("font_size", 18)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(msg)
		return
		
	for item_id in owned:
		var p = PanelContainer.new()
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_right", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		var v = VBoxContainer.new()
		
		var item_name = item_id.capitalize()
		var img_path = ""
		for si in STORE_ITEMS_DB:
			if si["id"] == item_id:
				item_name = si["name"]
				img_path = si["image"]
				break
				
		if img_path != "" and ResourceLoader.exists(img_path):
			var tex = TextureRect.new()
			tex.texture = load(img_path)
			tex.custom_minimum_size = Vector2(80, 80)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			v.add_child(tex)
			
		var n = Label.new()
		n.text = item_name
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		
		var b = Button.new()
		var equipped = SessionManager.get_equipped_hat() == item_id
		b.text = "✓ Equipped" if equipped else "Equip"
		b.disabled = equipped
		if not equipped:
			b.pressed.connect(func():
				SessionManager.equip_hat(item_id)
				_populate_vault_view()
				_populate_profile_view()
			)
		v.add_child(b)
		m.add_child(v)
		p.add_child(m)
		grid.add_child(p)

func _setup_daily_challenges() -> void:
	var card = find_child("ChallengesCard")
	if not card: return
	
	for c in card.get_children(): c.queue_free()
		
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "Daily Challenges"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var challenges = [
		{"name": "Collect 50 Momos", "current": 25, "max": 50},
		{"name": "Play 5 Rounds", "current": 2, "max": 5},
		{"name": "Login Today", "current": 1, "max": 1}
	]
	
	for ch in challenges:
		var hb = HBoxContainer.new()
		var l = Label.new()
		l.text = ch["name"]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		
		var pb = ProgressBar.new()
		pb.custom_minimum_size = Vector2(100, 20)
		pb.max_value = ch["max"]
		pb.value = ch["current"]
		pb.show_percentage = false
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.8, 0.2)
		pb.add_theme_stylebox_override("fill", sb)
		hb.add_child(pb)
		
		var tl = Label.new()
		tl.text = "%d/%d" % [ch["current"], ch["max"]]
		tl.custom_minimum_size = Vector2(40, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(tl)
		vbox.add_child(hb)
		
	m.add_child(vbox)
	card.add_child(m)

func _setup_streak_rewards() -> void:
	var card = find_child("RewardsCard")
	if not card: return
	
	for c in card.get_children(): c.queue_free()
		
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "Daily Login Streak"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var streak = 3 # Simulated streak
	
	var l = Label.new()
	l.text = "Current Streak: %d Days" % streak
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	vbox.add_child(l)
	
	var nxt = Label.new()
	nxt.text = "Next Reward: 5 Days (Avatar)"
	nxt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nxt)
	
	m.add_child(vbox)
	card.add_child(m)

# ─────────────────────────────────────────────────────────────────────────────
# SETTINGS – Password Change
# ─────────────────────────────────────────────────────────────────────────────
var _pw_old_input: LineEdit
var _pw_new_input: LineEdit
var _pw_confirm_input: LineEdit
var _pw_status_label: Label

func _setup_settings_ui() -> void:
	if not settings_view: return
	# Clear placeholder label
	for c in settings_view.get_children():
		if c is Label and c.text.begins_with("[ Video"):
			c.queue_free()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.10, 0.16, 1.0)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.25, 0.30, 0.45)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(480, 0)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	
	var sec_title = Label.new()
	sec_title.text = "🔒  Change Password"
	sec_title.add_theme_font_size_override("font_size", 22)
	sec_title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	vb.add_child(sec_title)
	
	vb.add_child(HSeparator.new())
	
	# Input fields with eye-toggle
	for field_data in [
		["Current Password", true],
		["New Password", true],
		["Confirm New Password", true]
	]:
		var lbl = Label.new()
		lbl.text = field_data[0]
		lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		vb.add_child(lbl)
		
		# Wrap input + eye toggle in an HBox
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		
		var le = LineEdit.new()
		le.secret = true
		le.placeholder_text = field_data[0]
		le.custom_minimum_size = Vector2(0, 44)
		le.add_theme_font_size_override("font_size", 16)
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(le)
		
		var eye_btn = Button.new()
		eye_btn.text = "👁"
		eye_btn.custom_minimum_size = Vector2(44, 44)
		eye_btn.toggle_mode = true
		eye_btn.flat = true
		eye_btn.toggled.connect(func(pressed: bool): le.secret = not pressed)
		row.add_child(eye_btn)
		
		vb.add_child(row)
		if field_data[0] == "Current Password":
			_pw_old_input = le
		elif field_data[0] == "New Password":
			_pw_new_input = le
		else:
			_pw_confirm_input = le
	
	# Status label
	_pw_status_label = Label.new()
	_pw_status_label.text = ""
	_pw_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_status_label.add_theme_font_size_override("font_size", 15)
	_pw_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_pw_status_label)
	
	# Confirm button
	var btn_center = CenterContainer.new()
	var btn = Button.new()
	btn.text = "  Confirm Change  "
	btn.custom_minimum_size = Vector2(200, 48)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_change_password_pressed)
	btn_center.add_child(btn)
	vb.add_child(btn_center)
	
	card.add_child(vb)
	margin.add_child(card)
	settings_view.add_child(margin)

func _on_change_password_pressed() -> void:
	if not _pw_old_input or not _pw_new_input or not _pw_confirm_input or not _pw_status_label:
		return
	var old_pw = _pw_old_input.text.strip_edges()
	var new_pw = _pw_new_input.text.strip_edges()
	var confirm_pw = _pw_confirm_input.text.strip_edges()
	
	if old_pw.is_empty() or new_pw.is_empty() or confirm_pw.is_empty():
		_pw_status_label.text = "⚠ Please fill in all fields."
		_pw_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		return
	if new_pw != confirm_pw:
		_pw_status_label.text = "✗ New passwords do not match."
		_pw_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	
	_pw_status_label.text = "⏳ Changing password..."
	_pw_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	var result = await SessionManager.change_password(old_pw, new_pw)
	if result["ok"]:
		_pw_status_label.text = "✓ " + result["msg"]
		_pw_status_label.add_theme_color_override("font_color", Color(0.25, 0.90, 0.45))
		_pw_old_input.text = ""
		_pw_new_input.text = ""
		_pw_confirm_input.text = ""
	else:
		_pw_status_label.text = "✗ " + result["msg"]
		_pw_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

# ─────────────────────────────────────────────────────────────────────────────
# LEVEL-UP LOBBY BANNER
# ─────────────────────────────────────────────────────────────────────────────
var _level_up_banner: PanelContainer

func _setup_level_up_banner() -> void:
	_level_up_banner = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.22, 0.08, 0.95)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_right = 12
	s.corner_radius_bottom_left = 12
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.border_color = Color(0.2, 0.95, 0.4)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	_level_up_banner.add_theme_stylebox_override("panel", s)
	_level_up_banner.visible = false
	_level_up_banner.z_index = 150
	
	# Anchor to bottom-center of screen
	_level_up_banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_level_up_banner.anchor_left = 0.15
	_level_up_banner.anchor_right = 0.85
	_level_up_banner.anchor_top = 0.85
	_level_up_banner.anchor_bottom = 0.97
	_level_up_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_level_up_banner.grow_vertical = Control.GROW_DIRECTION_END
	
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var lbl = Label.new()
	lbl.name = "BannerLabel"
	lbl.text = "🎉  Congratulations! You leveled up!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func(): _level_up_banner.visible = false)
	hb.add_child(close_btn)
	
	_level_up_banner.add_child(hb)
	add_child(_level_up_banner)

func _show_level_up_banner(new_level: int) -> void:
	if not is_instance_valid(_level_up_banner): return
	var lbl = _level_up_banner.get_node_or_null("BannerLabel")
	if lbl:
		lbl.text = "🎉  Congratulations! You reached Level %d! (+50 Momos)" % new_level
	_level_up_banner.visible = true
	# Auto-hide after 6 seconds
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(_level_up_banner):
			_level_up_banner.visible = false
	)
