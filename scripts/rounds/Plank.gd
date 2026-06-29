extends RigidBody3D

@export var player_weight: float = 75.0 # Virtual player weight in kg
@export var extra_gravity_multiplier: float = 1.0

var _area: Area3D

func _ready() -> void:
	# Configure RigidBody3D settings
	mass = 80.0
	linear_damp = 1.5
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 8
	
	# Programmatically spawn an Area3D to detect players standing on the plank
	_area = Area3D.new()
	add_child(_area)
	
	# Setup collision mask to only detect Layer 2 (Players / Yetis)
	_area.collision_mask = 2
	_area.collision_layer = 0
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	# The plank dimensions are (4.0, 0.4, 1.5)
	# The area should sit slightly above the plank to detect when player is standing on it
	box_shape.size = Vector3(3.8, 0.5, 1.4)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.45, 0.0) # Elevated slightly
	
	_area.add_child(col_shape)

func _physics_process(delta: float) -> void:
	# Only run physics forces on the server (authority)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	# Apply downward force for each player inside the area
	var overlapping_bodies = _area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is CharacterBody3D:
			# Calculate offset relative to plank center
			# This is what causes the plank to tilt dynamically depending on where the player stands!
			var local_offset = body.global_position - global_position
			local_offset.y = 0.0 # Keep force on the flat surface plane
			
			# Downward weight force: mass * gravity
			var g = 28.0
			if "GRAVITY" in body:
				g = body.GRAVITY
			
			var force_magnitude = player_weight * g * extra_gravity_multiplier
			var force_vector = Vector3.DOWN * force_magnitude
			
			# Apply the force at the player's position relative to the plank center
			apply_force(force_vector, local_offset)
			
			# Also apply a slight lateral friction force if the player is running
			if body.velocity.length_squared() > 0.1:
				var push_force = body.velocity * player_weight * 0.1
				apply_force(push_force, local_offset)
