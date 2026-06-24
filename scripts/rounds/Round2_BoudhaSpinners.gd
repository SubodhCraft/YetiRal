extends BaseRound

@export var base_spin_speed: float = 1.8

var spinner_nodes: Array[Node3D] = []

func _ready() -> void:
	super._ready()
	round_name = "ROUND 2: BOUDHA SPINNERS"
	
	# Find all spinner nodes in the level
	var spinners_parent = get_node_or_null("Spinners")
	if spinners_parent:
		for child in spinners_parent.get_children():
			if child is Node3D:
				spinner_nodes.append(child)

func _process(delta: float) -> void:
	super._process(delta)
	
	# Rotate spinners
	for i in range(spinner_nodes.size()):
		var spinner = spinner_nodes[i]
		if is_instance_valid(spinner):
			# Alternate rotation directions for variance
			var direction = -1.0 if (i % 2 == 0) else 1.0
			var speed = base_spin_speed * (1.0 + (i * 0.15)) # slight speed variations
			spinner.rotate_y(direction * speed * delta)
			
	# Fallback: if player somehow bypasses the FinishZone trigger, detect by Z position
	for child in get_children():
		if child is CharacterBody3D and child.global_position.z < -100.0 and child.global_position.y > -2.0:
			# Ensure we only trigger if they haven't been frozen yet
			if child.has_method("set_physics_process") and child.is_physics_processing():
				_on_finish_zone_body_entered(child)
