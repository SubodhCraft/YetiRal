extends BaseRound

## ─── CUSTOM CONSTANTS & PRELOADS ─────────────────────────────────────────────
const SLIPPERY_SCRIPT = preload("res://scripts/rounds/SlipperyZone.gd")

## ─── MEMBER VARIABLES ────────────────────────────────────────────────────────
var _prayer_wheels: Array[AnimatableBody3D] = []
var _prayer_wheel_speeds: Array[float] = [1.2, -1.8, 1.5, -1.0, 0.8]

var _boats: Array[AnimatableBody3D] = []
var _boat_base_positions: Array[Vector3] = []
var _boat_speeds: Array[float] = [1.8, -1.5, 2.2, -1.7]
var _boat_widths: Array[float] = [6.0, 5.0, 6.0, 5.5]

var _bell_pivots: Array[Node3D] = []
var _bell_swing_speeds: Array[float] = [1.8, 2.4, 2.0]
var _bell_max_angles: Array[float] = [35.0, 45.0, 40.0]

var _time_elapsed: float = 0.0

func _ready() -> void:
	# Round 3 has no mid-round checkpoints — failing always reloads from the start
	checkpoints.clear()
	
	super._ready()
	round_name = "ROUND 3: TRISHULI CROSSING"
	round_type = RoundType.RACE
	yeti_fact_index = 2
	time_limit = 90.0
	
	_build_trishuli_course()

func _build_trishuli_course() -> void:
	# Clean up any existing MapGeometry built by the script
	var old_geo = get_node_or_null("ScriptGeometry")
	if old_geo:
		old_geo.queue_free()
		
	# Fix for Water Plane being solid: remove it from MapGeometry (CSGCombiner)
	# and add it back at the root level so it doesn't inherit collision
	var old_water = get_node_or_null("MapGeometry/WaterPlane")
	if old_water:
		old_water.get_parent().remove_child(old_water)
		add_child(old_water)
		old_water.use_collision = false
		
	var parent = Node3D.new()
	parent.name = "ScriptGeometry"
	add_child(parent)

	# Shared Materials
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.35, 0.35, 0.38)
	mat_stone.roughness = 0.85

	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.9, 0.72, 0.08)
	mat_gold.metallic = 0.95
	mat_gold.roughness = 0.15

	var mat_red_clay = StandardMaterial3D.new()
	mat_red_clay.albedo_color = Color(0.65, 0.22, 0.15) # Red temple brick

	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.4, 0.25, 0.15) # Boat dark wood
	mat_wood.roughness = 0.9

	# ── Remove the old suspension bridge nodes ──
	for node_name in ["BridgeGenerator", "AnchorStart", "AnchorEnd"]:
		var n = get_node_or_null(node_name)
		if n:
			n.queue_free()

	# ── OBSTACLE A: SPINNING PRAYER WHEELS (MANE) ──
	_prayer_wheels.clear()
	var wheel_z_positions = [-12.0, -18.5, -25.0, -31.5, -38.0]
	var wheel_x_positions = [0.0, -2.5, 2.5, -2.0, 0.0]
	var wheel_radii = [2.2, 1.8, 2.0, 1.8, 2.2]
	
	for i in range(wheel_z_positions.size()):
		var w_pos = Vector3(wheel_x_positions[i], -0.2, wheel_z_positions[i])
		var w_rad = wheel_radii[i]
		
		var wheel = AnimatableBody3D.new()
		wheel.position = w_pos
		wheel.sync_to_physics = true
		parent.add_child(wheel)
		_prayer_wheels.append(wheel)
		
		# Collision
		var col = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		cyl_shape.radius = w_rad
		cyl_shape.height = 1.6
		col.shape = cyl_shape
		wheel.add_child(col)
		
		# Visuals: Main drum (red)
		var drum = CSGCylinder3D.new()
		drum.radius = w_rad
		drum.height = 1.6
		drum.material_override = mat_red_clay
		drum.use_collision = false
		wheel.add_child(drum)
		
		# Gold bands (top/bottom)
		var top_band = CSGCylinder3D.new()
		top_band.radius = w_rad + 0.08
		top_band.height = 0.25
		top_band.position = Vector3(0.0, 0.68, 0.0)
		top_band.material_override = mat_gold
		wheel.add_child(top_band)
		
		var bot_band = CSGCylinder3D.new()
		bot_band.radius = w_rad + 0.08
		bot_band.height = 0.25
		bot_band.position = Vector3(0.0, -0.68, 0.0)
		bot_band.material_override = mat_gold
		wheel.add_child(bot_band)
		
		# Central gold pin
		var pin = CSGCylinder3D.new()
		pin.radius = 0.2
		pin.height = 2.2
		pin.material_override = mat_gold
		wheel.add_child(pin)
		
		# Small decorative spokes
		for angle in [0, 90, 180, 270]:
			var spoke = CSGBox3D.new()
			spoke.size = Vector3(w_rad * 1.8, 0.15, 0.15)
			spoke.rotation_degrees.y = angle
			spoke.material_override = mat_gold
			wheel.add_child(spoke)

	# ── OBSTACLE B: SUSPENDED NAUCHAS (NEPALI BOATS) ──
	_boats.clear()
	_boat_base_positions.clear()
	var boat_z_positions = [-62.0, -72.0, -82.0, -92.0]
	
	for i in range(boat_z_positions.size()):
		var b_pos = Vector3(0.0, -1.0, boat_z_positions[i])
		
		var boat = AnimatableBody3D.new()
		boat.position = b_pos
		boat.sync_to_physics = true
		parent.add_child(boat)
		_boats.append(boat)
		_boat_base_positions.append(b_pos)
		
		# Collision
		var col = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(5.5, 0.8, 3.5)
		col.shape = box_shape
		boat.add_child(col)
		
		# Visuals: Boat base
		var base = CSGBox3D.new()
		base.size = Vector3(5.0, 0.8, 3.0)
		base.material_override = mat_wood
		boat.add_child(base)
		
		# Bow
		var bow = CSGBox3D.new()
		bow.size = Vector3(1.2, 1.2, 3.0)
		bow.position = Vector3(2.6, 0.4, 0.0)
		bow.rotation_degrees.z = 25.0
		bow.material_override = mat_wood
		boat.add_child(bow)
		
		# Stern
		var stern = CSGBox3D.new()
		stern.size = Vector3(1.2, 1.2, 3.0)
		stern.position = Vector3(-2.6, 0.4, 0.0)
		stern.rotation_degrees.z = -25.0
		stern.material_override = mat_wood
		boat.add_child(stern)
		
		# Slippery effect
		var slippery = Area3D.new()
		slippery.set_script(SLIPPERY_SCRIPT)
		slippery.set("slide_factor", 0.4)
		var s_col = CollisionShape3D.new()
		var s_box = BoxShape3D.new()
		s_box.size = Vector3(5.0, 1.2, 3.0)
		s_col.shape = s_box
		s_col.position = Vector3(0.0, 0.6, 0.0)
		slippery.add_child(s_col)
		boat.add_child(slippery)

	# ── OBSTACLE C: SWINGING TEMPLE BELLS (GHANTA) ──
	_bell_pivots.clear()
	
	# Flat rest platform connecting boat zone to bell zone
	var bank_rest = CSGBox3D.new()
	bank_rest.size = Vector3(14.0, 2.0, 6.0)
	bank_rest.position = Vector3(0.0, -1.0, -100.0)
	bank_rest.use_collision = true
	bank_rest.material_override = mat_stone
	parent.add_child(bank_rest)
	
	# FLAT ground-level platform for the bell arches — horizontal, walkable
	var bell_floor = CSGBox3D.new()
	bell_floor.size = Vector3(14.0, 1.0, 90.0)
	bell_floor.position = Vector3(0.0, -0.5, -145.0)
	bell_floor.use_collision = true
	bell_floor.material_override = mat_stone
	parent.add_child(bell_floor)
	
	var bell_z_positions = [-115.0, -140.0, -165.0]
	
	for i in range(bell_z_positions.size()):
		var bz = bell_z_positions[i]
		# All arches sit at ground level (Y=0) — aligned horizontally
		
		# Temple Arch (Toran)
		var arch_group = Node3D.new()
		arch_group.position = Vector3(0.0, 0.0, bz)
		parent.add_child(arch_group)
		
		var pill_l = CSGBox3D.new()
		pill_l.size = Vector3(1.2, 10.0, 1.2)
		pill_l.position = Vector3(-6.5, 4.5, 0.0)
		pill_l.material_override = mat_red_clay
		arch_group.add_child(pill_l)
		
		var pill_r = CSGBox3D.new()
		pill_r.size = Vector3(1.2, 10.0, 1.2)
		pill_r.position = Vector3(6.5, 4.5, 0.0)
		pill_r.material_override = mat_red_clay
		arch_group.add_child(pill_r)
		
		var beam = CSGBox3D.new()
		beam.size = Vector3(14.5, 1.2, 1.5)
		beam.position = Vector3(0.0, 9.2, 0.0)
		beam.material_override = mat_red_clay
		arch_group.add_child(beam)
		
		var roof = CSGBox3D.new()
		roof.size = Vector3(15.2, 0.5, 2.2)
		roof.position = Vector3(0.0, 9.9, 0.0)
		roof.material_override = mat_gold
		arch_group.add_child(roof)
		
		# Pendulum pivot
		var pivot = Node3D.new()
		pivot.position = Vector3(0.0, 8.8, 0.0)
		arch_group.add_child(pivot)
		_bell_pivots.append(pivot)
		
		# Pendulum Rod (Extended to touch ground)
		var rod = CSGCylinder3D.new()
		rod.radius = 0.12
		rod.height = 8.0
		rod.position = Vector3(0.0, -4.0, 0.0)
		rod.material_override = mat_stone
		pivot.add_child(rod)
		
		# The Bell
		var bell_body = CSGCylinder3D.new()
		bell_body.radius = 1.1
		bell_body.height = 1.8
		bell_body.cone = false
		bell_body.position = Vector3(0.0, -8.0, 0.0)
		bell_body.material_override = mat_gold
		pivot.add_child(bell_body)
		
		var dome = CSGCylinder3D.new()
		dome.radius = 1.1
		dome.height = 0.6
		dome.cone = true
		dome.position = Vector3(0.0, -6.9, 0.0)
		dome.material_override = mat_gold
		pivot.add_child(dome)
		
		# Collision Area3D for knockback
		var hit_area = Area3D.new()
		hit_area.collision_mask = 2
		var h_col = CollisionShape3D.new()
		var h_shape = CylinderShape3D.new()
		h_shape.radius = 1.35
		h_shape.height = 2.0
		h_col.shape = h_shape
		h_col.position = Vector3(0.0, -8.0, 0.0)
		hit_area.add_child(h_col)
		pivot.add_child(hit_area)
		
		hit_area.body_entered.connect(func(body):
			_on_bell_hit(body, hit_area)
		)

	# ── FINISH SHRINE (PAGODA STYLE) ──
	var pagoda_base = CSGBox3D.new()
	pagoda_base.size = Vector3(5.0, 4.0, 5.0)
	pagoda_base.position = Vector3(0.0, 2.5, -205.0)
	pagoda_base.material_override = mat_red_clay
	parent.add_child(pagoda_base)
	
	var pagoda_roof = CSGBox3D.new()
	pagoda_roof.size = Vector3(7.0, 0.8, 7.0)
	pagoda_roof.position = Vector3(0.0, 4.7, -205.0)
	pagoda_roof.material_override = mat_gold
	parent.add_child(pagoda_roof)

	# Zones adjustment
	if finish_zone:
		finish_zone.global_position = Vector3(0.0, 1.5, -205.0)
	if kill_zone:
		kill_zone.global_position = Vector3(0.0, -15.0, -100.0)
		var kz_col = kill_zone.get_node_or_null("CollisionShape3D")
		if kz_col and kz_col.shape is BoxShape3D:
			kz_col.shape.size = Vector3(120.0, 8.0, 400.0)

	# WaterKillZone: raised to catch anyone who steps onto the water surface
	# But must be low enough not to overlap with the top of the Naucha boats (Y=-0.6)
	var water_kill = get_node_or_null("WaterKillZone")
	if water_kill and water_kill is Area3D:
		water_kill.global_position = Vector3(0.0, -2.5, -100.0)
		var wkz_col = water_kill.get_node_or_null("CollisionShape3D")
		if wkz_col and wkz_col.shape is BoxShape3D:
			wkz_col.shape.size = Vector3(90.0, 2.0, 200.0)
		if not water_kill.body_entered.is_connected(_on_kill_zone_body_entered):
			water_kill.body_entered.connect(_on_kill_zone_body_entered)

func _on_bell_hit(body: Node3D, area: Area3D) -> void:
	if body is CharacterBody3D:
		var push_dir = (body.global_position - area.global_position).normalized()
		push_dir.y = 0.4
		body.velocity = push_dir * 30.0

func _process(delta: float) -> void:
	super._process(delta)
	if round_ended:
		return
		
	_time_elapsed += delta
	
	# 1. Rotate Prayer Wheels
	for i in range(_prayer_wheels.size()):
		var wheel = _prayer_wheels[i]
		if is_instance_valid(wheel):
			wheel.rotate_y(_prayer_wheel_speeds[i] * delta)
			
	# 2. Slide Nauchas (Boats) side to side
	for i in range(_boats.size()):
		var boat = _boats[i]
		if is_instance_valid(boat):
			var slide_x = sin(_time_elapsed * _boat_speeds[i] * 0.7) * _boat_widths[i]
			boat.position = _boat_base_positions[i] + Vector3(slide_x, 0.0, 0.0)
			
	# 3. Swing Bells in alternating directions
	for i in range(_bell_pivots.size()):
		var pivot = _bell_pivots[i]
		if is_instance_valid(pivot):
			var phase_offset = 0.0 if i % 2 == 0 else PI
			var swing = sin(_time_elapsed * _bell_swing_speeds[i] + phase_offset) * deg_to_rad(_bell_max_angles[i])
			pivot.rotation.z = swing
