extends BaseRound

## ─── MEMBER VARIABLES ────────────────────────────────────────────────────────
var player_hit_cooldown: float = 0.0
var _rng = RandomNumberGenerator.new()

var _kites: Array[Area3D] = []
var _kite_base_positions: Array[Vector3] = []
var _kite_speeds: Array[float] = [2.0, 2.5, 2.2]
var _kite_amplitudes: Array[float] = [3.5, 4.0, 3.8]

var _time_elapsed: float = 0.0

func _ready() -> void:
	# Clear checkpoints BEFORE super._ready() so BaseRound doesn't wire them up
	# This prevents continuous mid-map respawn loops
	checkpoints.clear()
	
	super._ready()
	round_name = "ROUND 4: KATHMANDU DASH"
	round_type = RoundType.RACE
	yeti_fact_index = 3
	time_limit = 90.0
	_rng.randomize()
	
	# Clear existing map geometry
	var map_geo = get_node_or_null("MapGeometry")
	if map_geo:
		for child in map_geo.get_children():
			child.queue_free()
	else:
		map_geo = Node3D.new()
		map_geo.name = "MapGeometry"
		add_child(map_geo)
		
	_generate_asan_bazaar(map_geo)

func _generate_asan_bazaar(parent: Node3D) -> void:
	# Materials
	var mat_brick = StandardMaterial3D.new()
	mat_brick.albedo_color = Color(0.55, 0.25, 0.2) # Kathmandu red brick
	mat_brick.roughness = 0.9

	var mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.2, 0.2, 0.22) # Alley cobblestone/dirt

	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.4, 0.2, 0.1)

	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.9, 0.72, 0.08)
	mat_gold.metallic = 0.9
	mat_gold.roughness = 0.2

	var mat_cow = StandardMaterial3D.new()
	mat_cow.albedo_color = Color(0.9, 0.9, 0.95)

	# ── ZONE 1: RICKSHAW GALLI (Narrow Alleyway) ──
	var floor_galli = CSGBox3D.new()
	floor_galli.size = Vector3(8.0, 1.0, 42.0)
	floor_galli.position = Vector3(0.0, -0.5, -20.0)
	floor_galli.use_collision = true
	floor_galli.material_override = mat_asphalt
	parent.add_child(floor_galli)

	# Left wall with 2 alcoves
	var wall_l = CSGBox3D.new()
	wall_l.size = Vector3(2.0, 8.0, 42.0)
	wall_l.position = Vector3(-5.0, 4.0, -20.0)
	wall_l.use_collision = true
	wall_l.material_override = mat_brick
	parent.add_child(wall_l)

	# Alcoves Left
	for alcove_z in [-15.0, -30.0]:
		var alcove = CSGBox3D.new()
		alcove.operation = CSGShape3D.OPERATION_SUBTRACTION
		alcove.size = Vector3(3.0, 5.0, 4.0)
		alcove.position = Vector3(-1.0, -1.5, alcove_z - (-20.0))
		wall_l.add_child(alcove)

	# Right wall with 2 alcoves (staggered)
	var wall_r = CSGBox3D.new()
	wall_r.size = Vector3(2.0, 8.0, 42.0)
	wall_r.position = Vector3(5.0, 4.0, -20.0)
	wall_r.use_collision = true
	wall_r.material_override = mat_brick
	parent.add_child(wall_r)

	# Alcoves Right
	for alcove_z in [-8.0, -23.0]:
		var alcove = CSGBox3D.new()
		alcove.operation = CSGShape3D.OPERATION_SUBTRACTION
		alcove.size = Vector3(3.0, 5.0, 4.0)
		alcove.position = Vector3(1.0, -1.5, alcove_z - (-20.0))
		wall_r.add_child(alcove)

	# Rickshaws patrolling
	var z_positions = [-10.0, -20.0, -32.0, -38.0]
	var colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8), Color(0.8, 0.8, 0.2), Color(0.2, 0.7, 0.3)]
	for i in range(z_positions.size()):
		var start_x = 3.0 if i % 2 == 0 else -3.0
		var end_x = -3.0 if i % 2 == 0 else 3.0
		_spawn_rickshaw(parent, z_positions[i], start_x, end_x, colors[i], _rng.randf_range(1.1, 1.6))

	# ── ZONE 2: STREET VENDOR MAZE ──
	var floor_maze = CSGBox3D.new()
	floor_maze.size = Vector3(12.0, 1.0, 40.0)
	floor_maze.position = Vector3(0.0, -0.5, -60.0)
	floor_maze.use_collision = true
	floor_maze.material_override = mat_asphalt
	parent.add_child(floor_maze)

	# Vendor stalls and Stray Cows forming a maze
	var obstacles_pos = [
		Vector3(-3.0, 0.5, -45.0),
		Vector3(3.0, 0.5, -50.0),
		Vector3(-2.0, 0.5, -56.0),
		Vector3(2.5, 0.5, -62.0),
		Vector3(-3.5, 0.5, -68.0),
		Vector3(3.0, 0.5, -74.0)
	]

	for i in range(obstacles_pos.size()):
		var pos = obstacles_pos[i]
		if i == 1 or i == 4:
			# Spawn Stray Cow
			var cow = StaticBody3D.new()
			cow.position = pos
			parent.add_child(cow)
			
			var c_col = CollisionShape3D.new()
			var c_shape = BoxShape3D.new()
			c_shape.size = Vector3(2.0, 1.5, 1.2)
			c_col.shape = c_shape
			cow.add_child(c_col)
			
			var body_mesh = CSGBox3D.new()
			body_mesh.size = Vector3(2.0, 1.2, 1.0)
			body_mesh.material_override = mat_cow
			cow.add_child(body_mesh)
			
			var patch = CSGBox3D.new()
			patch.size = Vector3(0.5, 0.5, 1.02)
			patch.position = Vector3(0.4, 0.3, 0.0)
			var mat_spot = StandardMaterial3D.new()
			mat_spot.albedo_color = Color(0.1, 0.1, 0.1)
			patch.material_override = mat_spot
			body_mesh.add_child(patch)
			
			var head_mesh = CSGBox3D.new()
			head_mesh.size = Vector3(0.6, 0.6, 0.6)
			head_mesh.position = Vector3(1.1, 0.6, 0.0)
			head_mesh.material_override = mat_cow
			body_mesh.add_child(head_mesh)
		else:
			# Spawn Market Stall
			var stall = StaticBody3D.new()
			stall.position = pos
			parent.add_child(stall)
			
			var s_col = CollisionShape3D.new()
			var s_shape = BoxShape3D.new()
			s_shape.size = Vector3(3.0, 2.0, 2.5)
			s_col.shape = s_shape
			stall.add_child(s_col)
			
			var table = CSGBox3D.new()
			table.size = Vector3(3.0, 1.0, 2.5)
			table.material_override = mat_wood
			stall.add_child(table)
			
			var canopy = CSGBox3D.new()
			canopy.size = Vector3(3.2, 0.2, 2.7)
			canopy.position = Vector3(0.0, 2.2, 0.0)
			var mat_can = StandardMaterial3D.new()
			mat_can.albedo_color = Color(0.8, 0.2, 0.2)
			canopy.material_override = mat_can
			stall.add_child(canopy)
			
			for corner_x in [-1.4, 1.4]:
				for corner_z in [-1.1, 1.1]:
					var pole = CSGCylinder3D.new()
					pole.radius = 0.05
					pole.height = 2.2
					pole.position = Vector3(corner_x, 1.1, corner_z)
					pole.material_override = mat_wood
					stall.add_child(pole)

	# ── ZONE 3: DASHAIN KITES (Rooftop Challenge) ──
	var roof_positions = [
		Vector3(0.0, 3.5, -88.0),
		Vector3(-3.0, 4.5, -98.0),
		Vector3(3.0, 3.5, -108.0),
		Vector3(-2.0, 5.0, -118.0),
		Vector3(0.0, 4.0, -128.0)
	]
	
	for i in range(roof_positions.size()):
		var pos = roof_positions[i]
		var roof = CSGBox3D.new()
		roof.size = Vector3(7.0, 6.0, 7.0)
		roof.position = pos - Vector3(0.0, 3.0, 0.0)
		roof.use_collision = true
		roof.material_override = mat_brick
		parent.add_child(roof)

	# Swooping Dashain Kites (Changas)
	_kites.clear()
	_kite_base_positions.clear()
	var kite_z_positions = [-93.0, -108.0, -123.0]
	var kite_colors = [Color(0.9, 0.2, 0.2), Color(0.2, 0.2, 0.9), Color(0.9, 0.8, 0.1)]
	
	for i in range(kite_z_positions.size()):
		var k_pos = Vector3(0.0, 6.0, kite_z_positions[i])
		
		var kite_area = Area3D.new()
		kite_area.collision_mask = 2
		kite_area.position = k_pos
		parent.add_child(kite_area)
		_kites.append(kite_area)
		_kite_base_positions.append(k_pos)
		
		var k_col = CollisionShape3D.new()
		var k_shape = SphereShape3D.new()
		k_shape.radius = 1.5
		k_col.shape = k_shape
		kite_area.add_child(k_col)
		
		var model = Node3D.new()
		kite_area.add_child(model)
		
		var mat_k = StandardMaterial3D.new()
		mat_k.albedo_color = kite_colors[i]
		mat_k.roughness = 0.5
		
		var plane_a = CSGBox3D.new()
		plane_a.size = Vector3(2.0, 0.05, 2.0)
		plane_a.rotation_degrees = Vector3(45.0, 45.0, 0.0)
		plane_a.material_override = mat_k
		model.add_child(plane_a)
		
		kite_area.body_entered.connect(func(body):
			_on_kite_hit(body, kite_area)
		)

	# ── ZONE 4: GOLDEN TEMPLE FINISH ──
	var finish_platform = CSGBox3D.new()
	finish_platform.size = Vector3(12.0, 8.0, 12.0)
	finish_platform.position = Vector3(0.0, 0.0, -142.0)
	finish_platform.use_collision = true
	finish_platform.material_override = mat_brick
	parent.add_child(finish_platform)

	var stupa_base = CSGBox3D.new()
	stupa_base.size = Vector3(4.0, 3.0, 4.0)
	stupa_base.position = Vector3(0.0, 5.5, -142.0)
	stupa_base.material_override = mat_brick
	parent.add_child(stupa_base)
	
	var stupa_gold = CSGCylinder3D.new()
	stupa_gold.radius = 2.0
	stupa_gold.height = 2.0
	stupa_gold.cone = true
	stupa_gold.position = Vector3(0.0, 8.0, -142.0)
	stupa_gold.material_override = mat_gold
	parent.add_child(stupa_gold)

	var audio = AudioStreamPlayer3D.new()
	audio.name = "BellSound"
	var bell_stream = AudioStreamGenerator.new()
	bell_stream.mix_rate = 44100
	bell_stream.buffer_length = 0.5
	audio.stream = bell_stream
	stupa_gold.add_child(audio)

	_setup_dynamic_checkpoints(parent)

	if finish_zone:
		finish_zone.global_position = Vector3(0.0, 5.5, -142.0)
		var box = BoxShape3D.new()
		box.size = Vector3(10.0, 5.0, 10.0)
		if finish_zone.get_child_count() > 0 and finish_zone.get_child(0) is CollisionShape3D:
			finish_zone.get_child(0).shape = box
		if not finish_zone.body_entered.is_connected(_on_bell_rung):
			finish_zone.body_entered.connect(_on_bell_rung)
			
	if kill_zone:
		kill_zone.global_position = Vector3(0.0, -10.0, -75.0)
		var kz_col = kill_zone.get_node_or_null("CollisionShape3D")
		if kz_col and kz_col.shape is BoxShape3D:
			kz_col.shape.size = Vector3(120.0, 8.0, 200.0)

func _setup_dynamic_checkpoints(parent: Node3D) -> void:
	checkpoints.clear()
	_player_checkpoints.clear()
	# No checkpoints so players always spawn at start and lose a life

func _spawn_rickshaw(parent: Node3D, z_pos: float, start_x: float, end_x: float, color: Color, duration: float) -> void:
	var rickshaw = AnimatableBody3D.new()
	rickshaw.position = Vector3(start_x, 1.0, z_pos)
	rickshaw.sync_to_physics = true
	
	var mesh = CSGBox3D.new()
	mesh.size = Vector3(2.5, 1.8, 1.8)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	rickshaw.add_child(mesh)
	
	var bar = CSGBox3D.new()
	bar.size = Vector3(0.2, 1.0, 1.2)
	bar.position = Vector3(0.0, -0.4, 1.2)
	bar.material_override = mat
	rickshaw.add_child(bar)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.5, 1.8, 1.8)
	col.shape = box
	rickshaw.add_child(col)
	
	var hit_area = Area3D.new()
	hit_area.collision_mask = 2
	var hit_col = CollisionShape3D.new()
	var hit_box = BoxShape3D.new()
	hit_box.size = Vector3(2.7, 2.0, 2.0)
	hit_col.shape = hit_box
	hit_area.add_child(hit_col)
	hit_area.body_entered.connect(_on_rickshaw_hit)
	rickshaw.add_child(hit_area)
	
	parent.add_child(rickshaw)
	
	var tween = create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(rickshaw, "position:x", end_x, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rickshaw, "position:x", start_x, duration).set_trans(Tween.TRANS_SINE)

func _on_rickshaw_hit(body: Node3D) -> void:
	if body is CharacterBody3D and player_hit_cooldown <= 0.0:
		player_hit_cooldown = 1.0
		var push_dir = Vector3(body.global_position.x, 0.0, 0.0).normalized()
		push_dir.z = 0.8
		body.velocity = push_dir * 28.0 + Vector3(0.0, 12.0, 0.0)

func _on_kite_hit(body: Node3D, area: Area3D) -> void:
	if body is CharacterBody3D:
		var push_dir = (body.global_position - area.global_position).normalized()
		push_dir.y = 0.3
		body.velocity = push_dir * 25.0

func _on_bell_rung(body: Node3D) -> void:
	if body is CharacterBody3D and not round_ended:
		var map = get_node_or_null("MapGeometry")
		if map:
			for child in map.get_children():
				if child is CSGCylinder3D:
					for sub in child.get_children():
						if sub is AudioStreamPlayer3D and sub.name == "BellSound":
							sub.play()
							break

func _process(delta: float) -> void:
	super._process(delta)
	if player_hit_cooldown > 0.0:
		player_hit_cooldown -= delta
		
	if round_ended:
		return
		
	_time_elapsed += delta
	
	for i in range(_kites.size()):
		var kite = _kites[i]
		if is_instance_valid(kite):
			var dx = sin(_time_elapsed * _kite_speeds[i]) * 4.5
			var dy = cos(_time_elapsed * _kite_speeds[i] * 1.5) * _kite_amplitudes[i]
			kite.position = _kite_base_positions[i] + Vector3(dx, dy, 0.0)
