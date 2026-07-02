extends CharacterBody3D

## ─── EXPORTED TUNABLES ───────────────────────────────────────────────────────
@export var SPEED: float = 9.0
@export var JUMP_VELOCITY: float = 14.0      # Increased: enough to clear Round 1 hurdles
@export var DIVE_FORCE: float = 12.0
@export var MOUSE_SENSITIVITY: float = 0.003
@export var GRAVITY: float = 28.0           # Slightly higher gravity for snappy feel
@export var fall_threshold: float = -25.0   # Platform lowest threshold

## ─── EMOTE TUNABLES ──────────────────────────────────────────────────────────
## Minimum seconds between emote triggers to prevent spam.
@export var EMOTE_COOLDOWN: float = 0.8

## ─── FOOTSTEP TUNABLES ───────────────────────────────────────────────────────
## Seconds between footstep audio events while moving on the ground.
@export var FOOTSTEP_INTERVAL: float = 0.35

## ─── NODE REFERENCES ─────────────────────────────────────────────────────────
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var visuals: Node3D = $Visuals
@onready var step_up_cast: ShapeCast3D = $StepUpCast if has_node("StepUpCast") else null
## AudioStreamPlayer3D for footstep SFX — add "FootstepAudio" node to Player3D.tscn.
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio if has_node("FootstepAudio") else null

## ─── RUNTIME STATE ───────────────────────────────────────────────────────────
var is_diving: bool = false
var dive_cooldown: float = 0.0
var is_ragdoll: bool = false
var ragdoll_timer: float = 0.0
var dive_recovery_timer: float = 0.0
var external_velocity: Vector3 = Vector3.ZERO
var _was_on_floor: bool = false
var _coyote_timer: float = 0.0          # Allows jumping just after walking off an edge
const COYOTE_TIME: float = 0.15

## ─── SLIPPERY SURFACE STATE ──────────────────────────────────────────────────
## Set by SlipperyZone.gd when the player steps onto wet river rocks.
## friction_multiplier scales down deceleration: 1.0 = normal, 0.2 = very slippery.
var _is_slippery: bool = false
var _friction_multiplier: float = 1.0

## ─── WIND TUNNEL STATE ───────────────────────────────────────────────────────
## Set by WindTunnel.gd each physics frame while the player is inside the zone.
## _in_wind_tunnel gates the built-in gravity accumulation so the tunnel's
## external_velocity push is the sole vertical force.
var _in_wind_tunnel: bool = false
## The push vector injected by WindTunnel this frame (cleared each tick).
var _wind_push: Vector3 = Vector3.ZERO

## ─── EMOTE STATE ─────────────────────────────────────────────────────────────
## Tracks time since the last emote so rapid triggers are ignored.
var _emote_cooldown_timer: float = 0.0
## Maps input action names to animation names on $Visuals/AnimationPlayer.
## The AnimationPlayer must have animations named exactly as the values here.
const EMOTE_MAP: Dictionary = {
	"emote_wave":    "wave",
	"emote_dance":   "dance_dhime",
	"emote_namaste": "namaste",
	"emote_roar":    "roar",
}

## ─── FOOTSTEP STATE ──────────────────────────────────────────────────────────
## Current surface type — set by Area3D trigger nodes in each round scene.
## Supported values: "snow", "stone", "wood", "metal".
var surface_type: String = "snow"
## Countdown timer controlling footstep audio cadence.
var _footstep_timer: float = 0.0
## Preloaded AudioStreams keyed by surface_type.
## Populate these paths once you have .ogg assets; nulls are safely skipped.
var _footstep_streams: Dictionary = {
	"snow":   null,   # e.g. preload("res://assets/audio/sfx/footstep_snow.ogg")
	"stone":  null,   # e.g. preload("res://assets/audio/sfx/footstep_stone.ogg")
	"wood":   null,   # e.g. preload("res://assets/audio/sfx/footstep_wood.ogg")
	"metal":  null,   # e.g. preload("res://assets/audio/sfx/footstep_metal.ogg")
}

## ─── SPEED BOOST STATE ───────────────────────────────────────────────────────
## Tracks the base SPEED before any boost so it can be restored exactly.
var _base_speed: float = 0.0
## Remaining seconds of the active speed boost (0.0 = no boost active).
var _speed_boost_timer: float = 0.0

## ─── FALL DETECTION STATE ────────────────────────────────────────────────────
## Accumulates seconds spent continuously falling faster than -20 m/s.
var _fast_fall_timer: float = 0.0
## Threshold velocity.y below which fall-detection begins counting.
const FALL_VELOCITY_THRESHOLD: float = -20.0
## Seconds of continuous fast-fall before player_fell is emitted.
const FALL_EMIT_DELAY: float = 0.3

## ─── SIGNALS ─────────────────────────────────────────────────────────────────
## Emitted once when the player has been falling faster than FALL_VELOCITY_THRESHOLD
## for longer than FALL_EMIT_DELAY seconds.  Resets after the player lands.
signal player_fell

func _ready() -> void:
	# Cache base speed for the boost/restore system.
	_base_speed = SPEED

	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		var peer_id = name.to_int()
		if peer_id > 0:
			set_multiplayer_authority(peer_id)
		
		# Set up dynamic MultiplayerSynchronizer on ALL peers so they can receive updates
		var sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		var config = SceneReplicationConfig.new()
		config.add_property(^".:global_position")
		config.add_property(^".:velocity")
		config.add_property(^"Visuals:rotation")
		sync.replication_config = config
		add_child(sync)
		
		if not is_multiplayer_authority():
			if has_node("SpringArm3D"):
				$SpringArm3D.queue_free()
			# Disable processing for other players' nodes locally
			set_process(false)
			set_physics_process(false)
			set_process_unhandled_input(false)
			set_process_input(false)
			return
			
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

## ─── PROCESS (non-physics per-frame logic) ───────────────────────────────────
func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	# ── Emote cooldown tick ───────────────────────────────────────────────────
	if _emote_cooldown_timer > 0.0:
		_emote_cooldown_timer -= delta

	# ── Emote input polling ───────────────────────────────────────────────────
	# Emotes are blocked while ragdolling or diving (they would look wrong).
	if not is_ragdoll and not is_diving and _emote_cooldown_timer <= 0.0:
		for action: String in EMOTE_MAP.keys():
			if Input.is_action_just_pressed(action):
				var anim_name: String = EMOTE_MAP[action]
				_trigger_emote(anim_name)
				break  # only one emote per frame

	# ── Speed boost timer ─────────────────────────────────────────────────────
	# Counts down the remaining boost duration and restores base speed on expiry.
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_boost_timer = 0.0
			SPEED = _base_speed  # restore exact pre-boost value

## ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── Gravity ──────────────────────────────────────────────────────────────
	# Gravity is suppressed while inside a WindTunnel zone so the tunnel's
	# upward push (delivered via external_velocity) is the sole vertical force.
	if not on_floor and not _in_wind_tunnel:
		var applied_gravity = GRAVITY
		var area_gravity = get_gravity().length()
		if area_gravity < 9.0:
			applied_gravity = GRAVITY * (area_gravity / 9.8)
		velocity.y -= applied_gravity * delta

	# ── Coyote Time (jump grace period after walking off a ledge) ─────────────
	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta

	# ── Jump ─────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept") and _coyote_timer > 0.0 and not is_diving and not is_ragdoll:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0  # consume coyote time

	# ── Dive ─────────────────────────────────────────────────────────────────
	if dive_cooldown > 0.0:
		dive_cooldown -= delta
	if dive_recovery_timer > 0.0:
		dive_recovery_timer -= delta
		if dive_recovery_timer <= 0.0:
			is_diving = false

	# ── Ragdoll ──────────────────────────────────────────────────────────────
	if ragdoll_timer > 0.0:
		ragdoll_timer -= delta
		if ragdoll_timer <= 0.0:
			is_ragdoll = false

	if Input.is_action_just_pressed("ui_select") and not on_floor and not is_diving and dive_cooldown <= 0.0 and not is_ragdoll:
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

	if direction and not is_diving and not is_ragdoll:
		# On a slippery surface, acceleration is also reduced slightly to model
		# the difficulty of pushing off with reduced grip.
		var base_accel := 35.0 if on_floor else 15.0
		var accel: float = base_accel * lerp(0.5, 1.0, _friction_multiplier)
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
	elif not is_diving and not is_ragdoll:
		# ── Slippery Deceleration ─────────────────────────────────────────────
		# On normal ground, decel = 25.0. On wet rocks (friction_multiplier=0.2),
		# the effective decel becomes 25 * 0.2 = 5.0, causing the Yeti to glide.
		var base_decel := 25.0 if on_floor else 8.0
		var decel := base_decel * _friction_multiplier
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# ── Fall Detection ────────────────────────────────────────────────────────
	# Accumulates time spent in a fast downward fall; emits player_fell once
	# the threshold duration is exceeded.  Resets the moment we land.
	if velocity.y < FALL_VELOCITY_THRESHOLD and not on_floor:
		_fast_fall_timer += delta
		if _fast_fall_timer >= FALL_EMIT_DELAY:
			# Emit only once per continuous fall — reset so it fires again only
			# after the player lands and falls a second time.
			_fast_fall_timer = -999.0
			player_fell.emit()
	elif on_floor:
		_fast_fall_timer = 0.0  # landed — reset so next fall can trigger again

	# ── Footstep Audio ────────────────────────────────────────────────────────
	# Only plays while the player is on the ground and actually moving laterally.
	# Uses a fixed interval timer so cadence doesn't vary with frame-rate.
	var xz_speed: float = Vector2(velocity.x, velocity.z).length()
	if on_floor and xz_speed > 1.0 and not is_ragdoll:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			_play_footstep()
	else:
		# Reset cadence when standing still or airborne so the next step fires
		# immediately rather than waiting for a partially-elapsed interval.
		_footstep_timer = 0.0

	# ── Out of Bounds Reset ───────────────────────────────────────────────────
	if global_position.y < fall_threshold:
		var parent = get_parent()
		if parent and parent.has_method("_on_kill_zone_body_entered"):
			parent._on_kill_zone_body_entered(self)
		else:
			# Fallback if no parent or method found
			global_position = Vector3.ZERO
			velocity = Vector3.ZERO

	_was_on_floor = on_floor
	
	# ── Apply external forces (slippery zone, wind tunnel, etc.) ─────────────
	# Wind tunnel push is accumulated into external_velocity each frame by
	# WindTunnel.gd via enter_wind_tunnel().  We inject it here, slide, then
	# subtract so the velocity isn't permanently boosted.
	velocity += external_velocity
	move_and_slide()
	velocity -= external_velocity

	# Reset external velocity and wind state so environment re-applies each frame.
	external_velocity = Vector3.ZERO
	_in_wind_tunnel = false  # WindTunnel must call enter_wind_tunnel() every tick
	_wind_push = Vector3.ZERO

## ─── SLIPPERY ZONE API ───────────────────────────────────────────────────────
## Called by SlipperyZone.gd when the player enters a wet/muddy hazard zone.
## factor: [0..1], where 0.0 = pure ice and 1.0 = no effect on friction.
func apply_slippery_effect(factor: float) -> void:
	_is_slippery = true
	# Clamp the factor so a misconfigured zone can't lock movement entirely.
	_friction_multiplier = clamp(factor, 0.05, 1.0)

## Called by SlipperyZone.gd when the player exits the hazard zone.
## Restores full normal friction immediately.
func remove_slippery_effect() -> void:
	_is_slippery = false
	_friction_multiplier = 1.0

## ─── WIND TUNNEL API ─────────────────────────────────────────────────────────
## Called by WindTunnel.gd every physics frame while this body is inside the
## volume.  `push` is a pre-computed Vector3 containing:
##   push.y  = (lift_force * smoothstep_ramp) * delta   ← vertical anti-gravity
##   push.xz = drag correction to cap lateral speed      ← air resistance
##
## Design note: because external_velocity is zeroed at the END of each
## _physics_process, this method must be called again every frame to sustain
## the floating effect.  That is intentional — no accumulation can occur.
func enter_wind_tunnel(push: Vector3) -> void:
	_in_wind_tunnel = true
	_wind_push      = push
	external_velocity += push  # merged into the existing external_velocity system

## Called by WindTunnel.gd when the drain phase completes (lift fully drained).
## No cleanup is needed here because _in_wind_tunnel auto-resets each tick,
## but this hook is available for VFX / audio systems that need an event.
func exit_wind_tunnel() -> void:
	_in_wind_tunnel = false
	_wind_push      = Vector3.ZERO

## ─── EMOTE API ───────────────────────────────────────────────────────────────
## Plays the named emote animation locally and replicates it to all peers.
## anim_name must match an AnimationPlayer track on $Visuals/AnimationPlayer.
func _trigger_emote(anim_name: String) -> void:
	_emote_cooldown_timer = EMOTE_COOLDOWN
	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		rpc("play_emote_rpc", anim_name)
	else:
		play_emote_rpc(anim_name)

## RPC that plays the emote animation on every peer's copy of this player.
## Declared "unreliable" — a dropped emote packet is not game-critical.
@rpc("any_peer", "call_local", "unreliable")
func play_emote_rpc(anim_name: String) -> void:
	if not visuals:
		return
	var anim_player: AnimationPlayer = visuals.get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation(anim_name):
		# Stop any currently playing emote before starting a new one.
		anim_player.stop()
		anim_player.play(anim_name)

## ─── FOOTSTEP AUDIO API ──────────────────────────────────────────────────────
## Selects and plays the correct footstep sound for the current surface_type.
## If no stream is loaded for the surface (null entry), the call is a no-op.
func _play_footstep() -> void:
	if not footstep_audio:
		return
	var stream: AudioStream = _footstep_streams.get(surface_type, null)
	if stream == null:
		return  # asset not yet loaded — silent but not an error
	if footstep_audio.playing:
		footstep_audio.stop()
	footstep_audio.stream = stream
	footstep_audio.play()

## Called by surface-type Area3D trigger nodes placed in each round scene.
## body_entered: set_surface_type("stone")
## body_exited:  set_surface_type("snow")  (default back to snow)
func set_surface_type(new_type: String) -> void:
	surface_type = new_type

## ─── SPEED BOOST API ─────────────────────────────────────────────────────────
## Temporarily multiplies SPEED by `multiplier` for `duration` seconds.
## Non-stackable: calling again while a boost is active replaces the existing
## timer (duration resets) but does NOT compound the multiplier — SPEED is
## always compared against _base_speed.
func apply_speed_boost(multiplier: float, duration: float) -> void:
	# Always restore base speed before applying so stacking cannot occur.
	SPEED = _base_speed * multiplier
	_speed_boost_timer = duration

## ─── RAGDOLL API ─────────────────────────────────────────────────────────────
func trigger_yeti_ragdoll(force: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "apply_ragdoll_rpc", force)
	else:
		apply_ragdoll_rpc(force)

@rpc("any_peer", "call_local", "reliable")
func apply_ragdoll_rpc(force: Vector3) -> void:
	if is_multiplayer_authority():
		is_ragdoll = true
		ragdoll_timer = 2.0
		velocity = force
		is_diving = false
