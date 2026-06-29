## WindTunnel.gd
## Attach to an Area3D node in the scene (e.g. the "WindTunnel" Area3D in
## Round3_TrishuliCrossing.tscn).
##
## Physics design contract  (Jolt Physics / Godot 4.6)
## ─────────────────────────────────────────────────────────────────────────────
##  Player3D._physics_process does:
##      velocity += external_velocity   ← before move_and_slide
##      move_and_slide()
##      velocity -= external_velocity   ← after  move_and_slide
##      external_velocity = Vector3.ZERO
##
##  Because external_velocity is zeroed after every tick, this script must
##  call body.enter_wind_tunnel() every _physics_process frame for the player
##  to keep floating.  That is intentional — it prevents runaway accumulation.
## ─────────────────────────────────────────────────────────────────────────────
##
## Anti-tunneling notes (Jolt)
## ─────────────────────────────────────────────────────────────────────────────
##  • CharacterBody3D with move_and_slide() already uses Jolt's CCD — no
##    extra setup needed for the player itself.
##  • Spinning paddle-wheel RigidBody3Ds:
##      - Set contact_monitor = true,  max_contacts_reported >= 4
##      - Keep angular_velocity magnitude < ~15 rad/s at 60 Hz physics
##      - Set their collision layer to layer 1 (environment) and mask to
##        include layer 2 (player) so Jolt pairs them correctly.
##  • Player CollisionShape3D capsule radius must be >= 0.3 m so Jolt never
##    loses the contact normal between ticks.

class_name WindTunnel
extends Area3D

# ─── EXPORTED TUNABLES ────────────────────────────────────────────────────────

## Upward push per second.  Set >= player GRAVITY (28) to fully suspend.
## 30 gives a slow upward drift; 28 = neutral buoyancy.
@export var lift_force: float = 30.0

## Seconds for lift to ramp from 0 → full after body enters the volume.
## The S-curve ramp prevents the entry velocity spike that causes jitter.
@export var lift_ramp_time: float = 0.35

## Seconds for lift to drain from full → 0 after the body exits the volume.
## This is what makes the gravity re-entry seamless (no snapping).
@export var exit_drain_time: float = 0.55

## Horizontal air drag coefficient inside the tunnel.
## Prevents the player from building up runaway lateral speed that could
## clip them through a spinning paddle wheel.
@export var air_drag: float = 4.0

## Hard cap on horizontal speed while floating (m/s).
@export var max_air_speed: float = 6.5

# ─── RUNTIME STATE ────────────────────────────────────────────────────────────

## body → ramp_t (float 0..1):  players actively inside the volume
var _players_inside: Dictionary = {}

## body → drain_t (float 1..0):  players who just exited, draining their lift
var _players_exiting: Dictionary = {}

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Layer 2 = Player / AI_Yeti in this project.  Adjust if your layers differ.
	collision_mask = 2

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ─── PHYSICS TICK ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# ── Active players: ramp lift up ────────────────────────────────────────
	for body: Node3D in _players_inside.keys():
		if not is_instance_valid(body):
			_players_inside.erase(body)
			continue

		var ramp_t: float = _players_inside[body]
		ramp_t = minf(ramp_t + delta / lift_ramp_time, 1.0)
		_players_inside[body] = ramp_t

		# smoothstep gives an S-curve: slow start, full middle, slow end.
		# This removes the hard velocity spike at entry.
		var effective_lift: float = lift_force * smoothstep(0.0, 1.0, ramp_t)
		_apply_wind_to(body, effective_lift, delta)

	# ── Exiting players: drain lift smoothly to zero ─────────────────────────
	var done: Array[Node3D] = []
	for body: Node3D in _players_exiting.keys():
		if not is_instance_valid(body):
			done.append(body)
			continue

		var drain_t: float = _players_exiting[body]
		drain_t = maxf(drain_t - delta / exit_drain_time, 0.0)
		_players_exiting[body] = drain_t

		if drain_t <= 0.0:
			_clear_wind_state(body)
			done.append(body)
		else:
			var fade_lift: float = lift_force * smoothstep(0.0, 1.0, drain_t)
			_apply_wind_to(body, fade_lift, delta)

	for body in done:
		_players_exiting.erase(body)

# ─── INTERNAL HELPERS ─────────────────────────────────────────────────────────

## Pushes the computed wind vector into the player's external_velocity slot.
## Because Player3D zeros external_velocity after every move_and_slide(), this
## must run every physics frame.  No accumulation occurs.
func _apply_wind_to(body: Node3D, effective_lift: float, delta: float) -> void:
	if not body.has_method("enter_wind_tunnel"):
		return

	# ── Vertical: apply displacement push ──────────────────────────────────
	var push := Vector3.ZERO
	push.y = effective_lift * delta

	# ── Vertical Damping: Cushion entries and stabilize hovering ──────────
	# Damp persistent velocity.y towards a target hover ascent speed (e.g., 1.5 m/s).
	# This cushions high-velocity entries (jumps/falls) and prevents runaway launches.
	var target_vertical_velocity := 1.5
	var v_damping_coeff := 8.0
	if "velocity" in body:
		body.velocity.y = move_toward(body.velocity.y, target_vertical_velocity, v_damping_coeff * delta)

	# ── Horizontal drag ──────────────────────────────────────────────────────
	# We do NOT zero horizontal velocity — the player keeps WASD steering.
	# We apply gentle drag so lateral speed can't grow past max_air_speed,
	# which prevents tunneling through thin rotating obstacles.
	var h_vel := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if h_vel.length_squared() > 0.001:
		var drag_reduction: Vector3 = -h_vel * air_drag * delta
		var clamped_h: Vector3 = h_vel + drag_reduction
		if clamped_h.length() > max_air_speed:
			clamped_h = clamped_h.normalized() * max_air_speed
		push.x = clamped_h.x - h_vel.x
		push.z = clamped_h.z - h_vel.z

	body.enter_wind_tunnel(push)

func _clear_wind_state(body: Node3D) -> void:
	if body.has_method("exit_wind_tunnel"):
		body.exit_wind_tunnel()

# ─── SIGNAL HANDLERS ─────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if not (body.is_in_group("Player") or body.is_in_group("AI_Yeti")):
		return
	if not body.has_method("enter_wind_tunnel"):
		return

	# If still in drain phase (re-entered before drain finished),
	# carry the current drain_t forward as the new ramp_t so there's no pop.
	var carry_t: float = 0.0
	if _players_exiting.has(body):
		carry_t = _players_exiting[body]
		_players_exiting.erase(body)

	_players_inside[body] = carry_t

func _on_body_exited(body: Node3D) -> void:
	if not _players_inside.has(body):
		return

	# Transfer to drain dict starting from the current ramp_t (usually 1.0),
	# so the drain starts from full lift, not from zero.
	var current_t: float = _players_inside[body]
	_players_inside.erase(body)
	_players_exiting[body] = current_t
