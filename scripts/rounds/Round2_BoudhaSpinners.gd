extends BaseRound

@export var base_spin_speed: float = 1.0
@export var wind_gust_interval: float = 8.0
@export var wind_gust_force: float = 7.5

var _spinners: Array[AnimatableBody3D] = []
var _spinner_speeds: Array[float] = []
var _wind_timer: float = 0.0

func _ready() -> void:
	round_name = "ROUND 2: BOUDHA SPINNERS"
	round_type = RoundType.RACE
	yeti_fact_index = 1
	time_limit = 90.0
	_wind_timer = wind_gust_interval
	
	super._ready()
	_build_course()

func _build_course() -> void:
	# Clean up any existing MapGeometry
	var old_geo = get_node_or_null("MapGeometry")
	if old_geo:
		old_geo.queue_free()
		
	var parent := Node3D.new()
	parent.name = "MapGeometry"
	add_child(parent)

	# ── Start Platform ──
	var start_platform = CSGBox3D.new()
	start_platform.size = Vector3(12.0, 1.0, 10.0)
	start_platform.position = Vector3(0.0, -0.5, 0.0)
	start_platform.use_collision = true
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.35, 0.38, 0.42)
	mat_stone.roughness = 0.8
	start_platform.material_override = mat_stone
	parent.add_child(start_platform)

	# ── Spinning Domes (Boudha Stupas) ──
	# Gap math: 2nd dome edge at z=(-38-6.5)=-44.5; 3rd dome at z=-51, edge at (-51+5)=-46
	# Gap = 1.5 units — comfortably jumpable
	var z_offsets = [-18.0, -38.0, -51.0]
	var radii = [8.0, 6.5, 5.0]
	var heights = [0.0, 1.0, 2.0]
	var spin_directions = [1.0, -1.0, 1.0]
	
	_spinners.clear()
	_spinner_speeds.clear()
	
	for i in range(3):
		var spinner = AnimatableBody3D.new()
		spinner.position = Vector3(0.0, heights[i], z_offsets[i])
		spinner.sync_to_physics = true
		parent.add_child(spinner)
		_spinners.append(spinner)
		
		# Dome base (Stupa dome)
		var dome = CSGCylinder3D.new()
		dome.radius = radii[i]
		dome.height = 1.0
		dome.position = Vector3(0, -0.5, 0)
		var mat_dome = StandardMaterial3D.new()
		# Alternating colors: white base, light clay, temple red
		if i == 0:
			mat_dome.albedo_color = Color(0.9, 0.9, 0.9) # White dome
		elif i == 1:
			mat_dome.albedo_color = Color(0.75, 0.65, 0.5) # Clay dome
		else:
			mat_dome.albedo_color = Color(0.7, 0.25, 0.2) # Brick dome
		dome.material_override = mat_dome
		spinner.add_child(dome)
		
		# Cylinder collision shape
		var col = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = radii[i]
		shape.height = 1.0
		col.shape = shape
		col.position = Vector3(0, -0.5, 0)
		spinner.add_child(col)
		
		# Central Stupa Golden Spire (pinnacle)
		var spire = CSGCylinder3D.new()
		spire.radius = 0.6
		spire.height = 2.2
		spire.position = Vector3(0.0, 1.1, 0.0)
		var mat_gold = StandardMaterial3D.new()
		mat_gold.albedo_color = Color(1.0, 0.84, 0.0)
		mat_gold.metallic = 0.8
		mat_gold.roughness = 0.15
		spire.material_override = mat_gold
		spinner.add_child(spire)
		
		# Rotating Sweeper (Prayer Flag Arm)
		# Lower tiers have longer/faster sweeps
		var arm = CSGBox3D.new()
		arm.size = Vector3(radii[i] * 1.7, 0.4, 0.4)
		arm.position = Vector3(0.0, 0.2, 0.0)
		var mat_arm = StandardMaterial3D.new()
		mat_arm.albedo_color = Color(0.8, 0.1, 0.1) # Bright red sweeper
		arm.material_override = mat_arm
		spinner.add_child(arm)
		
		var arm_col = CollisionShape3D.new()
		var arm_shape = BoxShape3D.new()
		arm_shape.size = arm.size
		arm_col.shape = arm_shape
		arm_col.position = arm.position
		spinner.add_child(arm_col)
		
		# Store spin speed
		var speed = (base_spin_speed + (i * 0.35)) * spin_directions[i]
		_spinner_speeds.append(speed)

	# ── End Platform ──
	var end_platform = CSGBox3D.new()
	end_platform.size = Vector3(10.0, 1.0, 10.0)
	end_platform.position = Vector3(0.0, 2.5, -65.0)
	end_platform.use_collision = true
	end_platform.material_override = mat_stone
	parent.add_child(end_platform)
	
	# ── Decorative Prayer Flags (Lungta) ──
	_spawn_prayer_flags(parent)
	
	# ── Zones setup ──
	if finish_zone:
		finish_zone.global_position = Vector3(0.0, 3.5, -65.0)
	
	if kill_zone:
		kill_zone.global_position = Vector3(0.0, -6.0, -33.0)
		var kz_col = kill_zone.get_node_or_null("CollisionShape3D")
		if kz_col and kz_col.shape is BoxShape3D:
			kz_col.shape.size = Vector3(70.0, 4.0, 105.0)

func _spawn_prayer_flags(parent: Node3D) -> void:
	var colors = [
		Color(0.1, 0.4, 0.8),  # Blue (Sky)
		Color(0.9, 0.9, 0.9),  # White (Air/Wind)
		Color(0.8, 0.1, 0.1),  # Red (Fire)
		Color(0.1, 0.7, 0.2),  # Green (Water)
		Color(0.9, 0.8, 0.1)   # Yellow (Earth)
	]
	
	# Spawn support poles and ropes on both sides
	var x_coords = [-10.0, 10.0]
	var z_coords = [0.0, -20.0, -40.0, -60.0, -73.0]
	
	for x in x_coords:
		for j in range(z_coords.size() - 1):
			var z1 = z_coords[j]
			var z2 = z_coords[j+1]
			
			# Left/Right poles
			var pole = CSGCylinder3D.new()
			pole.radius = 0.15
			pole.height = 5.0
			pole.position = Vector3(x, 2.0, z1)
			pole.use_collision = false
			var mat_wood = StandardMaterial3D.new()
			mat_wood.albedo_color = Color(0.4, 0.25, 0.15)
			pole.material_override = mat_wood
			parent.add_child(pole)
			
			# Rope/string between poles
			var mid_point = Vector3(x, 4.0, (z1 + z2) / 2.0)
			var rope = CSGBox3D.new()
			rope.size = Vector3(0.05, 0.05, abs(z1 - z2))
			rope.position = mid_point
			var mat_rope = StandardMaterial3D.new()
			mat_rope.albedo_color = Color(0.8, 0.8, 0.8)
			rope.material_override = mat_rope
			parent.add_child(rope)
			
			# Hang 5 prayer flags along each rope
			var num_flags = 6
			for k in range(num_flags):
				var ratio = float(k) / float(num_flags - 1)
				var flag_z = lerp(z1, z2, ratio)
				
				var flag = CSGBox3D.new()
				flag.size = Vector3(0.4, 0.4, 0.02)
				# Drop height slightly in the middle to simulate hanging sag
				var sag = sin(ratio * PI) * 0.35
				flag.position = Vector3(x, 3.9 - sag, flag_z)
				
				# Give the flag a slight flutter angle
				flag.rotation_degrees = Vector3(0.0, 15.0 * (1 if k % 2 == 0 else -1), 0.0)
				
				var mat_flag = StandardMaterial3D.new()
				mat_flag.albedo_color = colors[k % colors.size()]
				flag.material_override = mat_flag
				parent.add_child(flag)

func _process(delta: float) -> void:
	super._process(delta)
	
	if round_ended:
		return
		
	# Rotate stupa spinner platforms and their sweeper arms
	for i in range(_spinners.size()):
		var s = _spinners[i]
		if is_instance_valid(s):
			s.rotation.y += _spinner_speeds[i] * delta

	# Wind gusts
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_wind_timer = wind_gust_interval
		_trigger_wind_gust()

func _trigger_wind_gust() -> void:
	var wind_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	if wind_dir.length() < 0.1:
		wind_dir = Vector3(1, 0, 0)
		
	# Show wind warning
	if hud:
		var lbl := Label.new()
		lbl.text = "💨 WIND GUST! 💨"
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		lbl.offset_top = 100
		hud.add_child(lbl)
		get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

	for child in get_children():
		if child is CharacterBody3D:
			if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
				if not child.is_multiplayer_authority():
					continue
			child.velocity += wind_dir * wind_gust_force
