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
	login_btn.disabled = true
	call_deferred("_do_login", username, password)


func _do_login(username: String, password: String) -> void:
	var result: Dictionary = SessionManager.login_user(username, password)
	login_btn.disabled = false

	if result["success"]:
		_set_msg(login_msg, "✔ " + result["message"], MSG_COLOR_OK)
		_clear_fields()
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file(DASHBOARD_SCENE)
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
	signup_btn.disabled = true
	call_deferred("_do_signup", username, password)


func _do_signup(username: String, password: String) -> void:
	var result: Dictionary = SessionManager.register_user(username, password)
	signup_btn.disabled = false

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
	_set_msg(login_msg, "", MSG_COLOR_INFO)
	_set_msg(signup_msg, "", MSG_COLOR_INFO)


func _shake(target: Control) -> void:
	var ox: float = target.position.x
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	for i: int in range(5):
		var d: float = 6.0 if i % 2 == 0 else -6.0
		tw.tween_property(target, "position:x", ox + d, 0.04)
	tw.tween_property(target, "position:x", ox, 0.04)
