extends Node3D

@export var plank_scene: PackedScene # Drag your plank.tscn here in the inspector
@export var anchor_start: NodePath
@export var anchor_end: NodePath
@export var number_of_planks: int = 10
@export var joint_offset_distance: float = 1.8 # Spacing from center for the left/right joint anchors

func _ready():
	# Only generate bridge on server, or if in single player
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		call_deferred("generate_bridge")

func generate_bridge():
	var start_node = get_node_or_null(anchor_start)
	var end_node = get_node_or_null(anchor_end)
	if not start_node or not end_node: return
	
	var previous_body = start_node
	var start_pos = start_node.global_position
	var end_pos = end_node.global_position
	
	# Calculate the direction the bridge should point
	var direction = (end_pos - start_pos).normalized()
	var right_dir = direction.cross(Vector3.UP).normalized()
	var offset = right_dir * joint_offset_distance
	
	for i in range(number_of_planks):
		# 1. Spawn the Plank
		var new_plank = plank_scene.instantiate()
		add_child(new_plank)
		
		# Position the plank evenly along the line
		var step_distance = (float(i + 1) / (number_of_planks + 1)) * start_pos.distance_to(end_pos)
		new_plank.global_position = start_pos + (direction * step_distance)
		
		# Configure plank physics to be stable under multiple players
		if new_plank is RigidBody3D:
			new_plank.mass = 80.0
			new_plank.linear_damp = 1.5
			new_plank.angular_damp = 3.0
		
		# Add synchronizer for planks so clients see the bridge physics!
		var sync = MultiplayerSynchronizer.new()
		var config = SceneReplicationConfig.new()
		config.add_property(^".:position")
		config.add_property(^".:rotation")
		sync.replication_config = config
		new_plank.add_child(sync)
		
		# 2. Spawn TWO Joints to connect it to the previous object
		var mid_pos = previous_body.global_position.lerp(new_plank.global_position, 0.5)
		_create_joint(previous_body, new_plank, mid_pos - offset)
		_create_joint(previous_body, new_plank, mid_pos + offset)
		
		# Set up for the next loop
		previous_body = new_plank
		
	# 3. Connect the final plank to the end anchor
	var final_mid_pos = previous_body.global_position.lerp(end_node.global_position, 0.5)
	_create_joint(previous_body, end_node, final_mid_pos - offset)
	_create_joint(previous_body, end_node, final_mid_pos + offset)

func _create_joint(body_a: Node3D, body_b: Node3D, global_pos: Vector3) -> Generic6DOFJoint3D:
	var joint = Generic6DOFJoint3D.new()
	add_child(joint)
	joint.global_position = global_pos
	
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	
	# Lock linear axes (to act as tight ropes)
	joint.set("linear_limit_x/enabled", true)
	joint.set("linear_limit_y/enabled", true)
	joint.set("linear_limit_z/enabled", true)
	
	# Configure angular limits (pitch/yaw/roll)
	joint.set("angular_limit_x/enabled", true)
	joint.set("angular_limit_x/lower_angle", deg_to_rad(-20))
	joint.set("angular_limit_x/upper_angle", deg_to_rad(20))
	
	joint.set("angular_limit_y/enabled", true)
	joint.set("angular_limit_y/lower_angle", deg_to_rad(-5))
	joint.set("angular_limit_y/upper_angle", deg_to_rad(5))
	
	joint.set("angular_limit_z/enabled", true)
	joint.set("angular_limit_z/lower_angle", deg_to_rad(-10))
	joint.set("angular_limit_z/upper_angle", deg_to_rad(10))
	
	# Enable springs on pitch and roll to pull the bridge back to equilibrium
	joint.set("angular_spring_x/enabled", true)
	joint.set("angular_spring_x/stiffness", 40.0)
	joint.set("angular_spring_x/damping", 5.0)
	
	joint.set("angular_spring_z/enabled", true)
	joint.set("angular_spring_z/stiffness", 40.0)
	joint.set("angular_spring_z/damping", 5.0)
	
	return joint

