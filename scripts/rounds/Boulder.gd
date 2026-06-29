extends RigidBody3D

@export var life_span: float = 12.0

func _ready():
	# Enable Jolt CCD (Continuous Collision Detection) to prevent tunneling
	continuous_cd = true
	
	# Configure physics material programmatically for rolling and minor bounces
	if not physics_material_override:
		var mat = PhysicsMaterial.new()
		mat.friction = 0.8
		mat.bounce = 0.2
		physics_material_override = mat
		
	if multiplayer.has_multiplayer_peer():
		var sync = MultiplayerSynchronizer.new()
		var config = SceneReplicationConfig.new()
		config.add_property(^".:position")
		config.add_property(^".:rotation")
		config.add_property(^".:linear_velocity")
		config.add_property(^".:angular_velocity")
		sync.replication_config = config
		add_child(sync)

	body_entered.connect(_on_body_entered)
	
	await get_tree().create_timer(life_span).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(_delta: float) -> void:
	# Only the server should manage physics destruction
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	# Fallback coordinate cleanup to keep the level clean
	if global_position.y < -20.0:
		queue_free()

func _on_body_entered(body: Node):
	if body.has_method("trigger_yeti_ragdoll"):
		var knockback_direction = (body.global_position - global_position).normalized()
		# Add a slight vertical lift to make the knockback satisfying
		knockback_direction.y = 0.4
		knockback_direction = knockback_direction.normalized()
		body.trigger_yeti_ragdoll(knockback_direction * 18.0)
