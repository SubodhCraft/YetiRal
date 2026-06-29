extends BaseRound

const NUM_ROWS = 5
const CYCLE_TIME = 4.0
const ROW_SPACING = 15.0

var _door_rows: Array[Array] = [] # Array of [left_door, right_door, left_lamp, right_lamp, real_side]
var _cycle_timer: float = 0.0
var _rng = RandomNumberGenerator.new()
var _heat_areas: Array[Area3D] = []

func _ready() -> void:
	super._ready()
	round_name = "ROUND 7: LAVA DOOR MONASTERY"
	round_type = RoundType.RACE
	yeti_fact_index = 6
	time_limit = 75.0
	_rng.randomize()
	
	# Clear old nodes
	var map_geo = get_node_or_null("MapGeometry")
	if map_geo: map_geo.queue_free()
	var triggers = get_node_or_null("Triggers")
	if triggers: triggers.queue_free()
	
	var new_geo = Node3D.new()
	new_geo.name = "MapGeometry"
	add_child(new_geo)
	
	_build_monastery(new_geo)
	_build_doors(new_geo)
	_build_finish(new_geo)
	
	_cycle_timer = CYCLE_TIME
	_assign_real_doors()
	_update_door_states()

func _build_monastery(parent: Node3D) -> void:
	# Lava floor
	var lava = CSGBox3D.new()
	lava.size = Vector3(30.0, 2.0, 100.0)
	lava.position = Vector3(0, -6.0, -40.0)
	lava.use_collision = true
	var lava_mat = StandardMaterial3D.new()
	lava_mat.albedo_color = Color(1.0, 0.3, 0.0)
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.3, 0.0)
	lava_mat.emission_energy_multiplier = 1.0
	lava.material_override = lava_mat
	parent.add_child(lava)
	
	if kill_zone:
		kill_zone.global_position = Vector3(0, -5.0, -40.0)
		var kc = kill_zone.get_node_or_null("CollisionShape3D")
		if kc and kc.shape is BoxShape3D:
			kc.shape.size = Vector3(30.0, 4.0, 100.0)

	# Start platform
	var start = CSGBox3D.new()
	start.size = Vector3(12.0, 1.0, 10.0)
	start.position = Vector3(0, -0.5, 0.0)
	start.use_collision = true
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.3, 0.3, 0.35)
	start.material_override = mat_stone
	parent.add_child(start)

	# Side walls
	var left_wall = CSGBox3D.new()
	left_wall.size = Vector3(1.0, 10.0, 100.0)
	left_wall.position = Vector3(-6.5, 4.0, -40.0)
	left_wall.use_collision = true
	left_wall.material_override = mat_stone
	parent.add_child(left_wall)
	
	var right_wall = CSGBox3D.new()
	right_wall.size = Vector3(1.0, 10.0, 100.0)
	right_wall.position = Vector3(6.5, 4.0, -40.0)
	right_wall.use_collision = true
	right_wall.material_override = mat_stone
	parent.add_child(right_wall)

func _build_doors(parent: Node3D) -> void:
	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.4, 0.2, 0.1)
	
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.3, 0.3, 0.35)
	
	for i in range(NUM_ROWS):
		var z_pos = -10.0 - (i * ROW_SPACING)
		
		# Center pillar separating the doors
		var pillar = CSGCylinder3D.new()
		pillar.radius = 1.0
		pillar.height = 10.0
		pillar.position = Vector3(0, 4.0, z_pos)
		pillar.use_collision = true
		pillar.material_override = mat_stone
		parent.add_child(pillar)
		
		var door_l = _create_door(parent, -3.25, z_pos, mat_wood)
		var door_r = _create_door(parent, 3.25, z_pos, mat_wood)
		
		var lamp_l = _create_lamp(parent, -3.25, z_pos + 1.0)
		var lamp_r = _create_lamp(parent, 3.25, z_pos + 1.0)
		
		_door_rows.append([door_l, door_r, lamp_l, lamp_r, 0])
		
		# Path bridges (always present, but if player chooses wrong they hit closed door)
		# Actually, plan says lava floor below corridor, so players just run on floor?
		# No, the floor is lava. The bridges connect the doors.
		var bridge = CSGBox3D.new()
		bridge.size = Vector3(12.0, 1.0, ROW_SPACING)
		bridge.position = Vector3(0, -0.5, z_pos + (ROW_SPACING/2.0))
		bridge.use_collision = true
		bridge.material_override = mat_stone
		parent.add_child(bridge)

		# Heat hazards
		_create_heat_hazard(parent, -3.25, z_pos + 2.0, i, 0)
		_create_heat_hazard(parent, 3.25, z_pos + 2.0, i, 1)

func _create_door(parent: Node3D, x: float, z: float, mat: Material) -> AnimatableBody3D:
	var door = AnimatableBody3D.new()
	door.position = Vector3(x, 2.0, z)
	door.sync_to_physics = true
	
	var mesh = CSGBox3D.new()
	mesh.size = Vector3(4.5, 4.0, 0.5)
	mesh.material_override = mat
	door.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.5, 4.0, 0.5)
	col.shape = box
	door.add_child(col)
	
	parent.add_child(door)
	return door

func _create_lamp(parent: Node3D, x: float, z: float) -> OmniLight3D:
	var lamp = OmniLight3D.new()
	lamp.position = Vector3(x, 1.0, z)
	lamp.light_color = Color(1.0, 0.7, 0.2)
	
	var mesh = CSGCylinder3D.new()
	mesh.radius = 0.2
	mesh.height = 0.5
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.2)
	mesh.material_override = mat
	lamp.add_child(mesh)
	
	parent.add_child(lamp)
	return lamp

func _create_heat_hazard(parent: Node3D, x: float, z: float, row_idx: int, side: int) -> void:
	var area = Area3D.new()
	area.position = Vector3(x, 1.0, z)
	area.collision_mask = 2
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 4.0)
	col.shape = box
	area.add_child(col)
	
	area.body_entered.connect(_on_heat_entered.bind(row_idx, side))
	area.body_exited.connect(_on_heat_exited.bind(row_idx, side))
	
	parent.add_child(area)
	_heat_areas.append(area)

func _build_finish(parent: Node3D) -> void:
	var z_pos = -10.0 - (NUM_ROWS * ROW_SPACING)
	
	var bridge = CSGBox3D.new()
	bridge.size = Vector3(12.0, 1.0, ROW_SPACING)
	bridge.position = Vector3(0, -0.5, z_pos + (ROW_SPACING/2.0))
	bridge.use_collision = true
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.3, 0.3, 0.35)
	bridge.material_override = mat_stone
	parent.add_child(bridge)
	
	var platform = CSGBox3D.new()
	platform.size = Vector3(16.0, 1.0, 16.0)
	platform.position = Vector3(0, -0.5, z_pos - 8.0)
	platform.use_collision = true
	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.9, 0.7, 0.1)
	platform.material_override = mat_gold
	parent.add_child(platform)
	
	if finish_zone:
		finish_zone.global_position = Vector3(0, 1.0, z_pos - 8.0)

func _assign_real_doors() -> void:
	for row in _door_rows:
		row[4] = _rng.randi_range(0, 1)

func _update_door_states() -> void:
	for row in _door_rows:
		var door_l = row[0] as AnimatableBody3D
		var door_r = row[1] as AnimatableBody3D
		var lamp_l = row[2] as OmniLight3D
		var lamp_r = row[3] as OmniLight3D
		var real_side = row[4]
		
		# Reset doors (close them)
		door_l.position.y = 2.0
		door_r.position.y = 2.0
		
		# Set lamps
		if real_side == 0:
			lamp_l.light_energy = 2.0
			lamp_r.light_energy = 0.5
			_flicker_lamp(lamp_l)
		else:
			lamp_l.light_energy = 0.5
			lamp_r.light_energy = 2.0
			_flicker_lamp(lamp_r)
			
		# Open real door after 1s
		var tw = create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			if real_side == 0:
				var tw2 = create_tween()
				tw2.tween_property(door_l, "position:y", -3.0, 0.3)
			else:
				var tw2 = create_tween()
				tw2.tween_property(door_r, "position:y", -3.0, 0.3)
		)

func _flicker_lamp(lamp: OmniLight3D) -> void:
	var tw = create_tween().set_loops(10)
	tw.tween_property(lamp, "light_energy", 3.0, 0.1)
	tw.tween_property(lamp, "light_energy", 1.0, 0.1)

func _process(delta: float) -> void:
	super._process(delta)
	if round_ended: return
	
	_cycle_timer -= delta
	if _cycle_timer <= 0.0:
		_cycle_timer = CYCLE_TIME
		_assign_real_doors()
		_update_door_states()

func _on_heat_entered(body: Node3D, row_idx: int, side: int) -> void:
	if body is CharacterBody3D and body.has_method("apply_speed_boost"):
		# Check if this side is the false door (blocked)
		var row = _door_rows[row_idx]
		var real_side = row[4]
		if side != real_side:
			body.apply_speed_boost(0.7, 1.0) # 30% debuff

func _on_heat_exited(body: Node3D, row_idx: int, side: int) -> void:
	if body is CharacterBody3D and body.has_method("apply_speed_boost"):
		body.apply_speed_boost(1.0, 0.2)
