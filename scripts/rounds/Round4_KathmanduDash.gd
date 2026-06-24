extends BaseRound

var player_hit_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	round_name = "ROUND 4: KATHMANDU DASH"
	
	# Clear existing map geometry
	var map_geo = get_node_or_null("MapGeometry")
	if map_geo:
		for child in map_geo.get_children():
			child.queue_free()
	else:
		map_geo = Node3D.new()
		map_geo.name = "MapGeometry"
		add_child(map_geo)
		
	_generate_zone_1_rickshaws(map_geo)
	_generate_zone_2_madals(map_geo)
	_generate_zone_3_prayer_wheels(map_geo)
	_generate_zone_4_finish(map_geo)

func _process(delta: float) -> void:
	super._process(delta)
	if player_hit_cooldown > 0.0:
		player_hit_cooldown -= delta

# --- ZONE 1: RICKSHAW RUSH ---
func _generate_zone_1_rickshaws(parent: Node3D) -> void:
	# Floor Z: 0 to -40
	var floor = CSGBox3D.new()
	floor.size = Vector3(16.0, 1.0, 40.0)
	floor.position = Vector3(0, -0.5, -20.0)
	floor.use_collision = true
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.25)
	floor.material_override = mat
	parent.add_child(floor)
	
	# Spawn Rickshaws
	var z_positions = [-10.0, -20.0, -30.0]
	for i in range(z_positions.size()):
		var z = z_positions[i]
		# Alternate starting directions
		var start_x = 10.0 if i % 2 == 0 else -10.0
		var end_x = -10.0 if i % 2 == 0 else 10.0
		_spawn_rickshaw(parent, z, start_x, end_x)

func _spawn_rickshaw(parent: Node3D, z_pos: float, start_x: float, end_x: float) -> void:
	var rickshaw = AnimatableBody3D.new()
	rickshaw.position = Vector3(start_x, 1.0, z_pos)
	
	var mesh = CSGBox3D.new()
	mesh.size = Vector3(4.0, 2.0, 2.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mesh.material_override = mat
	rickshaw.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 2.0, 2.0)
	col.shape = box
	rickshaw.add_child(col)
	
	var hit_area = Area3D.new()
	hit_area.collision_mask = 2 # Player mask
	var hit_col = CollisionShape3D.new()
	var hit_box = BoxShape3D.new()
	hit_box.size = Vector3(4.2, 2.2, 2.2)
	hit_col.shape = hit_box
	hit_area.add_child(hit_col)
	hit_area.body_entered.connect(_on_rickshaw_hit)
	rickshaw.add_child(hit_area)
	
	parent.add_child(rickshaw)
	
	var tween = create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var duration = randf_range(1.5, 2.5)
	tween.tween_property(rickshaw, "position:x", end_x, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rickshaw, "position:x", start_x, duration).set_trans(Tween.TRANS_SINE)

func _on_rickshaw_hit(body: Node3D) -> void:
	if body is CharacterBody3D and player_hit_cooldown <= 0.0:
		player_hit_cooldown = 1.0
		# Apply knockback towards start
		var push_dir = (body.global_position - Vector3(0, body.global_position.y, body.global_position.z)).normalized()
		push_dir.z = 1.0 
		body.velocity = push_dir.normalized() * 30.0 + Vector3(0, 10.0, 0)

# --- ZONE 2: MADAL BOUNCE ---
func _generate_zone_2_madals(parent: Node3D) -> void:
	# Mud pit Z: -40 to -80
	var mud = CSGBox3D.new()
	mud.size = Vector3(20.0, 1.0, 40.0)
	mud.position = Vector3(0, -5.0, -60.0)
	var mud_mat = StandardMaterial3D.new()
	mud_mat.albedo_color = Color(0.3, 0.2, 0.1) # Brown mud
	mud.material_override = mud_mat
	parent.add_child(mud)
	
	var mud_area = Area3D.new()
	mud_area.position = mud.position
	var mud_col = CollisionShape3D.new()
	var mud_box = BoxShape3D.new()
	mud_box.size = Vector3(20.0, 2.0, 40.0)
	mud_col.shape = mud_box
	mud_area.add_child(mud_col)
	mud_area.body_entered.connect(_on_mud_hit)
	parent.add_child(mud_area)
	
	# Spawn Madals
	var madal_positions = [
		Vector3(0, -2, -45),
		Vector3(-4, -1, -52),
		Vector3(4, -1, -52),
		Vector3(0, 0, -59),
		Vector3(-5, -2, -66),
		Vector3(5, -1, -66),
		Vector3(0, -1, -73)
	]
	
	for pos in madal_positions:
		_spawn_madal(parent, pos)

func _spawn_madal(parent: Node3D, pos: Vector3) -> void:
	var madal = CSGCylinder3D.new()
	madal.radius = 2.5
	madal.height = 1.0
	madal.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	madal.material_override = mat
	madal.use_collision = true
	parent.add_child(madal)
	
	# Bounce pad area
	var bounce_area = Area3D.new()
	bounce_area.position = Vector3(0, 0.6, 0)
	var bounce_col = CollisionShape3D.new()
	var bounce_cyl = CylinderShape3D.new()
	bounce_cyl.radius = 2.4
	bounce_cyl.height = 0.5
	bounce_col.shape = bounce_cyl
	bounce_area.add_child(bounce_col)
	bounce_area.body_entered.connect(_on_madal_bounce)
	madal.add_child(bounce_area)

func _on_mud_hit(body: Node3D) -> void:
	if body is CharacterBody3D:
		# Respawn at start of zone 2
		body.global_position = Vector3(0, 2.0, -38.0)
		body.velocity = Vector3.ZERO

func _on_madal_bounce(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.velocity.y = 25.0

# --- ZONE 3: SWINGING PRAYER WHEELS ---
func _generate_zone_3_prayer_wheels(parent: Node3D) -> void:
	# Ramp Z: -80 to -130, Y goes up to 10
	var ramp = CSGBox3D.new()
	ramp.size = Vector3(16.0, 1.0, 52.0)
	ramp.position = Vector3(0, 4.0, -105.0)
	ramp.rotation_degrees = Vector3(-12.0, 0, 0)
	ramp.use_collision = true
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8)
	ramp.material_override = mat
	parent.add_child(ramp)
	
	for z in [-90.0, -105.0, -120.0]:
		_spawn_prayer_wheel(parent, z)

func _spawn_prayer_wheel(parent: Node3D, z_pos: float) -> void:
	var anchor = StaticBody3D.new()
	var y_anchor = 15.0
	anchor.position = Vector3(0, y_anchor, z_pos)
	parent.add_child(anchor)
	
	var wheel = RigidBody3D.new()
	wheel.position = Vector3(0, y_anchor - 6.0, z_pos)
	wheel.mass = 50.0
	
	var mesh = CSGCylinder3D.new()
	mesh.radius = 1.5
	mesh.height = 6.0
	mesh.rotation_degrees = Vector3(90, 0, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.2)
	mesh.material_override = mat
	wheel.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 6.0
	col.shape = cyl
	col.rotation_degrees = Vector3(90, 0, 0)
	wheel.add_child(col)
	parent.add_child(wheel)
	
	var joint = HingeJoint3D.new()
	joint.position = anchor.position
	joint.node_a = anchor.get_path()
	joint.node_b = wheel.get_path()
	joint.rotation_degrees = Vector3(0, 90, 0)
	
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(60))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-60))
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 5.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 100.0)
	parent.add_child(joint)
	
	var hit_area = Area3D.new()
	var hit_col = CollisionShape3D.new()
	hit_col.shape = cyl
	hit_col.rotation_degrees = Vector3(90, 0, 0)
	hit_area.add_child(hit_col)
	hit_area.body_entered.connect(_on_prayer_wheel_hit.bind(wheel))
	wheel.add_child(hit_area)
	
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.autostart = true
	timer.timeout.connect(func():
		var current = joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -current)
	)
	parent.add_child(timer)

func _on_prayer_wheel_hit(body: Node3D, wheel: RigidBody3D) -> void:
	if body is CharacterBody3D and player_hit_cooldown <= 0.0:
		player_hit_cooldown = 1.0
		var push_dir = wheel.linear_velocity.normalized()
		if push_dir.length() < 0.1:
			push_dir = Vector3(1, 0, 0)
		body.velocity = push_dir * 40.0 + Vector3(0, 15.0, 0)

# --- ZONE 4: RING THE BELL ---
func _generate_zone_4_finish(parent: Node3D) -> void:
	# End platform Z: -130 to -150
	var platform = CSGBox3D.new()
	platform.size = Vector3(20.0, 1.0, 20.0)
	platform.position = Vector3(0, 9.5, -140.0)
	platform.use_collision = true
	parent.add_child(platform)
	
	var bell = CSGCylinder3D.new()
	bell.radius = 2.0
	bell.height = 3.0
	bell.position = Vector3(0, 12.0, -140.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0)
	bell.material_override = mat
	parent.add_child(bell)
	
	var audio = AudioStreamPlayer3D.new()
	audio.name = "BellSound"
	var bell_stream = AudioStreamGenerator.new()
	bell_stream.mix_rate = 44100
	bell_stream.buffer_length = 0.5
	audio.stream = bell_stream
	bell.add_child(audio)
	
	if finish_zone:
		finish_zone.global_position = Vector3(0, 11.0, -140.0)
		var box = BoxShape3D.new()
		box.size = Vector3(10.0, 5.0, 10.0)
		if finish_zone.get_child_count() > 0 and finish_zone.get_child(0) is CollisionShape3D:
			finish_zone.get_child(0).shape = box
		
		if not finish_zone.body_entered.is_connected(_on_bell_rung):
			finish_zone.body_entered.connect(_on_bell_rung)

func _on_bell_rung(body: Node3D) -> void:
	if body is CharacterBody3D and not round_ended:
		# Use get_node_or_null with absolute path or relative to map geometry
		var audio = get_node_or_null("MapGeometry/BellSound")
		if not audio:
			# It's actually a child of bell which is a child of map_geo
			# Let's search for it
			var map = get_node_or_null("MapGeometry")
			if map:
				for child in map.get_children():
					if child is CSGCylinder3D: # This is the bell
						for sub in child.get_children():
							if sub is AudioStreamPlayer3D and sub.name == "BellSound":
								sub.play()
								break
