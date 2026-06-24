extends CharacterBody3D

## ─── EXPORTED TUNABLES ───────────────────────────────────────────────────────
@export var SPEED: float = 9.0
@export var JUMP_VELOCITY: float = 14.0      # Increased: enough to clear Round 1 hurdles
@export var DIVE_FORCE: float = 12.0
@export var MOUSE_SENSITIVITY: float = 0.003
@export var GRAVITY: float = 28.0           # Slightly higher gravity for snappy feel

## ─── NODE REFERENCES ─────────────────────────────────────────────────────────
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var visuals: Node3D = $Visuals
@onready var step_up_cast: ShapeCast3D = $StepUpCast if has_node("StepUpCast") else null

## ─── RUNTIME STATE ───────────────────────────────────────────────────────────
var is_diving: bool = false
var dive_cooldown: float = 0.0
var dive_recovery_timer: float = 0.0
var external_velocity: Vector3 = Vector3.ZERO
var _was_on_floor: bool = false
var _coyote_timer: float = 0.0          # Allows jumping just after walking off an edge
const COYOTE_TIME: float = 0.15

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		var peer_id = name.to_int()
		if peer_id > 0:
			set_multiplayer_authority(peer_id)
		
		if not is_multiplayer_authority():
			if has_node("SpringArm3D"):
				$SpringArm3D.queue_free()
			# Disable processing for other players' nodes locally
			set_process(false)
			set_physics_process(false)
			set_process_unhandled_input(false)
			set_process_input(false)
			return
		
		# Set up dynamic MultiplayerSynchronizer
		var sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		var config = SceneReplicationConfig.new()
		config.add_property(^".:global_position")
		config.add_property(^"Visuals:rotation")
		sync.replication_config = config
		add_child(sync)
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func setup_username_label(username: String) -> void:
	var label = Label3D.new()
	label.text = username
	label.position = Vector3(0, 2.2, 0)
	label.billboard = StandardMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_render_priority = 1
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 1)
	
	if name.to_int() == multiplayer.get_unique_id() or (name == "Player3D" and not multiplayer.has_multiplayer_peer()):
		label.modulate = Color(0.2, 0.8, 1.0) # Local player highlight
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
	add_child(label)

## ─── MOUSE LOOK ──────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		spring_arm.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70), deg_to_rad(20))

func _input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_lock()

func _toggle_mouse_lock() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── Gravity ──────────────────────────────────────────────────────────────
	if not on_floor:
		velocity.y -= GRAVITY * delta

	# ── Coyote Time (jump grace period after walking off a ledge) ─────────────
	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta

	# ── Jump ─────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept") and _coyote_timer > 0.0 and not is_diving:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0  # consume coyote time

	# ── Dive ─────────────────────────────────────────────────────────────────
	if dive_cooldown > 0.0:
		dive_cooldown -= delta
	if dive_recovery_timer > 0.0:
		dive_recovery_timer -= delta
		if dive_recovery_timer <= 0.0:
			is_diving = false

	if Input.is_action_just_pressed("ui_select") and not on_floor and not is_diving and dive_cooldown <= 0.0:
		is_diving = true
		dive_cooldown = 1.0
		dive_recovery_timer = 0.4
		var forward := -visuals.global_transform.basis.z
		velocity = forward * DIVE_FORCE
		velocity.y = -DIVE_FORCE * 0.5

	# ── Horizontal Movement & Input ──────────────────────────────────────────
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cam_y := spring_arm.global_transform.basis.get_euler().y
	var direction := (Vector3(input_dir.x, 0.0, input_dir.y)).rotated(Vector3.UP, cam_y).normalized()

	if direction and not is_diving:
		var accel = 35.0 if on_floor else 15.0
		velocity.x = move_toward(velocity.x, direction.x * SPEED, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, accel * delta)

		# ── STEP UP LOGIC ─────────────────────────────────────────────────────
		# Only step up on actual walls/hurdles, not gently sloped terrain.
		if on_floor and velocity.y <= 0.0 and step_up_cast and step_up_cast.is_colliding():
			var hit_normal = step_up_cast.get_collision_normal(0)
			# If the normal Y is low, it's a steep wall. If it's close to 1.0, it's a walkable slope.
			if hit_normal.y < 0.7:
				velocity.y = 4.0
		# ─────────────────────────────────────────────────────────────────────

		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(-direction.x, -direction.z), 15.0 * delta)
	elif not is_diving:
		var decel = 25.0 if on_floor else 8.0
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# ── Out of Bounds Reset ───────────────────────────────────────────────────
	if global_position.y < -25.0:
		global_position = Vector3.ZERO
		velocity = Vector3.ZERO

	_was_on_floor = on_floor
	
	# Apply external velocity temporarily for the slide
	velocity += external_velocity
	move_and_slide()
	velocity -= external_velocity
	
	# Reset it so environment must apply it every frame
	external_velocity = Vector3.ZERO
