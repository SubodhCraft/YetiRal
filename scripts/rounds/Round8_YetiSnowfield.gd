extends BaseRound

## Round 8: AVALANCHE RUN (SNOWBALL VENDORS)
## Two vendors throw massive snowballs across the pathway trying to
## knock the player off.

# ── Course parameters ─────────────────────────────────────────────────────────
const COURSE_LENGTH   : float = 120.0
const COURSE_WIDTH	: float = 12.0
const COURSE_SEGMENTS : int   = 24

# ── Vendor parameters ─────────────────────────────────────────────────────────
const SNOWBALL_RADIUS : float = 4.0
const THROW_FORCE	 : float = 25.0
const THROW_INTERVAL  : float = 2.0

var vendor_left_pos   : Vector3
var vendor_right_pos  : Vector3
var throw_timer	   : float = 0.0
var throw_left		: bool = true

# ── Materials ─────────────────────────────────────────────────────────────────
var _mat_snow   : StandardMaterial3D
var _mat_ice	: StandardMaterial3D
var _mat_rock   : StandardMaterial3D

func _ready() -> void:
	round_name	  = "ROUND 8: AVALANCHE RUN (SNOWBALL VENDORS)"
	round_type	  = RoundType.FINAL
	yeti_fact_index = 7
	time_limit	  = 90.0
	
	super._ready()
	_build_materials()
	_build_course()
	_setup_vendors()

# ─── Materials ────────────────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_snow = StandardMaterial3D.new()
	_mat_snow.albedo_color = Color(0.93, 0.95, 1.0)
	_mat_snow.roughness	= 0.95

	_mat_ice = StandardMaterial3D.new()
	_mat_ice.albedo_color = Color(0.65, 0.82, 0.95)
	_mat_ice.roughness	= 0.1
	_mat_ice.metallic	 = 0.1

	_mat_rock = StandardMaterial3D.new()
	_mat_rock.albedo_color = Color(0.40, 0.38, 0.35)
	_mat_rock.roughness	= 1.0

# ─── Course ───────────────────────────────────────────────────────────────────
func _build_course() -> void:
	var map = Node3D.new()
	map.name = "MapGeometry"
	add_child(map)

	var seg_len = COURSE_LENGTH / COURSE_SEGMENTS

	for i in range(COURSE_SEGMENTS):
		var body = StaticBody3D.new()
		body.position = Vector3(0, -0.25, i * seg_len + seg_len * 0.5)
		map.add_child(body)

		var mesh = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(COURSE_WIDTH, 0.5, seg_len + 0.05)
		mesh.mesh = bm
		mesh.material_override = _mat_snow.duplicate() if (i % 2 == 0) else _mat_ice.duplicate()
		body.add_child(mesh)

		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(COURSE_WIDTH, 0.5, seg_len + 0.05)
		col.shape = box
		body.add_child(col)

	# Finish platform
	var finish_plat = StaticBody3D.new()
	finish_plat.position = Vector3(0, -0.25, COURSE_LENGTH + 3.0)
	map.add_child(finish_plat)
	var fp_mesh = MeshInstance3D.new()
	var fp_bm = BoxMesh.new()
	fp_bm.size = Vector3(COURSE_WIDTH + 4, 0.5, 8.0)
	fp_mesh.mesh = fp_bm
	fp_mesh.material_override = _mat_rock.duplicate()
	finish_plat.add_child(fp_mesh)
	var fp_col = CollisionShape3D.new()
	var fp_box = BoxShape3D.new()
	fp_box.size = Vector3(COURSE_WIDTH + 4, 0.5, 8.0)
	fp_col.shape = fp_box
	finish_plat.add_child(fp_col)

	# Move key nodes
	if spawn_point:
		spawn_point.position = Vector3(0, 0.5, 1.0)
	if finish_zone:
		finish_zone.position = Vector3(0, 1.0, COURSE_LENGTH + 3.0)
		# Make finish zone trigger volume large enough to fill the finish platform
		if finish_zone.get_child_count() > 0 and finish_zone.get_child(0) is CollisionShape3D:
			var fz_shape = (finish_zone.get_child(0) as CollisionShape3D).shape
			if fz_shape is BoxShape3D:
				fz_shape.size = Vector3(COURSE_WIDTH + 4, 6, 8)
		else:
			var fz_col = CollisionShape3D.new()
			var fz_box = BoxShape3D.new()
			fz_box.size = Vector3(COURSE_WIDTH + 4, 6, 8)
			fz_col.shape = fz_box
			finish_zone.add_child(fz_col)
	if kill_zone:
		kill_zone.position = Vector3(0, -20.0, COURSE_LENGTH * 0.5)
		if kill_zone.get_child_count() > 0 and kill_zone.get_child(0) is CollisionShape3D:
			var shape = (kill_zone.get_child(0) as CollisionShape3D).shape
			if shape is BoxShape3D:
				shape.size = Vector3(200, 5, COURSE_LENGTH + 50)
				
	# Add hurdles across the course
	for h in range(1, 4):
		var hurdle_z = COURSE_LENGTH * (float(h) / 4.0)
		var hurdle_body = StaticBody3D.new()
		hurdle_body.position = Vector3(0, 0.5, hurdle_z)
		map.add_child(hurdle_body)
		
		var h_mesh = MeshInstance3D.new()
		var h_bm = BoxMesh.new()
		h_bm.size = Vector3(COURSE_WIDTH - 2.0, 1.0, 1.0)
		h_mesh.mesh = h_bm
		h_mesh.material_override = _mat_rock.duplicate()
		hurdle_body.add_child(h_mesh)
		
		var h_col = CollisionShape3D.new()
		var h_shape = BoxShape3D.new()
		h_shape.size = h_bm.size
		h_col.shape = h_shape
		hurdle_body.add_child(h_col)

func _setup_vendors() -> void:
	# Place vendors side by side beyond the finish line
	var end_z = COURSE_LENGTH + 8.0
	
	vendor_left_pos  = Vector3(-5.0, SNOWBALL_RADIUS, end_z)
	vendor_right_pos = Vector3(5.0, SNOWBALL_RADIUS, end_z)

	_build_vendor(vendor_left_pos, "VENDOR LEFT")
	_build_vendor(vendor_right_pos, "VENDOR RIGHT")

func _build_vendor(pos: Vector3, label_text: String) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	add_child(body)
	
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(4, 8, 4)
	mesh.mesh = bm
	mesh.position.y = -SNOWBALL_RADIUS + 4.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mesh.material_override = mat
	body.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4, 8, 4)
	col.shape = box
	col.position.y = mesh.position.y
	body.add_child(col)
	
	var lbl = Label3D.new()
	lbl.text = label_text
	lbl.position.y = 8.5
	lbl.font_size = 120
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(lbl)

# ─── Process ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	super._process(delta)
	if not round_started or round_ended:
		return
		
	throw_timer -= delta
	if throw_timer <= 0.0:
		throw_timer = THROW_INTERVAL
		_throw_snowball()

func _throw_snowball() -> void:
	var ball = RigidBody3D.new()
	
	# Massive mass so players can't easily push it back
	ball.mass = 500.0 
	
	var start_pos = vendor_left_pos if throw_left else vendor_right_pos
	# Start slightly forward (negative Z) so it doesn't hit the vendor itself
	start_pos.z -= 5.0
	
	ball.position = start_pos
	
	var mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = SNOWBALL_RADIUS
	sm.height = SNOWBALL_RADIUS * 2
	mesh.mesh = sm
	mesh.material_override = _mat_snow.duplicate()
	ball.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = SNOWBALL_RADIUS
	col.shape = shape
	ball.add_child(col)
	
	# Knockback Area3D
	var hit_area = Area3D.new()
	var hit_col = CollisionShape3D.new()
	var hit_shape = SphereShape3D.new()
	hit_shape.radius = SNOWBALL_RADIUS + 0.5
	hit_col.shape = hit_shape
	hit_area.add_child(hit_col)
	ball.add_child(hit_area)
	
	hit_area.body_entered.connect(func(body: Node3D):
		if body is CharacterBody3D:
			var push_dir = (body.global_position - ball.global_position).normalized()
			push_dir.y = 0.4
			push_dir = push_dir.normalized()
			if body.has_method("trigger_yeti_ragdoll"):
				body.trigger_yeti_ragdoll(push_dir * 25.0)
			else:
				body.velocity = push_dir * 30.0
	)
	
	add_child(ball)
	
	# Shoot across the path towards the start line
	var dir = Vector3(0, 0, -1)
	
	# Add a slight random X drift to make it harder
	dir.x = randf_range(-0.15, 0.15)
	
	ball.apply_central_impulse(dir.normalized() * THROW_FORCE * ball.mass)
	
	throw_left = not throw_left
	
	# Clean up after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(ball):
			ball.queue_free()
	)

# ─── Override objective text ──────────────────────────────────────────────────
func _get_round_objective() -> String:
	return "Sprint to the FINISH line! But watch out, two massive snowball vendors on the sides of the path are taking turns throwing giant snowballs at you to knock you off the mountain!"
