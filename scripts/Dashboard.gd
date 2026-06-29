extends Control

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const AUTH_SCENE: String = "res://AuthScreen.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/SettingsScreen.tscn"

# ─────────────────────────────────────────────────────────────────────────────
# TOP BAR
# ─────────────────────────────────────────────────────────────────────────────
@onready var top_profile_name: Label = %TopProfileName

# --- NEW UI REFS ---
@onready var money_label: Label = $MainVBox/TopBar/Margin/HBox/RightSide/Money
var file_dialog: FileDialog
var level_up_modal: ColorRect
var level_up_msg: Label
var xp_progress: ProgressBar
var profile_avatar: TextureRect
var username_edit: LineEdit

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
	
	_populate_user_data()
	_show_view(lobby_view)

	if NetworkManager:
		NetworkManager.room_created.connect(_on_room_created)
		NetworkManager.join_failed.connect(_on_join_failed)
		NetworkManager.player_list_changed.connect(_refresh_lobby_player_list)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		
	if SessionManager:
		if not SessionManager.leveled_up.is_connected(_on_leveled_up):
			SessionManager.leveled_up.connect(_on_leveled_up)

# ─────────────────────────────────────────────────────────────────────────────
# NAV
# ─────────────────────────────────────────────────────────────────────────────
func _connect_nav_buttons() -> void:
	if nav_btn_lobby:   nav_btn_lobby.pressed.connect(func(): _show_view(lobby_view))
	if nav_btn_profile: nav_btn_profile.pressed.connect(func(): _show_view(profile_view); _populate_profile_view())
	if nav_btn_store:   nav_btn_store.pressed.connect(func(): _show_view(store_view))
	if nav_btn_settings:nav_btn_settings.pressed.connect(func(): _show_view(settings_view))
	if nav_btn_social:  nav_btn_social.pressed.connect(func(): _show_view(social_view); _populate_social_view())
	if nav_btn_logout:  nav_btn_logout.pressed.connect(_on_logout_pressed)

func _show_view(target: Control) -> void:
	var views: Array[Control] = [lobby_view, profile_view, store_view, settings_view, social_view]
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

func _populate_social_view() -> void:
	if not SessionManager or not SessionManager.is_logged_in(): return
	var username = SessionManager.get_current_user()
	if my_uid_label:
		my_uid_label.text = "Your UID: %s" % SessionManager.get_uid(username)
	_refresh_friends_lists()

func _refresh_friends_lists() -> void:
	if not SessionManager or not SessionManager.is_logged_in(): return
	# Clear old entries
	if requests_v_box:
		for c in requests_v_box.get_children(): c.queue_free()
	if friends_v_box:
		for c in friends_v_box.get_children(): c.queue_free()

	var requests: Array = SessionManager.get_friend_requests()
	for uid in requests:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "%s (UID)" % uid
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accept_btn = Button.new()
		accept_btn.text = "✅"
		accept_btn.pressed.connect(func(): _accept_request(uid))
		var reject_btn = Button.new()
		reject_btn.text = "❌"
		reject_btn.pressed.connect(func(): _reject_request(uid))
		row.add_child(lbl)
		row.add_child(accept_btn)
		row.add_child(reject_btn)
		requests_v_box.add_child(row)

	var friends: Array = SessionManager.get_friends()
	for uid in friends:
		var name_str = SessionManager.get_username_by_uid(uid)
		var lbl = Label.new()
		lbl.text = "👤 %s" % name_str
		friends_v_box.add_child(lbl)

# ─────────────────────────────────────────────────────────────────────────────
# SOCIAL BUTTON HANDLERS
# ─────────────────────────────────────────────────────────────────────────────
func _connect_social_buttons() -> void:
	if add_friend_btn:
		add_friend_btn.pressed.connect(_on_add_friend)

func _on_add_friend() -> void:
	if not friend_uid_input or not SessionManager: return
	var uid = friend_uid_input.text.strip_edges().to_upper()
	if uid.is_empty():
		if social_msg: social_msg.text = "Enter a UID first."
		return
	var result = SessionManager.send_friend_request(uid)
	if social_msg:
		social_msg.text = result.get("message", "")
	if result.get("success", false):
		friend_uid_input.text = ""
		_refresh_friends_lists()

func _accept_request(uid: String) -> void:
	SessionManager.accept_friend_request(uid)
	_refresh_friends_lists()

func _reject_request(uid: String) -> void:
	SessionManager.reject_friend_request(uid)
	_refresh_friends_lists()

# ─────────────────────────────────────────────────────────────────────────────
# LOGOUT
# ─────────────────────────────────────────────────────────────────────────────
func _on_logout_pressed() -> void:
	if NetworkManager: NetworkManager.leave_room()
	if SessionManager: SessionManager.logout()
	get_tree().change_scene_to_file(AUTH_SCENE)

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
	profile_avatar = TextureRect.new()
	profile_avatar.custom_minimum_size = Vector2(100, 100)
	profile_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.3, 0.4)
	bg.custom_minimum_size = Vector2(100, 100)
	bg.add_child(profile_avatar)
	profile_avatar.set_anchors_preset(PRESET_FULL_RECT)
	avatar_vbox.add_child(bg)
	
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
	xp_progress = ProgressBar.new()
	xp_progress.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(xp_progress)
	
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
			
	var hats = [
		{"id": "dhaka_topi", "name": "Dhaka Topi", "cost": 100},
		{"id": "everest_crown", "name": "Everest Crown", "cost": 250},
		{"id": "sherpa_cap", "name": "Sherpa Cap", "cost": 150},
		{"id": "yak_horns", "name": "Yak Horns", "cost": 300},
		{"id": "kukri_band", "name": "Kukri Band", "cost": 200}
	]
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	%StoreView.add_child(grid)
	
	for h in hats:
		var p = PanelContainer.new()
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_right", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		var v = VBoxContainer.new()
		var n = Label.new()
		n.text = h["name"]
		n.add_theme_font_size_override("font_size", 18)
		var c = Label.new()
		c.text = "Cost: %d Momos" % h["cost"]
		c.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
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
	level_up_modal.color = Color(0, 0, 0, 0.8)
	level_up_modal.set_anchors_preset(PRESET_FULL_RECT)
	level_up_modal.visible = false
	add_child(level_up_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	level_up_modal.add_child(center)
	
	var p = PanelContainer.new()
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	level_up_msg = Label.new()
	level_up_msg.text = "You reached level X!\nGift: 50 Momos"
	level_up_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = "Confirm"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.pressed.connect(func(): level_up_modal.visible = false)
	
	v.add_child(title)
	v.add_child(level_up_msg)
	v.add_child(btn)
	m.add_child(v)
	p.add_child(m)
	center.add_child(p)

func _on_leveled_up(new_level: int, gift: int) -> void:
	level_up_msg.text = "Congratulations!\nYou reached Level %d!\nGift: %d Momos!" % [new_level, gift]
	level_up_modal.visible = true
	_populate_user_data()
	_populate_profile_view()

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
		if profile_avatar:
			profile_avatar.texture = tex
			
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
