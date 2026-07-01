extends BaseRound
## ROUND 1 — PASHUPATINATH PROCESSION
## Fall Guys: Gate Crash + Fruit Chute
## Nepal Theme: Race through the ghats of Pashupatinath temple during a festival.
## Obstacles: Swinging dhyangro drums, prayer wheel walls, flower garland trip-ropes.

@export var drum_swing_speed: float = 1.5
@export var wheel_open_interval: float = 2.5
@export var spawn_interval: float = 3.0
@export var garland_count: int = 8

var spawn_timer: float = 4.0
var _drums: Array[AnimatableBody3D] = []
var _wheel_gates: Array[Array] = []   # [[left_door, right_door, timer], ...]
var _wheel_timers: Array[float] = []

@onready var boulder_spawner: Marker3D = $BoulderSpawner

func _ready() -> void:
	round_name = "ROUND 1: PASHUPATINATH PROCESSION"
	round_type = RoundType.RACE
	yeti_fact_index = 0
	time_limit = 90.0
	
	super._ready()
	_build_course()

func _build_course() -> void:
	# Clean up any existing MapGeometry from the scene
	var old_geo = get_node_or_null("MapGeometry")
	if old_geo:
		old_geo.queue_free()

	var parent := Node3D.new()
	parent.name = "MapGeometry"
	add_child(parent)

	# ── Ground floor: stone ghat steps ──────────────────────────────────────
	var step_z := 0.0
	for tier in range(5):
		var step := CSGBox3D.new()
		step.use_collision = true
		step.size = Vector3(14.0, 0.8, 18.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.65, 0.55)
		step.material_override = mat
		step.position = Vector3(0.0, float(tier) * 1.5, step_z - float(tier) * 15.0)
		parent.add_child(step)
		step_z -= 15.0

	# ── Dhyangro drum obstacles (swinging pendulums) ─────────────────────────
	# Pivots raised to y=11 so the 9-unit arm sweeps nearly the full 22-unit platform
	var drum_positions := [
		Vector3(-4.0, 11.0, -12.0), Vector3(4.0, 11.0, -27.0),
		Vector3(0.0, 11.0, -42.0),  Vector3(-3.5, 12.5, -57.0),
		Vector3(3.5, 12.5, -65.0),
	]
	for dpos in drum_positions:
		_spawn_drum(parent, dpos)

	# ── Prayer wheel gate rows ───────────────────────────────────────────────
	for i in range(3):
		_spawn_gate_row(parent, -30.0 - float(i) * 20.0, float(i) * 1.5)

	# ── Flower garland trip-ropes ────────────────────────────────────────────
	for j in range(garland_count):
		var gar := CSGBox3D.new()
		gar.use_collision = true
		gar.size = Vector3(10.0, 0.18, 1.8)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.95, 0.60, 0.20)
		gar.material_override = gmat
		gar.position = Vector3(0.0, float(j / 2) * 1.5 + 0.28, -8.0 - float(j) * 9.0)
		parent.add_child(gar)
		
		# Add trigger area
		var area = Area3D.new()
		area.collision_mask = 2 # Player layer
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(10.0, 0.5, 1.8)
		col.shape = box
		area.add_child(col)
		area.position = gar.position
		area.body_entered.connect(_on_garland_entered)
		area.body_exited.connect(_on_garland_exited)
		parent.add_child(area)

	# ── Bell at finish ───────────────────────────────────────────────────────
	var bell := CSGCylinder3D.new()
	bell.radius = 1.2
	bell.height = 2.0
	bell.use_collision = false
	bell.position = Vector3(0.0, 8.5, -78.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.84, 0.0)
	bell.material_override = bmat
	parent.add_child(bell)

	# Reposition FinishZone
	if finish_zone:
		finish_zone.global_position = Vector3(0.0, 8.0, -76.0)

func _on_garland_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("apply_speed_boost"):
		body.apply_speed_boost(0.5, 1.0) # slow down

func _on_garland_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("apply_speed_boost"):
		body.apply_speed_boost(1.0, 0.1) # restore speed quickly

func _spawn_drum(parent: Node3D, pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)

	var drum := AnimatableBody3D.new()
	drum.sync_to_physics = true
	# Arm length of 9.0 units: sin(72°) * 9.0 ≈ 8.56 units of lateral reach,
	# sweeping almost the full 22-unit platform width
	drum.position = Vector3(0.0, -9.0, 0.0)

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.2, 0.1)
	cyl.surface_set_material(0, mat)
	mesh.mesh = cyl
	drum.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.6
	col.shape = shape
	drum.add_child(col)
	
	var hit_area := Area3D.new()
	hit_area.collision_mask = 2
	var hit_col = CollisionShape3D.new()
	var hit_shape = CylinderShape3D.new()
	hit_shape.radius = 1.0
	hit_shape.height = 1.7
	hit_col.shape = hit_shape
	hit_area.add_child(hit_col)
	hit_area.body_entered.connect(func(body):
		if body is CharacterBody3D:
			# simple knockback
			var dir = (body.global_position - drum.global_position).normalized()
			dir.y = 0.5
			body.velocity = dir * 15.0
	)
	drum.add_child(hit_area)

	pivot.add_child(drum)
	_drums.append(drum)

	# Swing pivot using tween — 72° gives ~8.56 unit lateral reach on a 9-unit arm
	var rng := randf_range(-1.0, 1.0)
	var tw := create_tween().set_loops()
	var start_deg: float = 72.0 * sign(rng if rng != 0.0 else 1.0)
	tw.tween_property(pivot, "rotation_degrees:z", -start_deg, drum_swing_speed).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivot, "rotation_degrees:z",  start_deg, drum_swing_speed).set_trans(Tween.TRANS_SINE)

func _spawn_gate_row(parent: Node3D, z: float, y_offset: float) -> void:
	# Two panel doors — one opens (passable), one stays shut (wall)
	var door_l := _create_door(parent, -3.0, y_offset + 1.5, z)
	var door_r := _create_door(parent, 3.0, y_offset + 1.5, z)
	
	var doors_entry = [door_l, door_r]

	# Timer to toggle one of the doors
	var timer := Timer.new()
	timer.wait_time = wheel_open_interval
	timer.autostart = true
	var open_idx := 0
	timer.timeout.connect(func():
		open_idx = 1 - open_idx # swap
		var d_open = doors_entry[open_idx]
		var d_shut = doors_entry[1 - open_idx]
		
		# Animate slide
		var tw_o = create_tween()
		tw_o.tween_property(d_open, "position:y", y_offset + 1.5 - 3.0, 0.4)
		var tw_s = create_tween()
		tw_s.tween_property(d_shut, "position:y", y_offset + 1.5, 0.4)
	)
	parent.add_child(timer)

func _create_door(parent: Node3D, x: float, y: float, z: float) -> AnimatableBody3D:
	var door := AnimatableBody3D.new()
	door.sync_to_physics = true
	door.position = Vector3(x, y, z)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5.5, 3.0, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.5, 0.2)
	box.surface_set_material(0, mat)
	mesh.mesh = box
	door.add_child(mesh)

	var col := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(5.5, 3.0, 0.25)
	col.shape = bshape
	door.add_child(col)

	parent.add_child(door)
	return door

func _process(delta: float) -> void:
	super._process(delta)
