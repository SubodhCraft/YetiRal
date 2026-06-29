extends Node3D

@export var boulder_scene: PackedScene
@export var min_spawn_time: float = 3.0
@export var max_spawn_time: float = 7.0

var spawn_timer: Timer

func _ready():
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		setup_spawn_timer()

func setup_spawn_timer():
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_timer_timeout)
	start_random_timer()

func start_random_timer():
	spawn_timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.start()

func _on_timer_timeout():
	spawn_boulder()
	start_random_timer()

func spawn_boulder():
	if not boulder_scene: return
	var new_rock = boulder_scene.instantiate()
	
	# Add to this spawner's node to keep hierarchy clean and avoid a one-frame position glitch
	add_child(new_rock)
	new_rock.global_position = global_position
	
	# Apply an initial downward push and a strong rolling angular velocity (torque)
	var random_push = Vector3(randf_range(-3.0, 3.0), -4.0, randf_range(-3.0, 3.0))
	new_rock.linear_velocity = random_push
	
	# Dokos roll down along the narrow pathways (aligned along the Z axis).
	# Rotational velocity around X axis induces forward roll, Y and Z add realistic instability.
	var roll_torque = Vector3(randf_range(15.0, 25.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	new_rock.angular_velocity = roll_torque


