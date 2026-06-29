extends Node

# VFXManager.gd
# Autoload singleton handling global visual effects (CPUParticles).

# EFFECT 1 — SNOW AMBIENCE
func spawn_snow_ambience(center: Vector3, radius: float, parent: Node) -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	var mesh = QuadMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 200
	particles.lifetime = 4.0
	particles.one_shot = false
	particles.direction = Vector3(0, -1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.08
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	
	parent.add_child(particles)
	particles.global_position = center
	return particles

# EFFECT 2 — MOMO COLLECT BURST
func play_momo_collect(world_pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	var mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4) # yellow-cream
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mesh.radius = 0.05
	mesh.height = 0.1
	
	particles.mesh = mesh
	particles.amount = 15
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0 # burst
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0, -2, 0)
	
	add_child(particles)
	particles.global_position = world_pos
	
	_schedule_free(particles, 2.0)

# EFFECT 3 — RAGDOLL IMPACT STARS
func play_ragdoll_stars(world_pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	var mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mesh.radius = 0.04
	mesh.height = 0.08
	
	particles.mesh = mesh
	particles.amount = 8
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	
	add_child(particles)
	particles.global_position = world_pos
	
	_schedule_free(particles, 1.0)

# EFFECT 4 — VICTORY FIREWORKS (2D, screen-space)
func play_victory_fireworks() -> void:
	var colors = [Color(0.86, 0.08, 0.24), Color.WHITE, Color(0.0, 0.36, 0.73)]
	
	# Use a CanvasLayer to ensure they render in screen-space above everything
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0: viewport_size = Vector2(1920, 1080)
	
	for i in range(5):
		var particles = CPUParticles2D.new()
		particles.amount = 200
		particles.lifetime = 2.0
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.spread = 180.0
		particles.initial_velocity_min = 100.0
		particles.initial_velocity_max = 300.0
		particles.gravity = Vector2(0, 200)
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 8.0
		particles.color = colors[randi() % colors.size()]
		particles.emitting = false # Will enable via tween/timer
		
		var rx = randf_range(viewport_size.x * 0.1, viewport_size.x * 0.9)
		var ry = randf_range(viewport_size.y * 0.1, viewport_size.y * 0.6)
		particles.position = Vector2(rx, ry)
		
		canvas.add_child(particles)
		
		# Stagger them slightly
		get_tree().create_timer(randf_range(0.0, 1.0)).timeout.connect(func():
			if is_instance_valid(particles):
				particles.emitting = true
		)
		
	# Queue free the entire canvas after 3 seconds (2s life + 1s max stagger)
	_schedule_free(canvas, 3.5)

# EFFECT 5 — PLATFORM CRACK
func play_platform_crack(world_pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 20
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 8.0
	
	add_child(particles)
	particles.global_position = world_pos
	
	_schedule_free(particles, 1.5)

# EFFECT 6 — WIND UPWARD STREAM
func play_wind_upward(world_pos: Vector3, duration: float) -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	var mesh = QuadMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6) # blue-white
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.amount = 75 # 50/s for 1.5s lifetime
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 15.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	
	add_child(particles)
	particles.global_position = world_pos
	
	if duration > 0.0:
		_schedule_free(particles, duration)
		
	return particles

# Utility
func _schedule_free(node: Node, delay: float) -> void:
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)
