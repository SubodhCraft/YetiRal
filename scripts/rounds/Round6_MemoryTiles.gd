extends BaseRound

enum State {
	IDLE,
	MEMORIZE,
	TARGET,
	ELIMINATE,
	RESET,
	FINISHED
}

@export var max_phases: int = 3
@export var base_memorize_time: float = 8.0
@export var base_target_time: float = 7.0
@export var memorize_min_time: float = 3.0

var current_phase: int = 0
var current_state: State = State.IDLE
var state_timer: float = 0.0

var tiles: Array[Node3D] = []
var tile_labels: Array[Label3D] = []
var tile_collisions: Array[CollisionShape3D] = []
var original_tile_y: float

var main_screen: Label3D
var screen_symbol: Label3D = null


@onready var sweeper: Node3D = $Sweeper
var sweeper_speed: float = 0.0
var time_passed: float = 0.0

var target_symbol: String = ""

const SYMBOLS: Dictionary = {
	"OM": "ॐ",
	"DHARMA": "☸",
	"KHUKURI": "⚔",
	"YAK": "🐃",
	"LEOPARD": "🐆",
	"LOTUS": "🪷",
	"TRIDENT": "🔱"
}

const SYMBOL_COLORS: Dictionary = {
	"OM": Color(0.95, 0.8, 0.1),       # gold
	"DHARMA": Color(0.2, 0.4, 0.8),    # blue
	"KHUKURI": Color(0.7, 0.7, 0.75),  # silver
	"YAK": Color(0.5, 0.3, 0.1),       # brown
	"LEOPARD": Color(0.95, 0.95, 0.95),# white
	"LOTUS": Color(0.95, 0.4, 0.6),    # pink
	"TRIDENT": Color(0.8, 0.2, 0.2)    # red
}

var symbol_pool: Array[String] = ["OM", "DHARMA", "KHUKURI", "YAK", "LEOPARD", "LOTUS", "TRIDENT"]
var current_symbols: Array[String] = []

func _ready() -> void:
	super._ready()
	round_name = "ROUND 6: SHERPA'S MEMORY TRAIL"
	round_type = RoundType.MEMORY
	yeti_fact_index = 5
	time_limit = 120.0
	
	main_screen = get_node_or_null("MapGeometry/Screen/ScreenLabel")
	
	var tiles_parent = get_node_or_null("Tiles")
	if tiles_parent:
		for child in tiles_parent.get_children():
			if child is AnimatableBody3D:
				if tiles.size() < 6:
					tiles.append(child)
					
					# Clean up old nodes if present
					var old_label = child.get_node_or_null("Label3D")
					if old_label: old_label.queue_free()
					for c in child.get_children():
						if c is Sprite3D: c.queue_free()
					
					var lbl = Label3D.new()
					lbl.font_size = 96
					lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
					lbl.rotation_degrees = Vector3(-90, 0, 0)
					lbl.position = Vector3(0, 0.32, 0)
					lbl.outline_size = 8
					lbl.visible = false
					child.add_child(lbl)
					tile_labels.append(lbl)
					
					var col = child.get_node_or_null("CollisionShape3D")
					if col:
						tile_collisions.append(col)
				else:
					child.queue_free()
	
	if tiles.size() > 0:
		original_tile_y = tiles[0].global_position.y
		
		var spacing_x = 5.0
		var spacing_z = 5.0
		var cols = 3
		var rows = 2
		var offset_x = (cols - 1) * spacing_x / 2.0
		var offset_z = (rows - 1) * spacing_z / 2.0
		
		for i in range(tiles.size()):
			var c = i % cols
			var r = i / cols
			tiles[i].global_position = Vector3(c * spacing_x - offset_x, original_tile_y, r * spacing_z - offset_z)

	if sweeper:
		sweeper.global_position = Vector3(0, original_tile_y + 0.5, 0)
		for child in sweeper.get_children():
			child.queue_free()
			
		var arm1 = CSGBox3D.new()
		arm1.size = Vector3(14.0, 0.5, 0.5)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.1, 0.1)
		arm1.material_override = mat
		sweeper.add_child(arm1)
		
		var arm2 = CSGBox3D.new()
		arm2.size = Vector3(0.5, 0.5, 14.0)
		arm2.material_override = mat
		sweeper.add_child(arm2)
		
		var sweep_area = Area3D.new()
		sweep_area.collision_mask = 2
		var sweep_col = CollisionShape3D.new()
		var sweep_shape = BoxShape3D.new()
		sweep_shape.size = Vector3(14.0, 0.6, 0.6)
		sweep_col.shape = sweep_shape
		sweep_area.add_child(sweep_col)
		var sweep_col2 = CollisionShape3D.new()
		var sweep_shape2 = BoxShape3D.new()
		sweep_shape2.size = Vector3(0.6, 0.6, 14.0)
		sweep_col2.shape = sweep_shape2
		sweep_area.add_child(sweep_col2)
		sweeper.add_child(sweep_area)
		
		sweep_area.body_entered.connect(func(body):
			if body is CharacterBody3D:
				var push_dir = (body.global_position - sweeper.global_position).normalized()
				push_dir.y = 0.5
				body.velocity = push_dir * 15.0
		)

	var screen_node = get_node_or_null("MapGeometry/Screen")
	if screen_node:
		screen_symbol = Label3D.new()
		screen_symbol.font_size = 180
		screen_symbol.outline_size = 12
		screen_symbol.position = Vector3(0, -1.0, 0.55)
		screen_symbol.visible = false
		screen_node.add_child(screen_symbol)

	_change_state(State.IDLE, 3.0)
	if main_screen:
		main_screen.text = "GET READY!"

func _process(delta: float) -> void:
	super._process(delta)
	

	if current_state == State.FINISHED:
		sweeper_speed = 0.0
	
	if sweeper and sweeper_speed > 0.0:
		sweeper.rotation.y += sweeper_speed * delta
		
	time_passed += delta
	# Undulate tiles
	for i in range(tiles.size()):
		if tiles[i].visible and current_state != State.ELIMINATE:
			tiles[i].global_position.y = original_tile_y + sin(time_passed * 2.0 + i) * 0.2

	if current_state == State.FINISHED:
		return
		
	if state_timer > 0.0:
		state_timer -= delta
		if state_timer <= 0.0:
			_on_state_timeout()

func _change_state(new_state: State, time: float) -> void:
	current_state = new_state
	state_timer = time

func _on_state_timeout() -> void:
	match current_state:
		State.IDLE:
			_start_memorize()
		State.MEMORIZE:
			_start_target()
		State.TARGET:
			_start_eliminate()
		State.ELIMINATE:
			_start_reset()
		State.RESET:
			current_phase += 1
			if current_phase >= max_phases:
				_finish_round()
			else:
				_start_memorize()

func _start_memorize() -> void:
	sweeper_speed = 0.5 + (current_phase * 0.2)
	var available_symbols = symbol_pool.duplicate()
	available_symbols.shuffle()
	
	current_symbols.clear()
	for i in range(tiles.size()):
		var sym = available_symbols[i % available_symbols.size()]
		current_symbols.append(sym)
	
	target_symbol = current_symbols[randi() % current_symbols.size()]
	
	for i in range(tiles.size()):
		if i >= tile_labels.size():
			break
		var sym = current_symbols[i]
		var lbl = tile_labels[i]
		
		lbl.text = SYMBOLS.get(sym, "?")
		lbl.modulate = SYMBOL_COLORS.get(sym, Color.WHITE)
		lbl.visible = true

		var mesh = tiles[i].get_node_or_null("MeshInstance3D")
		if mesh:
			var mat = StandardMaterial3D.new()
			# Subtle tint on the floor
			mat.albedo_color = SYMBOL_COLORS.get(sym, Color.WHITE).lerp(Color.WHITE, 0.5)
			mat.roughness = 0.5
			mesh.set_surface_override_material(0, mat)

		tiles[i].visible = true
		tiles[i].global_position.y = original_tile_y
		if i < tile_collisions.size() and tile_collisions[i]:
			tile_collisions[i].disabled = false

	if main_screen:
		main_screen.text = "MEMORISE! 👀"
		
	var mem_time = max(memorize_min_time, base_memorize_time - (current_phase * 0.8))
	_change_state(State.MEMORIZE, mem_time)

func _start_target() -> void:
	sweeper_speed = 0.8 + (current_phase * 0.3)
	for lbl in tile_labels:
		lbl.visible = false

	if main_screen:
		main_screen.text = "STAND ON:"

	if screen_symbol:
		screen_symbol.text = SYMBOLS.get(target_symbol, "?")
		screen_symbol.modulate = SYMBOL_COLORS.get(target_symbol, Color.WHITE)
		screen_symbol.visible = true
	
	var tgt_time = max(2.5, base_target_time - (current_phase * 0.5))
	_change_state(State.TARGET, tgt_time)

func _start_eliminate() -> void:
	sweeper_speed = 1.0 + (current_phase * 0.4)
	if main_screen:
		main_screen.text = "ELIMINATION! 💀"

	if screen_symbol:
		screen_symbol.visible = false

	for i in range(tiles.size()):
		if current_symbols[i] != target_symbol:
			var tile = tiles[i]
			if i < tile_collisions.size() and tile_collisions[i]:
				tile_collisions[i].disabled = true
			var tw = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(tile, "global_position:y", tile.global_position.y - 30.0, 0.8)
			tw.tween_callback(tile.hide)
		
	_change_state(State.ELIMINATE, 2.5)

func _start_reset() -> void:
	if main_screen:
		main_screen.text = "NEXT ROUND..."

	for i in range(tiles.size()):
		tiles[i].global_position.y = original_tile_y
		tiles[i].visible = true
		if i < tile_collisions.size() and tile_collisions[i]:
			tile_collisions[i].disabled = false
		var mesh = tiles[i].get_node_or_null("MeshInstance3D")
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.8, 0.8)
			mat.roughness = 0.5
			mesh.set_surface_override_material(0, mat)
		if i < tile_labels.size():
			tile_labels[i].visible = false
		
	_change_state(State.RESET, 2.0)

func _finish_round() -> void:
	current_state = State.FINISHED
	if main_screen:
		main_screen.text = "SURVIVED! 🎉"

	for child in get_children():
		if child is CharacterBody3D:
			# Auto transfer the user by triggering the finish zone logic from BaseRound
			_on_finish_zone_body_entered(child)
