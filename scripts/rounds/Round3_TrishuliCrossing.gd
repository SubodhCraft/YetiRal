extends BaseRound

@export var boat_speed: float = 2.5        ## Forward speed of boats (Z direction)
@export var boat_sway_amplitude: float = 1.8   ## Lateral sway amount (X) - reduced slightly to keep jumps clean
@export var boat_sway_speed: float = 0.6       ## How fast boats sway left-right

@export var num_boats: int = 18                ## Spawn 18 boats to cover the 190m river
@export var boat_spacing: float = 10.5         ## Spacing of 10.5m guarantees small, jumpable gaps
@export var boat_start_z: float = -20.0
@export var boat_drift_range: float = 190.0

@export var croc_patrol_speed: float = 1.2
@export var croc_patrol_amplitude: float = 3.5

var boats: Array[AnimatableBody3D] = []
var boat_start_positions: Array[Vector3] = []
var croc_zones: Array[Area3D] = []
var croc_start_positions: Array[Vector3] = []

# Warning label injected into HUD at runtime
var croc_warning_label: Label = null

func _ready() -> void:
	super._ready()
	round_name = "ROUND 3: TRISHULI CROSSING"

	# ── Collect and duplicate template boat ───────────────────────────────────
	var boats_parent = get_node_or_null("Boats")
	if boats_parent:
		var template_boat = boats_parent.get_node_or_null("Boat1")
		if template_boat:
			# Remove all other pre-placed editor boats to prevent duplicate clutter
			for child in boats_parent.get_children():
				if child != template_boat:
					child.queue_free()
			
			boats.clear()
			boat_start_positions.clear()
			
			# Dynamically duplicate the template boat and stagger them
			for i in range(num_boats):
				var boat: AnimatableBody3D
				if i == 0:
					boat = template_boat
				else:
					boat = template_boat.duplicate()
					boats_parent.add_child(boat)
				
				# Alternate starting X lanes (zig-zag pattern)
				var start_x = -2.5 if (i % 2 == 0) else 2.5
				boat.global_position = Vector3(start_x, -0.7, boat_start_z)
				
				boats.append(boat)
				boat_start_positions.append(boat.global_position)

	# ── Collect croc hazard zones ──────────────────────────────────────────────
	var hazards_parent = get_node_or_null("CrocHazards")
	if hazards_parent:
		for child in hazards_parent.get_children():
			if child is Area3D:
				croc_zones.append(child)
				croc_start_positions.append(child.global_position)
				child.body_entered.connect(_on_croc_entered)

	# ── Water kill zone ────────────────────────────────────────────────────────
	var water_kill = get_node_or_null("WaterKillZone")
	if water_kill:
		water_kill.body_entered.connect(_on_water_entered)

	# ── Create warning label on HUD ─────────────────────────────────────────
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if hud:
			croc_warning_label = Label.new()
			croc_warning_label.text = "🐊 CROCODILE! Get to a BOAT! 🐊"
			croc_warning_label.add_theme_font_size_override("font_size", 30)
			croc_warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.1))
			croc_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			croc_warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			croc_warning_label.offset_top = 120
			croc_warning_label.offset_bottom = 160
			hud.add_child(croc_warning_label)
			croc_warning_label.hide()
	)

func _physics_process(delta: float) -> void:
	var time_sec = Time.get_ticks_msec() / 1000.0

	# ── Animate boats: sway laterally + slow drift forward ───────────────────
	for i in range(boats.size()):
		var boat: AnimatableBody3D = boats[i]
		if not is_instance_valid(boat):
			continue

		var start_pos: Vector3 = boat_start_positions[i]
		var phase: float = i * 1.2  # stagger phase per boat
		var sway_x: float = sin(time_sec * boat_sway_speed + phase) * boat_sway_amplitude

		# Boats drift slowly forward, wrapping around individually using fmod
		var drift_z: float = fmod(time_sec * boat_speed * 0.5 + float(i) * boat_spacing, boat_drift_range)
		var target_pos: Vector3 = start_pos + Vector3(sway_x, 0.0, -drift_z)

		boat.global_position = target_pos

	# ── Animate crocodiles: patrol left-right ─────────────────────────────────
	for i in range(croc_zones.size()):
		var croc = croc_zones[i]
		if not is_instance_valid(croc):
			continue
		var start_pos = croc_start_positions[i]
		var phase = i * 1.5
		var offset_x = sin(time_sec * croc_patrol_speed + phase) * croc_patrol_amplitude
		croc.global_position = start_pos + Vector3(offset_x, 0.0, 0.0)

func _on_water_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_handle_player_hazard(body)

func _on_croc_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		# Flash warning
		if croc_warning_label:
			croc_warning_label.show()
			get_tree().create_timer(2.5).timeout.connect(func():
				if is_instance_valid(croc_warning_label):
					croc_warning_label.hide()
			)
		_handle_player_hazard(body)

func _handle_player_hazard(body: CharacterBody3D) -> void:
	if GameManager.is_multiplayer and multiplayer.has_multiplayer_peer():
		if body.is_multiplayer_authority():
			body.global_position = spawn_point.global_position
			body.velocity = Vector3.ZERO
	else:
		if GameManager:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			GameManager.lose_life()
