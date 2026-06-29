extends Control

## AuthScreen v3 — Matches the Yeti Run mockup using Scene Unique Nodes (%Node)
## This makes the script completely immune to UI hierarchy changes.

# ─────────────────────────────────────────────────────────────────────────────
# NODE REFERENCES (Using %UniqueNames)
# ─────────────────────────────────────────────────────────────────────────────
@onready var glass_panel: PanelContainer = %GlassPanel

# ── Login form ──
@onready var login_form:       VBoxContainer = %LoginForm
@onready var login_username:   LineEdit      = %LoginUsernameField
@onready var login_password:   LineEdit      = %LoginPasswordField
@onready var login_btn:        Button        = %LoginButton
@onready var login_msg:        Label         = %LoginMessageLabel
@onready var goto_signup_btn:  Button        = %GoToSignupButton

# ── Signup form ──
@onready var signup_form:      VBoxContainer = %SignupForm
@onready var signup_username:  LineEdit      = %SignupUsernameField
@onready var signup_password:  LineEdit      = %SignupPasswordField
@onready var signup_confirm:   LineEdit      = %SignupConfirmField
@onready var signup_btn:       Button        = %SignupButton
@onready var signup_msg:       Label         = %SignupMessageLabel
@onready var goto_login_btn:   Button        = %GoToLoginButton

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const DASHBOARD_SCENE: String = "res://Dashboard.tscn"

const MSG_COLOR_ERROR: Color = Color(1.00, 0.45, 0.45, 1.0)
const MSG_COLOR_OK:    Color = Color(0.45, 1.00, 0.75, 1.0)
const MSG_COLOR_INFO:  Color = Color(0.65, 0.85, 1.00, 1.0)

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────
var _form_tween: Tween
var remember_me_checkbox: CheckBox
var forgot_pw_btn: Button
var loading_spinner: Label
var spinner_tween: Tween
var forgot_popup: PanelContainer

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Start with login form visible
	login_form.show()
	signup_form.hide()

	# Connect signals
	login_btn.pressed.connect(_on_login_pressed)
	signup_btn.pressed.connect(_on_signup_pressed)
	goto_signup_btn.pressed.connect(_switch_to_signup)
	goto_login_btn.pressed.connect(_switch_to_login)

	_set_msg(login_msg,  "", MSG_COLOR_INFO)
	_set_msg(signup_msg, "", MSG_COLOR_INFO)

	# Enter keys
	login_password.gui_input.connect(_on_login_password_key)
	signup_confirm.gui_input.connect(_on_signup_confirm_key)

	# 1. Real-time validation connections
	login_username.text_changed.connect(func(_new_text): _validate_username_field(login_username))
	signup_username.text_changed.connect(func(_new_text): _validate_username_field(signup_username))
	signup_password.text_changed.connect(_on_signup_password_changed)

	# Setup password strength bar in Signup
	var strength_bar = ProgressBar.new()
	strength_bar.name = "StrengthBar"
	strength_bar.max_value = 3
	strength_bar.step = 1
	strength_bar.value = 0
	strength_bar.show_percentage = false
	signup_form.add_child(strength_bar)
	var idx = signup_password.get_index()
	signup_form.move_child(strength_bar, idx + 1)

	# 2. Loading spinner setup
	_create_loading_spinner()

	# 3. Remember Me setup
	_setup_remember_me()

	# 4. Forgot Password setup
	_setup_forgot_password_btn()

	# 5. Password visibility toggle
	_setup_password_visibility_toggle()

	# 6. Snow particle background
	_setup_snow_bg()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		SessionManager.register_user("testuser", "testpassword")
		var result = SessionManager.login_user("testuser", "testpassword")
		if result["success"]:
			get_tree().change_scene_to_file(DASHBOARD_SCENE)


func _on_login_password_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_login_pressed()


func _on_signup_confirm_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_signup_pressed()

# ─────────────────────────────────────────────────────────────────────────────
# TRANSITIONS
# ─────────────────────────────────────────────────────────────────────────────
func _switch_to_signup() -> void:
	_clear_fields()
	_cross_fade(login_form, signup_form)


func _switch_to_login() -> void:
	_clear_fields()
	_cross_fade(signup_form, login_form)


func _cross_fade(from_form: VBoxContainer, to_form: VBoxContainer) -> void:
	if _form_tween:
		_form_tween.kill()
	_form_tween = create_tween()
	_form_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	_form_tween.tween_property(from_form, "modulate:a", 0.0, 0.15)
	_form_tween.tween_callback(func() -> void:
		from_form.hide()
		to_form.modulate.a = 0.0
		to_form.show()
	)
	_form_tween.tween_property(to_form, "modulate:a", 1.0, 0.22)

# ─────────────────────────────────────────────────────────────────────────────
# LOGIC
# ─────────────────────────────────────────────────────────────────────────────
func _on_login_pressed() -> void:
	var username: String = login_username.text.strip_edges()
	var password: String = login_password.text

	if username.is_empty() or password.is_empty():
		_set_msg(login_msg, "⚠ Please fill out all fields.", MSG_COLOR_ERROR)
		return

	_set_msg(login_msg, "Authenticating…", MSG_COLOR_INFO)
	_start_loading_animation()
	var start_time = Time.get_ticks_msec()
	
	var result: Dictionary = SessionManager.login_user(username, password)
	
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < 0.5:
		await get_tree().create_timer(0.5 - elapsed).timeout
		
	_stop_loading_animation()

	if result["success"]:
		_set_msg(login_msg, "✔ " + result["message"], MSG_COLOR_OK)
		
		# Remember me handling
		if remember_me_checkbox.button_pressed:
			var cfg = ConfigFile.new()
			cfg.set_value("auth", "username", username)
			cfg.save("user://last_user.cfg")
		else:
			var dir = DirAccess.open("user://")
			if dir and dir.file_exists("last_user.cfg"):
				dir.remove("last_user.cfg")
				
		_clear_fields()
		_animate_login_success()
	else:
		_set_msg(login_msg, "✘ " + result["message"], MSG_COLOR_ERROR)
		_shake(glass_panel)


func _on_signup_pressed() -> void:
	var username: String = signup_username.text.strip_edges()
	var password: String = signup_password.text
	var confirm:  String = signup_confirm.text

	if username.length() < 4:
		_set_msg(signup_msg, "⚠ Username must be at least 4 characters.", MSG_COLOR_ERROR)
		return
	if password.length() < 6:
		_set_msg(signup_msg, "⚠ Password must be at least 6 characters.", MSG_COLOR_ERROR)
		return
	if password != confirm:
		_set_msg(signup_msg, "⚠ Passwords do not match!", MSG_COLOR_ERROR)
		_shake(glass_panel)
		return

	_set_msg(signup_msg, "Creating account…", MSG_COLOR_INFO)
	_start_loading_animation()
	var start_time = Time.get_ticks_msec()
	
	var result: Dictionary = SessionManager.register_user(username, password)
	
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < 0.5:
		await get_tree().create_timer(0.5 - elapsed).timeout
		
	_stop_loading_animation()

	if result["success"]:
		_set_msg(signup_msg, "✔ " + result["message"], MSG_COLOR_OK)
		_clear_fields()
		await get_tree().create_timer(1.0).timeout
		_switch_to_login()
		_set_msg(login_msg, "Account created — please log in.", MSG_COLOR_INFO)
	else:
		_set_msg(signup_msg, "✘ " + result["message"], MSG_COLOR_ERROR)
		_shake(glass_panel)


func _set_msg(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.modulate = color


func _clear_fields() -> void:
	login_username.text = ""
	login_password.text = ""
	signup_username.text = ""
	signup_password.text = ""
	signup_confirm.text = ""
	login_username.remove_theme_stylebox_override("normal")
	signup_username.remove_theme_stylebox_override("normal")
	if has_node("SignupForm/StrengthBar"):
		get_node("SignupForm/StrengthBar").value = 0
	_set_msg(login_msg, "", MSG_COLOR_INFO)
	_set_msg(signup_msg, "", MSG_COLOR_INFO)


func _shake(target: Control) -> void:
	var ox: float = target.position.x
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	for i: int in range(5):
		var d: float = 6.0 if i % 2 == 0 else -6.0
		tw.tween_property(target, "position:x", ox + d, 0.04)
	tw.tween_property(target, "position:x", ox, 0.04)


# ─────────────────────────────────────────────────────────────────────────────
# UX SYSTEMS — VALIDATION, SPINNER, REMEMBER ME, FORGOT PW, TRANSITIONS
# ─────────────────────────────────────────────────────────────────────────────
func _validate_username_field(line_edit: LineEdit) -> void:
	var text = line_edit.text.strip_edges()
	if text.is_empty():
		line_edit.remove_theme_stylebox_override("normal")
		return
		
	var is_valid = text.length() >= 4 and text.length() <= 24
	if is_valid:
		var regex = RegEx.new()
		regex.compile("^[a-zA-Z0-9_]+$")
		is_valid = regex.search(text) != null
		
	var style = line_edit.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.8, 0.2) if is_valid else Color(0.8, 0.2, 0.2)
		line_edit.add_theme_stylebox_override("normal", style)

func _on_signup_password_changed(new_text: String) -> void:
	var strength = 0
	if new_text.length() >= 6:
		strength += 1
	var regex_digit = RegEx.new()
	regex_digit.compile("\\d")
	if regex_digit.search(new_text) != null:
		strength += 1
	var regex_symbol = RegEx.new()
	regex_symbol.compile("[^a-zA-Z0-9]")
	if regex_symbol.search(new_text) != null:
		strength += 1
		
	if has_node("SignupForm/StrengthBar"):
		var bar = get_node("SignupForm/StrengthBar") as ProgressBar
		bar.value = strength
		var fill_style: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
		if fill_style:
			if strength <= 1:
				fill_style.bg_color = Color(0.8, 0.2, 0.2)
			elif strength == 2:
				fill_style.bg_color = Color(0.8, 0.6, 0.2)
			else:
				fill_style.bg_color = Color(0.2, 0.8, 0.2)
			bar.add_theme_stylebox_override("fill", fill_style)

func _create_loading_spinner() -> void:
	loading_spinner = Label.new()
	loading_spinner.name = "LoadingSpinner"
	loading_spinner.text = "⭕"
	loading_spinner.add_theme_font_size_override("font_size", 48)
	loading_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_spinner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_spinner.pivot_offset = Vector2(24, 24)
	loading_spinner.visible = false
	
	var center_container = CenterContainer.new()
	center_container.name = "SpinnerCenter"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.visible = false
	center_container.add_child(loading_spinner)
	add_child(center_container)

func _start_loading_animation() -> void:
	_set_buttons_disabled(true)
	loading_spinner.get_parent().visible = true
	loading_spinner.visible = true
	
	if spinner_tween:
		spinner_tween.kill()
	loading_spinner.rotation = 0.0
	spinner_tween = create_tween().set_loops()
	spinner_tween.tween_property(loading_spinner, "rotation", 2.0 * PI, 1.0)

func _stop_loading_animation() -> void:
	if spinner_tween:
		spinner_tween.kill()
		spinner_tween = null
	if loading_spinner:
		loading_spinner.visible = false
		loading_spinner.get_parent().visible = false
	_set_buttons_disabled(false)

func _set_buttons_disabled(disabled: bool) -> void:
	login_btn.disabled = disabled
	signup_btn.disabled = disabled
	goto_signup_btn.disabled = disabled
	goto_login_btn.disabled = disabled
	if is_instance_valid(remember_me_checkbox):
		remember_me_checkbox.disabled = disabled
	if is_instance_valid(forgot_pw_btn):
		forgot_pw_btn.disabled = disabled

func _setup_remember_me() -> void:
	remember_me_checkbox = CheckBox.new()
	remember_me_checkbox.name = "RememberMeCheckBox"
	remember_me_checkbox.text = "Remember me"
	remember_me_checkbox.add_theme_font_size_override("font_size", 16)
	login_form.add_child(remember_me_checkbox)
	var idx = login_password.get_index()
	login_form.move_child(remember_me_checkbox, idx + 1)
	
	var cfg = ConfigFile.new()
	var err = cfg.load("user://last_user.cfg")
	if err == OK:
		var last_user = cfg.get_value("auth", "username", "")
		if not last_user.is_empty():
			login_username.text = last_user
			remember_me_checkbox.button_pressed = true

func _setup_forgot_password_btn() -> void:
	forgot_pw_btn = Button.new()
	forgot_pw_btn.name = "ForgotPasswordBtn"
	forgot_pw_btn.text = "Forgot Password?"
	forgot_pw_btn.flat = true
	forgot_pw_btn.add_theme_font_size_override("font_size", 14)
	forgot_pw_btn.add_theme_color_override("font_color", Color(0.65, 0.85, 1.00))
	login_form.add_child(forgot_pw_btn)
	var idx = remember_me_checkbox.get_index()
	login_form.move_child(forgot_pw_btn, idx + 1)
	forgot_pw_btn.pressed.connect(_on_forgot_pw_pressed)

func _on_forgot_pw_pressed() -> void:
	if forgot_popup:
		return
		
	var username = login_username.text.strip_edges().to_lower()
	if username.is_empty():
		_set_msg(login_msg, "⚠ Please enter username in the field first.", MSG_COLOR_ERROR)
		return
		
	forgot_popup = PanelContainer.new()
	forgot_popup.name = "ForgotPopup"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.65, 0.65)
	forgot_popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	forgot_popup.add_child(vbox)
	
	var title = Label.new()
	title.text = "🔑 RESET PASSWORD FOR: " + username.to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var uid_input = LineEdit.new()
	uid_input.placeholder_text = "Enter your UID"
	uid_input.add_theme_font_size_override("font_size", 16)
	vbox.add_child(uid_input)
	
	var new_pw_input = LineEdit.new()
	new_pw_input.placeholder_text = "New Password"
	new_pw_input.secret = true
	new_pw_input.add_theme_font_size_override("font_size", 16)
	vbox.add_child(new_pw_input)
	
	var confirm_pw_input = LineEdit.new()
	confirm_pw_input.placeholder_text = "Confirm New Password"
	confirm_pw_input.secret = true
	confirm_pw_input.add_theme_font_size_override("font_size", 16)
	vbox.add_child(confirm_pw_input)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.add_theme_font_size_override("font_size", 16)
	reset_btn.custom_minimum_size = Vector2(100, 40)
	hbox.add_child(reset_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	hbox.add_child(cancel_btn)
	
	var popup_msg = Label.new()
	popup_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_msg.add_theme_font_size_override("font_size", 14)
	vbox.add_child(popup_msg)
	
	cancel_btn.pressed.connect(func(): 
		forgot_popup.queue_free()
		forgot_popup = null
	)
	
	reset_btn.pressed.connect(func():
		var entered_uid = uid_input.text.strip_edges().to_upper()
		var new_pw = new_pw_input.text
		var confirm_pw = confirm_pw_input.text
		
		if entered_uid.is_empty() or new_pw.is_empty() or confirm_pw.is_empty():
			popup_msg.text = "⚠ Please fill all fields."
			popup_msg.modulate = MSG_COLOR_ERROR
			return
			
		if new_pw.length() < 6:
			popup_msg.text = "⚠ Password must be at least 6 characters."
			popup_msg.modulate = MSG_COLOR_ERROR
			return
			
		if new_pw != confirm_pw:
			popup_msg.text = "⚠ Passwords do not match!"
			popup_msg.modulate = MSG_COLOR_ERROR
			return
			
		var actual_uid = SessionManager.get_uid(username)
		if actual_uid.is_empty() or entered_uid != actual_uid:
			popup_msg.text = "✘ Incorrect UID for this user."
			popup_msg.modulate = MSG_COLOR_ERROR
			return
			
		SessionManager._users[username]["hash"] = SessionManager._hash_password(new_pw)
		var saved = SessionManager._save_database()
		if saved:
			_show_toast("Password reset!")
			forgot_popup.queue_free()
			forgot_popup = null
		else:
			popup_msg.text = "✘ Failed to save database."
			popup_msg.modulate = MSG_COLOR_ERROR
	)
	
	add_child(forgot_popup)
	forgot_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _show_toast(message: String) -> void:
	var toast = Label.new()
	toast.text = message
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", MSG_COLOR_OK)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(toast)
	add_child(panel)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 50)
	
	var tween = create_tween()
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(panel.queue_free)

func _setup_snow_bg() -> void:
	var snow_bg = CPUParticles2D.new()
	snow_bg.name = "SnowBG"
	snow_bg.amount = 120
	snow_bg.lifetime = 6.0
	snow_bg.gravity = Vector2(0, 40)
	snow_bg.initial_velocity_min = 10.0
	snow_bg.initial_velocity_max = 30.0
	snow_bg.spread = 180.0
	snow_bg.scale_amount_min = 2.0
	snow_bg.scale_amount_max = 6.0
	snow_bg.color = Color(1, 1, 1, 0.6)
	
	var viewport_w = get_viewport_rect().size.x
	if viewport_w <= 0:
		viewport_w = 1920
		
	snow_bg.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_bg.emission_rect_extents = Vector2(viewport_w / 2.0, 10)
	snow_bg.position = Vector2(viewport_w / 2.0, -10)
	
	add_child(snow_bg)
	move_child(snow_bg, 0)
	snow_bg.emitting = true

func _animate_login_success() -> void:
	var dashboard_scene_res = load(DASHBOARD_SCENE)
	if not dashboard_scene_res:
		get_tree().change_scene_to_file(DASHBOARD_SCENE)
		return
		
	var viewport_container = SubViewportContainer.new()
	viewport_container.name = "TransitionContainer"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(get_viewport_rect().size)
	sub_viewport.transparent_bg = true
	viewport_container.add_child(sub_viewport)
	
	var dashboard_instance = dashboard_scene_res.instantiate()
	sub_viewport.add_child(dashboard_instance)
	
	add_child(viewport_container)
	
	var screen_w = get_viewport_rect().size.x
	if screen_w <= 0:
		screen_w = 1920
		
	viewport_container.position.x = screen_w
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(glass_panel, "position:x", -1920, 0.4)
	tween.tween_property(viewport_container, "position:x", 0.0, 0.4)
	
	tween.chain().tween_callback(func():
		get_tree().change_scene_to_file(DASHBOARD_SCENE)
	)

func _setup_password_visibility_toggle() -> void:
	var toggle_btn = Button.new()
	toggle_btn.name = "TogglePasswordBtn"
	toggle_btn.text = "👁 Show Password"
	toggle_btn.flat = true
	toggle_btn.add_theme_font_size_override("font_size", 14)
	toggle_btn.add_theme_color_override("font_color", Color(0.65, 0.85, 1.00))
	login_form.add_child(toggle_btn)
	var idx = login_password.get_index()
	login_form.move_child(toggle_btn, idx + 1)
	
	toggle_btn.pressed.connect(func():
		login_password.secret = not login_password.secret
		toggle_btn.text = "👁 Hide Password" if not login_password.secret else "👁 Show Password"
	)
