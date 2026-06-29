class_name YetiAIController
extends CharacterBody3D

## YetiAIController.gd
## A complete waypoint-navigating AI with a full state machine, difficulty scaling,
## hazard avoidance via raycasting, jump edge detection, and multiplayer bot fill support.

## ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal ai_finished(bot_id: int)
signal ai_fell(bot_id: int)

## ─── STATE MACHINE ───────────────────────────────────────────────────────────
enum AIState {
	IDLE,
	NAVIGATE,
	AVOID_HAZARD,
	JUMPING,
	DIVING,
	RECOVERING,
	FINISHED
}

## ─── EXPORTED TUNABLES ───────────────────────────────────────────────────────
@export var difficulty: int = 1    # 1=Easy, 2=Medium, 3=Hard
@export var reaction_delay: float = 0.3

## ─── RUNTIME VARIABLES ───────────────────────────────────────────────────────
var state: AIState = AIState.NAVIGATE

# Navigation
var waypoints: Array[Vector3] = []

# Bot Identity
var bot_id: int = -1
var bot_username: String = "YetiBot_A"

# Difficulty scaled stats
var move_speed: float = 6.0
var jump_miss_chance: float = 0.30
var dive_chance: float = 0.0

# Physics
var gravity: float = 28.0
var jump_velocity: float = 12.0
var dive_velocity: float = 18.0

# Timers & State vars
var state_timer: float = 0.0
var avoid_dir: Vector3 = Vector3.ZERO
var hazard_check_timer: float = 0.0

var danger_zones: Array[Area3D] = []

# Nodes
var hazard_cast: ShapeCast3D
var edge_cast: RayCast3D
@onready var visuals: Node3D = $Visuals if has_node("Visuals") else self

## ─── LIFECYCLE ───────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("AI_Yeti")
	
	_apply_difficulty()
	
	# Setup Hazard ShapeCast (radius 0.5, length 3m forward, layer 4 mask)
	hazard_cast = ShapeCast3D.new()
	hazard_cast.shape = SphereShape3D.new()
	hazard_cast.shape.radius = 0.5
	hazard_cast.target_position = Vector3(0, 0, -3.0)
	hazard_cast.collision_mask = 1 << 3 # Layer 4 = index 3
	hazard_cast.add_exception(self)
	add_child(hazard_cast)
	
	# Setup Edge Detection RayCast (0.3m ahead at foot level)
	edge_cast = RayCast3D.new()
	edge_cast.position = Vector3(0, 0.5, -0.3) 
	edge_cast.target_position = Vector3(0, -1.0, 0)
	edge_cast.add_exception(self)
	add_child(edge_cast)

func _apply_difficulty() -> void:
	match difficulty:
		1: # Easy
			reaction_delay = 0.5
			move_speed = 6.0
			jump_miss_chance = 0.30
			dive_chance = 0.0
		2: # Medium
			reaction_delay = 0.3
			move_speed = 8.0
			jump_miss_chance = 0.10
			dive_chance = 0.20
		3, _: # Hard
			reaction_delay = 0.1
			move_speed = 9.5
			jump_miss_chance = 0.02
			dive_chance = 0.50

## ─── PUBLIC API ──────────────────────────────────────────────────────────────
func set_waypoints(pts: Array[Vector3]) -> void:
	waypoints = pts.duplicate()
	if waypoints.size() > 0 and state in [AIState.IDLE, AIState.FINISHED]:
		state = AIState.NAVIGATE

func add_danger_zone(area: Area3D) -> void:
	if not danger_zones.has(area):
		danger_zones.append(area)

## ─── PHYSICS LOOP ────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Fall death logic
	if global_position.y < -15.0 and state != AIState.FINISHED:
		ai_fell.emit(bot_id)
		state = AIState.IDLE
		velocity = Vector3.ZERO
		return
		
	match state:
		AIState.IDLE:
			_decelerate_horizontal(delta)
		AIState.NAVIGATE:
			_process_navigate(delta)
			_check_hazards(delta)
			_check_edge(delta)
		AIState.AVOID_HAZARD:
			_process_avoid(delta)
		AIState.JUMPING:
			_process_jumping(delta)
		AIState.DIVING:
			_process_diving(delta)
		AIState.RECOVERING:
			_process_recovering(delta)
		AIState.FINISHED:
			_decelerate_horizontal(delta)
			
	move_and_slide()

## ─── STATE HANDLERS ──────────────────────────────────────────────────────────
func _process_navigate(delta: float) -> void:
	if waypoints.is_empty():
		state = AIState.FINISHED
		ai_finished.emit(bot_id)
		return
		
	var target: Vector3 = waypoints[0]
	var dist: float = global_position.distance_to(target)
	
	# Pop waypoint if within 1.5m
	if dist < 1.5:
		waypoints.pop_front()
		return
		
	# Steer toward target
	var dir: Vector3 = (target - global_position)
	dir.y = 0
	dir = dir.normalized()
	
	# Direct velocity injection (lerp turning implicitly through move_toward logic)
	velocity.x = move_toward(velocity.x, dir.x * move_speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * move_speed, 30.0 * delta)
	
	# Smooth turning
	if dir.length() > 0.1:
		var target_angle = atan2(-dir.x, -dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 10.0 * delta)

func _check_hazards(delta: float) -> void:
	hazard_check_timer -= delta
	if hazard_check_timer <= 0.0:
		hazard_check_timer = 0.1
		
		# Rotate casts to match visual rotation
		hazard_cast.rotation.y = visuals.rotation.y
		hazard_cast.force_shapecast_update()
		
		# 1. Forward ShapeCast Hit
		if hazard_cast.is_colliding():
			_trigger_avoidance()
			return
			
		# 2. Registered Danger Zones Check
		for zone in danger_zones:
			if is_instance_valid(zone) and zone.overlaps_body(self):
				_trigger_avoidance()
				return
				
	# 3. Sphere overlap (boulder detection within 5m) every physics frame
	var space = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 5.0
	params.shape = sphere
	params.transform = global_transform
	# Layer 1 masks generally cover rigid bodies
	params.collision_mask = 0xFFFFFFFF
	
	var results = space.intersect_shape(params)
	for res in results:
		var collider = res.collider
		if collider is Node3D and collider.is_in_group("boulder"):
			var boulder_vel = Vector3.ZERO
			if collider is RigidBody3D:
				boulder_vel = collider.linear_velocity
			
			var dir_to_me = (global_position - collider.global_position).normalized()
			# If boulder is moving fast and approaching the bot
			if boulder_vel.length() > 2.0 and boulder_vel.normalized().dot(dir_to_me) > 0.5:
				_trigger_avoidance(dir_to_me)
				return

func _trigger_avoidance(threat_dir: Vector3 = Vector3.ZERO) -> void:
	state = AIState.AVOID_HAZARD
	state_timer = 0.3 # Strafe perpendicular for 0.3s
	
	var forward = -visuals.global_transform.basis.z
	var dodge_sign = 1.0 if randf() > 0.5 else -1.0
	
	if threat_dir != Vector3.ZERO:
		# Strafe away from the incoming threat
		avoid_dir = threat_dir
		avoid_dir.y = 0
		avoid_dir = avoid_dir.normalized()
	else:
		# Random perpendicular dodge
		avoid_dir = forward.cross(Vector3.UP).normalized() * dodge_sign

func _process_avoid(delta: float) -> void:
	state_timer -= delta
	
	# High speed strafe
	velocity.x = avoid_dir.x * move_speed * 1.5
	velocity.z = avoid_dir.z * move_speed * 1.5
	
	if state_timer <= 0.0:
		state = AIState.NAVIGATE

func _check_edge(_delta: float) -> void:
	if not is_on_floor(): return
	
	edge_cast.rotation.y = visuals.rotation.y
	edge_cast.force_raycast_update()
	
	# If raycast fails to hit ground 0.3m ahead, we are at an edge
	if not edge_cast.is_colliding():
		if randf() > jump_miss_chance:
			_schedule_jump()

func _schedule_jump() -> void:
	state = AIState.JUMPING
	state_timer = reaction_delay

func _process_jumping(delta: float) -> void:
	state_timer -= delta
	
	# Delay executed, perform the jump
	if state_timer <= 0.0:
		if is_on_floor():
			velocity.y = jump_velocity
			
			if randf() < dive_chance:
				# Apply dive velocity boost
				velocity += (-visuals.global_transform.basis.z * dive_velocity * 0.5)
				state = AIState.DIVING
				state_timer = 1.0 # arbitrary max dive flight time
				return
				
		state = AIState.NAVIGATE

func _process_diving(delta: float) -> void:
	state_timer -= delta
	if is_on_floor() or state_timer <= 0.0:
		state = AIState.RECOVERING
		state_timer = 0.5

func _process_recovering(delta: float) -> void:
	_decelerate_horizontal(delta)
	state_timer -= delta
	if state_timer <= 0.0:
		state = AIState.NAVIGATE

func _decelerate_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)

## ─── MULTIPLAYER BOT FILL ────────────────────────────────────────────────────
## Called by GameManager when players < min_players.
static func spawn_ai_bots(count: int, parent: Node) -> void:
	var bot_names = ["YetiBot_A", "YetiBot_B", "YetiBot_C"]
	
	# Fallback if specific YetiAI scene is registered, else assume current logic builds it.
	# We instance the AI controller script attached to a basic body.
	var ai_scene: PackedScene
	var ai_scene_path: String = "res://scenes/gameplay/YetiAI.tscn"
	
	if ResourceLoader.exists(ai_scene_path):
		ai_scene = load(ai_scene_path)
	
	for i in range(count):
		var bot: Node
		if ai_scene:
			bot = ai_scene.instantiate()
			var ai_comp = bot as YetiAIController
			if ai_comp:
				ai_comp.bot_id = -(i + 1)
				ai_comp.bot_username = bot_names[i % bot_names.size()]
			parent.add_child(bot)
		else:
			# Fallback if no scene: just create raw node
			var raw_ai = YetiAIController.new()
			raw_ai.name = "Bot_" + str(i + 1)
			raw_ai.bot_id = -(i + 1)
			raw_ai.bot_username = bot_names[i % bot_names.size()]
			parent.add_child(raw_ai)
