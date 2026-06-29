extends BaseRound

var _hex_tiles: Array[AnimatableBody3D] = []
var _hex_states: Array[int] = [] # 0 = normal, 1 = cracking, 2 = falling, 3 = hidden
var _hex_timers: Array[float] = []
var _hex_respawn_timers: Array[float] = []

# Layer system — up to 5 layers below the main platform
const LAYER_GAP = 6.0   # Vertical distance between each safety layer
const NUM_LAYERS = 4    # Number of safety layers below the top (0 = top, 1-4 = lower layers)

const HEX_RADIUS = 3.0
const HEX_SPACING = 5.5

# Survival timer: player must survive X seconds to unlock the exit
const SURVIVAL_DURATION = 45.0

var _survival_timer: float = SURVIVAL_DURATION
var _finish_zone_active: bool = false
var _survival_hud_label: Label = null

var _avalanche_timer: float = 10.0
var _altitude_sickness_timer: float = 15.0

var _rng = RandomNumberGenerator.new()
var player_ref: CharacterBody3D = null

func _ready() -> void:
	super._ready()
	round_name = "ROUND 5: EVEREST DEATH ZONE"
	round_type = RoundType.SURVIVAL
	yeti_fact_index = 4
	time_limit = 120.0
	_rng.randomize()
	
	var old_geo = get_node_or_null("MapGeometry")
	if old_geo: old_geo.queue_free()
	
	var map_geo = Node3D.new()
	map_geo.name = "MapGeometry"
	add_child(map_geo)
	
	_build_layered_hex_grid(map_geo)
	_spawn_oxygen_tanks(map_geo)
	
	if finish_zone:
		finish_zone.position = Vector3(0, 200.0, 0) # Hidden high above
		finish_zone.monitoring = false
		
	if kill_zone:
		# Lower the kill zone below the bottommost layer (Layer 4 is at Y=-24.0)
		kill_zone.position = Vector3(0, -35.0, 0)
	
	_create_survival_hud()

func _create_survival_hud() -> void:
	if not hud: return
	
	_survival_hud_label = Label.new()
	_survival_hud_label.name = "SurvivalTimer"
	_survival_hud_label.add_theme_font_size_override("font_size", 36)
	_survival_hud_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	_survival_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_survival_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_survival_hud_label.offset_top = 80
	hud.add_child(_survival_hud_label)

func _build_layered_hex_grid(parent: Node3D) -> void:
	var rows = 7
	var cols = 7
	
	# Build the main top layer (layer 0)
	for r in range(rows):
		for c in range(cols):
			var x_offset = (c - cols/2) * HEX_SPACING
			if r % 2 != 0:
				x_offset += HEX_SPACING * 0.5
			var z_offset = (r - rows/2) * HEX_SPACING * 0.866
			_create_hex_tile(parent, Vector3(x_offset, 0.0, z_offset), 0)

	# Build safety layers (layers 1 to NUM_LAYERS) — smaller grids each time
	for layer in range(1, NUM_LAYERS + 1):
		var layer_rows = max(3, rows - layer * 1)
		var layer_cols = max(3, cols - layer * 1)
		var layer_y = -LAYER_GAP * layer
		
		for r in range(layer_rows):
			for c in range(layer_cols):
				var x_offset = (c - layer_cols/2) * HEX_SPACING
				if r % 2 != 0:
					x_offset += HEX_SPACING * 0.5
				var z_offset = (r - layer_rows/2) * HEX_SPACING * 0.866
				_create_hex_tile(parent, Vector3(x_offset, layer_y, z_offset), layer)

func _create_hex_tile(parent: Node3D, pos: Vector3, layer: int) -> void:
	var tile = AnimatableBody3D.new()
	tile.position = pos
	tile.sync_to_physics = true
	
	var mesh = CSGCylinder3D.new()
	mesh.sides = 6
	mesh.radius = HEX_RADIUS
	mesh.height = 1.0
	
	var mat = StandardMaterial3D.new()
	# Color darkens with each layer to give visual depth cue
	var brightness = 1.0 - (layer * 0.15)
	mat.albedo_color = Color(0.5 * brightness, 0.8 * brightness, 1.0 * brightness)
	mat.emission_enabled = true
	mat.emission = Color(0.2 * brightness, 0.5 * brightness, 0.8 * brightness)
	mat.emission_energy_multiplier = 0.2
	mesh.material_override = mat
	tile.add_child(mesh)
	
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = HEX_RADIUS
	cyl.height = 1.0
	col.shape = cyl
	tile.add_child(col)
	
	var stand = Area3D.new()
	stand.collision_mask = 2
	var s_col = CollisionShape3D.new()
	var s_cyl = CylinderShape3D.new()
	s_cyl.radius = HEX_RADIUS * 0.9
	s_cyl.height = 0.5
	s_col.shape = s_cyl
	stand.position = Vector3(0, 0.6, 0)
	stand.add_child(s_col)
	
	var tile_idx = _hex_tiles.size()
	stand.body_entered.connect(_on_hex_stepped.bind(tile_idx))
	tile.add_child(stand)
	
	parent.add_child(tile)
	_hex_tiles.append(tile)
	_hex_states.append(0)
	_hex_timers.append(0.0)
	_hex_respawn_timers.append(0.0)



func _process(delta: float) -> void:
	super._process(delta)
	if round_ended: return
	
	if not is_instance_valid(player_ref):
		if multiplayer.has_multiplayer_peer():
			player_ref = get_node_or_null(str(multiplayer.get_unique_id())) as CharacterBody3D
		else:
			player_ref = get_node_or_null("Player3D") as CharacterBody3D

	_tick_survival(delta)
	_tick_hex_tiles(delta)
	_tick_avalanche(delta)
	_tick_altitude_sickness(delta)

func _tick_survival(delta: float) -> void:
	if round_ended: return
	
	_survival_timer -= delta
	
	# Update HUD countdown label
	if is_instance_valid(_survival_hud_label):
		var secs = max(0, int(ceil(_survival_timer)))
		if secs > 0:
			_survival_hud_label.text = "⏳ SURVIVE: %d seconds" % secs
		else:
			_survival_hud_label.text = "🏆 YOU SURVIVED!"
	
	if _survival_timer <= 0.0:
		if is_instance_valid(player_ref):
			_on_finish_zone_body_entered(player_ref)

func _on_hex_stepped(body: Node3D, idx: int) -> void:
	if body is CharacterBody3D and _hex_states[idx] == 0:
		_hex_states[idx] = 1 # cracking
		_hex_timers[idx] = 1.5
		
		var t = _hex_tiles[idx]
		var m = t.get_child(0) as CSGCylinder3D
		if m and m.material_override:
			var mat = m.material_override.duplicate() as StandardMaterial3D
			mat.albedo_color = Color(1.0, 0.5, 0.5)
			mat.emission = Color(0.8, 0.2, 0.2)
			m.material_override = mat

func _tick_hex_tiles(delta: float) -> void:
	for i in range(_hex_tiles.size()):
		var t = _hex_tiles[i]
		if not is_instance_valid(t): continue
		
		if _hex_states[i] == 1: # Cracking while stood on
			var stand = t.get_child(2) as Area3D
			if not stand: continue
			var has_player = false
			for b in stand.get_overlapping_bodies():
				if b is CharacterBody3D:
					has_player = true
			if has_player:
				_hex_timers[i] -= delta
				if _hex_timers[i] <= 0.0:
					_hex_states[i] = 2 # Falling
					if t.get_child_count() > 1:
						t.get_child(1).disabled = true
					var tw = create_tween()
					tw.tween_property(t, "position:y", t.position.y - 30.0, 0.8).set_trans(Tween.TRANS_SINE)
					tw.tween_callback(func():
						_hex_states[i] = 3
						_hex_respawn_timers[i] = 12.0
					)
		elif _hex_states[i] == 3: # Respawning
			_hex_respawn_timers[i] -= delta
			if _hex_respawn_timers[i] <= 0.0:
				_hex_states[i] = 0
				t.position.y = 0.0 if i < 49 else t.position.y + 30.0 # Restore to original (approx)
				if t.get_child_count() > 1:
					t.get_child(1).disabled = false
				var m = t.get_child(0) as CSGCylinder3D
				if m:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = Color(0.5, 0.8, 1.0)
					mat.emission_enabled = true
					mat.emission = Color(0.2, 0.5, 0.8)
					mat.emission_energy_multiplier = 0.2
					m.material_override = mat

func _tick_avalanche(delta: float) -> void:
	_avalanche_timer -= delta
	if _avalanche_timer <= 0.0:
		_avalanche_timer = 10.0
		var available: Array = []
		for i in range(_hex_tiles.size()):
			if _hex_states[i] == 0:
				available.append(i)
		available.shuffle()
		for i in range(min(3, available.size())):
			var idx = available[i]
			_hex_states[idx] = 1
			_hex_timers[idx] = 0.1

func _tick_altitude_sickness(delta: float) -> void:
	if not is_instance_valid(player_ref): return
	_altitude_sickness_timer -= delta
	if _altitude_sickness_timer <= 0.0:
		_altitude_sickness_timer = 15.0
		if "SPEED" in player_ref:
			var current = player_ref.get("SPEED")
			if current > 3.0:
				player_ref.set("SPEED", max(3.0, current - 0.5))
				if hud:
					var lbl = Label.new()
					lbl.text = "❄️ Altitude Sickness: Speed reduced!"
					lbl.add_theme_font_size_override("font_size", 24)
					lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
					lbl.offset_top = 130
					hud.add_child(lbl)
					get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

func _spawn_oxygen_tanks(parent: Node3D) -> void:
	var mat_green = StandardMaterial3D.new()
	mat_green.albedo_color = Color(0.2, 0.85, 0.2)
	mat_green.emission_enabled = true
	mat_green.emission = Color(0.0, 0.5, 0.0)
	mat_green.emission_energy_multiplier = 0.3
	
	for i in range(3):
		var tank = Area3D.new()
		if _hex_tiles.size() > 0:
			var pos_idx = _rng.randi_range(0, min(48, _hex_tiles.size()-1))
			tank.position = _hex_tiles[pos_idx].position + Vector3(0, 1.5, 0)
		tank.collision_mask = 2
		
		var mesh = CSGCylinder3D.new()
		mesh.radius = 0.35
		mesh.height = 1.0
		mesh.material_override = mat_green
		tank.add_child(mesh)
		
		var col = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.radius = 0.6
		cyl.height = 1.2
		col.shape = cyl
		tank.add_child(col)
		
		tank.body_entered.connect(_on_oxygen_pickup.bind(tank))
		parent.add_child(tank)

func _on_oxygen_pickup(body: Node3D, tank: Area3D) -> void:
	if body is CharacterBody3D:
		if "SPEED" in body:
			body.set("SPEED", 9.0)
		if hud:
			var lbl = Label.new()
			lbl.text = "💨 Oxygen: Speed restored!"
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			lbl.offset_top = 130
			hud.add_child(lbl)
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(lbl): lbl.queue_free())
		if is_instance_valid(tank):
			tank.queue_free()
