extends BaseRound

## ─── OBSTACLE SPAWNER TUNABLES ───────────────────────────────────────────────

## How often (seconds) a new boulder is spawned once the safe zone has passed.
@export var spawn_interval: float = 2.8

## Boulders never spawn within this many units (Z-distance) of the player's current position.
@export var safe_zone_distance: float = 15.0

## Minimum world-Z gap between consecutive boulders (prevents clustering).
@export var min_obstacle_spacing: float = 20.0

## Maximum allowed radius for a boulder. 
## Adjusted to 0.75 so total diameter (height) is exactly 1.5 units,
## allowing the player's calibrated jump height to cleanly clear them.
const MAX_BOULDER_RADIUS: float = 0.75
const MIN_BOULDER_RADIUS: float = 0.45

## ─── RUNTIME STATE ───────────────────────────────────────────────────────────
var spawn_timer: float = 0.0
var last_boulder_z: float = -99999.0   # tracks Z of the last placed boulder

@onready var boulder_spawner: Marker3D = $BoulderSpawner

func _ready() -> void:
	super._ready()
	round_name = "ROUND 1: HIMALAYAN CLIMB"
	# Give the player 4 seconds of zero-boulder grace at the very start
	# (safe_zone_distance provides spatial safety; this provides temporal safety).
	spawn_timer = 4.0
	# Initialise spacing tracker at spawner Z so first boulder respects spacing
	last_boulder_z = boulder_spawner.global_position.z

func _process(delta: float) -> void:
	super._process(delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_boulder()
		spawn_timer = spawn_interval

## Validates spatial constraints before committing to a spawn.
func _try_spawn_boulder() -> void:
	if not boulder_spawner:
		return

	# Pick a randomised spawn position around the spawner marker
	var candidate_offset := Vector3(randf_range(-5.5, 5.5), 0.0, randf_range(-0.8, 0.8))
	var candidate_pos: Vector3 = boulder_spawner.global_position + candidate_offset

	# ── Guard 1: Dynamic Safe Zone ───────────────────────────────────────────
	# Dynamically check where the player is currently standing instead of assuming Z=0.
	var current_player_z: float = 0.0
	var player_node = get_tree().get_first_node_in_group("player")
	
	if player_node:
		current_player_z = player_node.global_position.z

	# If the boulder's proposed placement is too close to the player's real-time position, skip.
	if abs(candidate_pos.z - current_player_z) < safe_zone_distance:
		return 

	# ── Guard 2: minimum spacing ──────────────────────────────────────────────
	if abs(candidate_pos.z - last_boulder_z) < min_obstacle_spacing:
		return  # too close to the last boulder — skip this tick

	# All guards passed — spawn it
	_spawn_boulder(candidate_pos)
	last_boulder_z = candidate_pos.z

## Instantiates a single well-proportioned boulder RigidBody3D at world_pos.
func _spawn_boulder(world_pos: Vector3) -> void:
	# ── Size: capped so height never exceeds 1.5 units (MAX_BOULDER_RADIUS=0.75) ─
	var radius: float = randf_range(MIN_BOULDER_RADIUS, MAX_BOULDER_RADIUS)

	# ── Physics body ──────────────────────────────────────────────────────────
	var boulder := RigidBody3D.new()
	boulder.collision_layer = 1
	boulder.collision_mask  = 3   # environment (1) + player (2)
	boulder.mass            = 60.0 + radius * 40.0  # heavier boulders are bigger
	# Prevent extreme tumbling that looks physics-glitchy
	boulder.angular_damp    = 0.6

	# ── Collision ─────────────────────────────────────────────────────────────
	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape    = shape
	boulder.add_child(col)

	# ── Visual mesh ───────────────────────────────────────────────────────────
	var mesh_inst := MeshInstance3D.new()
	var mesh      := SphereMesh.new()
	mesh.radius   = radius
	mesh.height   = radius * 2.0   # height == diameter, perfectly round sphere

	# Stylised stone with slight colour variation per boulder
	var grey_shift := randf_range(-0.05, 0.05)
	var mat        := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38 + grey_shift, 0.40 + grey_shift, 0.43 + grey_shift)
	mat.roughness    = 0.92
	mat.metallic     = 0.05
	# Subtle emission so the boulder reads clearly against the white snow
	mat.emission_enabled          = true
	mat.emission                  = Color(0.18, 0.18, 0.20)
	mat.emission_energy_multiplier = 0.08
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh = mesh

	boulder.add_child(mesh_inst)

	# ── Position (slightly elevated so it rolls, not slides) ──────────────────
	boulder.global_position = world_pos + Vector3(0.0, radius + 0.1, 0.0)

	add_child(boulder)

	# ── Initial push downhill (+Z direction toward player) ────────────────────
	# Applies force after one physics frame so the RigidBody is in the tree.
	await get_tree().process_frame
	if is_instance_valid(boulder):
		var downhill_push := Vector3(
			randf_range(-1.5, 1.5),    # slight lateral wobble
			-1.0,                      # small downward component
			randf_range(6.0, 10.0)     # main push toward player (+Z)
		)
		boulder.apply_central_impulse(downhill_push * boulder.mass * 0.35)

	# ── Auto-cleanup ──────────────────────────────────────────────────────────
	get_tree().create_timer(14.0).timeout.connect(func():
		if is_instance_valid(boulder):
			boulder.queue_free()
	)
	
