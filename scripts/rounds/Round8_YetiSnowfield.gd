extends BaseRound

var crown_holder: CharacterBody3D = null
var crown_timer: float = 30.0
var crown_label: Label3D = null
var _crown_area: Area3D = null
var yeti_ai: CharacterBody3D = null

var _boulder_timer: float = 5.0
var _boulder_spawn_x: float = 0.0

const SLIPPERY_SCRIPT = preload("res://scripts/rounds/SlipperyZone.gd")
const WIND_SCRIPT = preload("res://scripts/rounds/WindTunnel.gd")

func _ready() -> void:
	super._ready()
	round_name = "ROUND 8: YETI'S SACRED SNOWFIELD"
	round_type = RoundType.FINAL
	yeti_fact_index = 7
	time_limit = 120.0
	
	_build_mountain()
	_spawn_crown()
	_setup_yeti_ai()

func _build_mountain() -> void:
	var map_geo = Node3D.new()
	map_geo.name = "MapGeometry"
	add_child(map_geo)
	
	var mat_ice = StandardMaterial3D.new()
	mat_ice.albedo_color = Color(0.6, 0.8, 0.9)
	mat_ice.emission_enabled = true
	mat_ice.emission = Color(0.2, 0.4, 0.6)
	mat_ice.emission_energy_multiplier = 0.5
	
	# Base
	var base = CSGCylinder3D.new()
	base.radius = 25.0
	base.height = 4.0
	base.position = Vector3(0, -2.0, 0)
	base.use_collision = true
	base.material_override = mat_ice
	map_geo.add_child(base)
	
	# Tiers
	for i in range(4):
		var tier = CSGCylinder3D.new()
		tier.radius = 20.0 - (i * 4.0)
		tier.height = 3.0
		tier.position = Vector3(0, (i * 3.0) + 1.5, 0)
		tier.use_collision = true
		tier.material_override = mat_ice
		map_geo.add_child(tier)
		
		# Slopes (Ramps between tiers)
		var ramp = CSGBox3D.new()
		ramp.size = Vector3(4.0, 1.0, 8.0)
		var angle = i * PI / 2.0
		var r_pos = Vector3(cos(angle), 0, sin(angle)) * (tier.radius + 1.0)
		ramp.position = r_pos + Vector3(0, (i * 3.0), 0)
		ramp.rotation.y = -angle
		ramp.rotation.x = PI / 6.0
		ramp.use_collision = true
		ramp.material_override = mat_ice
		map_geo.add_child(ramp)
		
		var slip = Area3D.new()
		slip.set_script(SLIPPERY_SCRIPT)
		slip.set("slide_factor", 0.25)
		slip.position = ramp.position
		slip.rotation = ramp.rotation
		var s_col = CollisionShape3D.new()
		var s_box = BoxShape3D.new()
		s_box.size = Vector3(4.0, 1.0, 8.0)
		s_col.shape = s_box
		slip.add_child(s_col)
		map_geo.add_child(slip)

	# Wind Zones
	for i in range(3):
		var wind = Area3D.new()
		wind.set_script(WIND_SCRIPT)
		wind.set("lift_force", 15.0)
		var angle = i * (PI * 2.0 / 3.0)
		wind.position = Vector3(cos(angle) * 15.0, 4.0, sin(angle) * 15.0)
		var wc = CollisionShape3D.new()
		var ws = BoxShape3D.new()
		ws.size = Vector3(6, 10, 6)
		wc.shape = ws
		wind.add_child(wc)
		map_geo.add_child(wind)
		
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(6, 10, 6)
		mi.mesh = bm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.9, 1.0, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		wind.add_child(mi)

func _spawn_crown() -> void:
	_crown_area = Area3D.new()
	_crown_area.position = Vector3(0, 14.0, 0)
	_crown_area.collision_mask = 2 # Player
	
	var mesh = CSGSphere3D.new()
	mesh.radius = 0.8
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	_crown_area.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	_crown_area.add_child(col)
	
	_crown_area.body_entered.connect(_on_crown_touched)
	add_child(_crown_area)
	
	crown_label = Label3D.new()
	crown_label.font_size = 96
	crown_label.outline_size = 8
	crown_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crown_label.position = Vector3(0, 1.5, 0)
	crown_label.visible = false
	add_child(crown_label)

func _setup_yeti_ai() -> void:
	var ai_scene = load("res://scenes/gameplay/YetiAI.tscn")
	if ai_scene:
		yeti_ai = ai_scene.instantiate()
		yeti_ai.position = Vector3(0, 1.0, -20.0)
		add_child(yeti_ai)

func _on_crown_touched(body: Node3D) -> void:
	if round_ended: return
	if body is CharacterBody3D and body != crown_holder:
		_assign_crown(body)

func _assign_crown(player: CharacterBody3D) -> void:
	crown_holder = player
	crown_timer = 30.0
	
	_crown_area.get_parent().remove_child(_crown_area)
	player.add_child(_crown_area)
	_crown_area.position = Vector3(0, 1.5, 0)
	
	crown_label.get_parent().remove_child(crown_label)
	player.add_child(crown_label)
	crown_label.position = Vector3(0, 2.5, 0)
	crown_label.visible = true

func _drop_crown() -> void:
	if crown_holder:
		crown_holder.remove_child(_crown_area)
		add_child(_crown_area)
		_crown_area.position = Vector3(0, 14.0, 0) # Back to summit
		
		crown_holder.remove_child(crown_label)
		add_child(crown_label)
		crown_label.visible = false
		
		crown_holder = null

func _process(delta: float) -> void:
	super._process(delta)
	if round_ended: return
	
	_tick_boulders(delta)
	_tick_yeti(delta)
	
	if crown_holder:
		crown_timer -= delta
		crown_label.text = str(int(ceil(crown_timer)))
		if crown_timer <= 0.0:
			_win_cinematic()
	
	# Check for player-to-player steal
	if crown_holder:
		var players = get_tree().get_nodes_in_group("Players")
		for p in players:
			if p != crown_holder and p is CharacterBody3D:
				if p.global_position.distance_to(crown_holder.global_position) < 2.0:
					_assign_crown(p)
					break

func _tick_boulders(delta: float) -> void:
	_boulder_timer -= delta
	if _boulder_timer <= 0.0:
		_boulder_timer = 5.0
		var boulder = RigidBody3D.new()
		boulder.position = Vector3(randf_range(-15, 15), 20.0, randf_range(-15, 15))
		boulder.mass = 20.0
		var mesh = CSGSphere3D.new()
		mesh.radius = 2.0
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.9, 1.0)
		mesh.material_override = mat
		boulder.add_child(mesh)
		var col = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 2.0
		col.shape = shape
		boulder.add_child(col)
		add_child(boulder)
		
		get_tree().create_timer(10.0).timeout.connect(func(): if is_instance_valid(boulder): boulder.queue_free())

func _tick_yeti(delta: float) -> void:
	if is_instance_valid(yeti_ai):
		if crown_holder:
			if yeti_ai.has_method("set_target_position"):
				yeti_ai.set_target_position(crown_holder.global_position)
			
			if yeti_ai.global_position.distance_to(crown_holder.global_position) < 3.0:
				var push = (crown_holder.global_position - yeti_ai.global_position).normalized()
				push.y = 1.0
				crown_holder.velocity = push * 20.0
				if crown_holder.has_method("become_ragdoll"):
					crown_holder.become_ragdoll(2.0)
				_drop_crown()
		else:
			if yeti_ai.has_method("set_target_position"):
				yeti_ai.set_target_position(Vector3(0, 14, 0)) # Go to summit

func _win_cinematic() -> void:
	round_ended = true
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if p is CharacterBody3D:
			p.set_physics_process(false)
			p.set_process_input(false)
			p.velocity = Vector3.ZERO
	
	if is_instance_valid(yeti_ai):
		yeti_ai.set_physics_process(false)
		
	var cam = get_viewport().get_camera_3d()
	if cam and crown_holder:
		var tw = create_tween()
		tw.tween_property(cam, "global_position", crown_holder.global_position + Vector3(0, 2, 5), 2.0)
		cam.look_at(crown_holder.global_position + Vector3(0, 1, 0))
		
	crown_label.text = "CHAMPION!"
	crown_label.modulate = Color(1.0, 0.8, 0.2)
	
	get_tree().create_timer(3.0).timeout.connect(func():
		_show_yeti_fact_then(func(): 
			if GameManager.is_multiplayer:
				pass # Multi logic
			else:
				GameManager.show_victory()
		)
	)
