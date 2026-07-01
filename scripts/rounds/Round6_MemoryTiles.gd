extends BaseRound

## Round 6: ICE PILLAR PARKOUR
## Players must jump across a series of cylindrical ice pillars
## that are bobbing up and down over a bottomless chasm.

# ── Pillar parameters ────────────────────────────────────────────────────────
const PILLAR_COUNT   : int = 15
const PILLAR_RADIUS  : float = 2.0
const PILLAR_SPACING : float = 4.5
const CHASM_DEPTH	: float = 30.0

var pillars		: Array[AnimatableBody3D] = []
var pillar_offsets : Array[float] = []

# ── Materials ─────────────────────────────────────────────────────────────────
var _mat_ice : StandardMaterial3D

func _ready() -> void:
	round_name	  = "ROUND 6: BHANJYANG BALANCE"
	round_type	  = RoundType.RACE
	yeti_fact_index = 5
	time_limit	  = 90.0
	
	# Build scene FIRST so SpawnPoint is moved to the safe starting platform
	# BEFORE super._ready() spawns the player. Otherwise the player spawns at
	# the scene's default SpawnPoint (Z=12, mid-chasm) with no platform under them.
	_build_materials()
	_build_scene()
	
	super._ready()

# ─── Build materials ──────────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_ice = StandardMaterial3D.new()
	_mat_ice.albedo_color = Color(0.65, 0.82, 0.95)
	_mat_ice.roughness	= 0.1
	_mat_ice.metallic	 = 0.2
	_mat_ice.emission_enabled = true
	_mat_ice.emission = Color(0.2, 0.4, 0.6)
	_mat_ice.emission_energy_multiplier = 0.5

# ─── Build scene procedurally ─────────────────────────────────────────────────
func _build_scene() -> void:
	var map = Node3D.new()
	map.name = "MapGeometry"
	add_child(map)

	# Sky / chasm atmosphere
	var fog = MeshInstance3D.new()
	var fog_mesh = PlaneMesh.new()
	fog_mesh.size = Vector2(100, 150)
	fog.mesh = fog_mesh
	var fog_mat = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.6, 0.75, 0.9, 0.35)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.material_override = fog_mat
	fog.position = Vector3(0, -10, (PILLAR_COUNT * PILLAR_SPACING) * 0.5)
	map.add_child(fog)

	# Start platform (rock ledge)
	_build_platform(map, Vector3(0, -0.5, -2), Vector3(8, 1.0, 8), Color(0.45, 0.40, 0.35))

	# End platform
	var total_len = PILLAR_COUNT * PILLAR_SPACING
	_build_platform(map, Vector3(0, -0.5, total_len + 2), Vector3(8, 1.0, 8), Color(0.45, 0.40, 0.35))

	# Ice Pillars
	for i in range(PILLAR_COUNT):
		var z_pos = (i * PILLAR_SPACING) + (PILLAR_SPACING * 0.5)
		
		# Slight x offset for zigzag path
		var x_pos = sin(i * 1.5) * 2.0
		
		var body = AnimatableBody3D.new()
		body.position = Vector3(x_pos, -2.0, z_pos)
		add_child(body)
		
		var mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = PILLAR_RADIUS
		cyl.bottom_radius = PILLAR_RADIUS
		cyl.height = 15.0
		mesh.mesh = cyl
		mesh.material_override = _mat_ice.duplicate()
		# Position mesh so top is at body origin
		mesh.position.y = -7.5
		body.add_child(mesh)
		
		var col = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = PILLAR_RADIUS
		shape.height = 15.0
		col.shape = shape
		col.position.y = -7.5
		body.add_child(col)
		
		pillars.append(body)
		pillar_offsets.append(randf() * TAU) # Random phase for bobbing

	# HUD Screen Label
	var lbl = Label3D.new()
	lbl.font_size = 90
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 6.0, total_len * 0.5)
	lbl.text = "DON'T LOOK DOWN!"
	lbl.modulate = Color(0.6, 0.9, 1.0)
	add_child(lbl)

	# Move SpawnPoint & FinishZone
	if spawn_point:
		spawn_point.position = Vector3(0, 0.5, -2.0)
		spawn_point.rotation_degrees = Vector3(0, 180, 0)
	if finish_zone:
		finish_zone.position = Vector3(0, 0.0, total_len + 2.0)
	if kill_zone:
		kill_zone.position = Vector3(0, -20.0, total_len * 0.5)
		if kill_zone.get_child_count() > 0 and kill_zone.get_child(0) is CollisionShape3D:
			var shape = (kill_zone.get_child(0) as CollisionShape3D).shape
			if shape is BoxShape3D:
				shape.size = Vector3(200, 30, 200)
		else:
			var col = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(200, 30, 200)
			col.shape = box
			kill_zone.add_child(col)

func _build_platform(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	parent.add_child(body)

# ─── Process ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not round_started or round_ended:
		return
		
	var time = Time.get_ticks_msec() / 1000.0
	
	for i in range(pillars.size()):
		var body = pillars[i]
		var offset = pillar_offsets[i]
		# Pillars bob up and down by 2 units
		var target_y = sin(time * 2.0 + offset) * 1.5 - 0.5
		
		# Move vertically
		body.position.y = target_y

# ─── Override _get_round_objective ────────────────────────────────────────────
func _get_round_objective() -> String:
	return "Jump across the icy pillars suspended over the chasm! Time your jumps carefully as the pillars bob up and down. Reach the far side before time runs out!"
