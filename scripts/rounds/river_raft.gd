extends AnimatableBody3D

enum State { FLOATING, SINKING, RESETTING, RISING }
var current_state: State = State.FLOATING

var time_passed: float = 0.0
var _base_y: float = 0.0
var _state_time: float = 0.0

@export var bob_intensity: float = 0.5
@export var wave_speed: float = 3.0
@export var sinking_threshold: float = 0.90 # progress_ratio to start sinking
@export var sink_depth: float = 4.0 # how deep the raft sinks
@export var sink_speed: float = 4.0 # speed of sinking translation
@export var rise_speed: float = 2.0 # speed of rising translation
@export var reset_hold_time: float = 1.0 # time spent at start before rising

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var parent_follower: PathFollow3D = get_parent() as PathFollow3D

func _ready() -> void:
	_base_y = position.y
	current_state = State.FLOATING

func _physics_process(delta: float) -> void:
	time_passed += delta
	_state_time += delta
	
	if not parent_follower:
		parent_follower = get_parent() as PathFollow3D
		if not parent_follower:
			return

	# Apply continuous bobbing and tilting (always active visually except when resetting)
	var vertical_bob := sin(time_passed * wave_speed) * bob_intensity
	var pitch_tilt  := cos(time_passed * wave_speed * 0.8) * (bob_intensity * 0.15)
	var roll_tilt   := sin(time_passed * wave_speed * 1.2) * (bob_intensity * 0.08)

	match current_state:
		State.FLOATING:
			# Normal floating behavior
			position.y = lerp(position.y, _base_y + vertical_bob, 10.0 * delta)
			rotation.x = lerp_angle(rotation.x, pitch_tilt, 5.0 * delta)
			rotation.z = lerp_angle(rotation.z, roll_tilt, 5.0 * delta)
			
			# Enable collision and ensure visible
			collision_shape.disabled = false
			visible = true
			
			# Enable parent movement
			if "is_active" in parent_follower:
				parent_follower.is_active = true
			
			# Transition to sinking when near the end of path
			if parent_follower.progress_ratio >= sinking_threshold:
				current_state = State.SINKING
				_state_time = 0.0
				
		State.SINKING:
			# Disable player collisions immediately so they fall into water
			collision_shape.disabled = true
			
			# Move the raft downwards below water plane
			position.y = move_toward(position.y, _base_y - sink_depth, sink_speed * delta)
			# Reduce bobbing/tilt to look like it's heavy and sinking
			rotation.x = lerp_angle(rotation.x, 0.0, 5.0 * delta)
			rotation.z = lerp_angle(rotation.z, 0.0, 5.0 * delta)
			
			# Wait until it reaches full sink depth or the end of path
			if position.y <= (_base_y - sink_depth + 0.1) or parent_follower.progress_ratio >= 0.99:
				current_state = State.RESETTING
				_state_time = 0.0
				
		State.RESETTING:
			# Teleport parent to start of path and pause movement
			if "is_active" in parent_follower:
				parent_follower.is_active = false
			parent_follower.progress_ratio = 0.0
			
			# Make invisible and keep collision disabled
			visible = false
			collision_shape.disabled = true
			position.y = _base_y - sink_depth
			
			if _state_time >= reset_hold_time:
				current_state = State.RISING
				_state_time = 0.0
				visible = true
				
		State.RISING:
			# Enable parent movement (start moving forward from start)
			if "is_active" in parent_follower:
				parent_follower.is_active = true
				
			# Translate upward from sink depth to base Y
			position.y = move_toward(position.y, _base_y + vertical_bob, rise_speed * delta)
			
			# Once close to base Y, enable collision and transition to FLOATING
			if position.y >= (_base_y - 0.5):
				collision_shape.disabled = false
				if position.y >= (_base_y - 0.1):
					current_state = State.FLOATING
					_state_time = 0.0
