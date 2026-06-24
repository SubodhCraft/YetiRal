extends BaseRound

enum State {
	IDLE,
	MEMORIZE,
	TARGET,
	ELIMINATE,
	RESET,
	FINISHED
}

@export var max_phases: int = 5
@export var base_memorize_time: float = 8.0   ## Increased from 4.0 — gives players time to scan images
@export var base_target_time: float = 7.0
@export var memorize_min_time: float = 3.0    ## Never drops below this even at late phases

var current_phase: int = 0
var current_state: State = State.IDLE
var state_timer: float = 0.0

var tiles: Array[Node3D] = []
var tile_sprites: Array[Sprite3D] = []
var tile_collisions: Array[CollisionShape3D] = []
var original_tile_y: float

var main_screen: Label3D
var screen_sprite: Sprite3D = null  ## Shows target fruit image on the big screen

var target_fruit: String = ""

## Fruit name -> SVG asset path mapping
const FRUIT_ASSETS: Dictionary = {
	"APPLE":  "res://assets/fruits/apple.svg",
	"BANANA": "res://assets/fruits/banana.svg",
	"CHERRY": "res://assets/fruits/cherry.svg",
	"ORANGE": "res://assets/fruits/orange.svg",
	"GRAPE":  "res://assets/fruits/grape.svg",
	"MELON":  "res://assets/fruits/melon.svg",
	"KIWI":   "res://assets/fruits/kiwi.svg",
	"LEMON":  "res://assets/fruits/lemon.svg",
	"PEACH":  "res://assets/fruits/peach.svg",
}

## Tile colour palette — each fruit gets a distinctive background colour
const FRUIT_COLORS: Dictionary = {
	"APPLE":  Color(0.95, 0.25, 0.20),
	"BANANA": Color(0.98, 0.90, 0.15),
	"CHERRY": Color(0.85, 0.10, 0.35),
	"ORANGE": Color(1.00, 0.55, 0.05),
	"GRAPE":  Color(0.55, 0.15, 0.75),
	"MELON":  Color(0.20, 0.75, 0.35),
	"KIWI":   Color(0.45, 0.65, 0.15),
	"LEMON":  Color(0.95, 0.92, 0.10),
	"PEACH":  Color(1.00, 0.60, 0.45),
}

var fruit_pool: Array[String] = ["APPLE", "BANANA", "CHERRY", "ORANGE", "GRAPE", "MELON", "KIWI", "LEMON", "PEACH"]
var current_fruits: Array[String] = []

func _ready() -> void:
	super._ready()
	round_name = "ROUND 6: MEMORY TILES"
	
	main_screen = get_node_or_null("MapGeometry/Screen/ScreenLabel")
	
	var tiles_parent = get_node_or_null("Tiles")
	if tiles_parent:
		for child in tiles_parent.get_children():
			if child is AnimatableBody3D:
				tiles.append(child)
				
				# ── Hide the old text Label3D ──────────────────────────────
				var old_label = child.get_node_or_null("Label3D")
				if old_label:
					old_label.visible = false
				
				# ── Create a Sprite3D for the fruit image ──────────────────
				var spr = Sprite3D.new()
				spr.pixel_size = 0.012       # scales 256px SVG to ≈3m tile
				spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				# Lay flat on tile top face, facing upward
				spr.position = Vector3(0, 0.32, 0)
				spr.rotation_degrees = Vector3(-90, 0, 0)
				spr.visible = false
				child.add_child(spr)
				tile_sprites.append(spr)
				
				var col = child.get_node_or_null("CollisionShape3D")
				if col:
					tile_collisions.append(col)
	
	if tiles.size() > 0:
		original_tile_y = tiles[0].global_position.y

	# ── Add a Sprite3D on the big screen for the target fruit image ────────────
	var screen_node = get_node_or_null("MapGeometry/Screen")
	if screen_node:
		screen_sprite = Sprite3D.new()
		screen_sprite.pixel_size = 0.020
		screen_sprite.position = Vector3(0, 1.5, 0.55)   # slightly in front of screen face
		screen_sprite.visible = false
		screen_node.add_child(screen_sprite)

	# Start the game loop after a short delay
	_change_state(State.IDLE, 3.0)
	if main_screen:
		main_screen.text = "GET READY!"

func _process(delta: float) -> void:
	super._process(delta)
	
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
	# Shuffle fruits and assign
	var available_fruits = fruit_pool.duplicate()
	available_fruits.shuffle()
	
	current_fruits.clear()
	for i in range(tiles.size()):
		var f = available_fruits[i % available_fruits.size()]
		current_fruits.append(f)
	
	# Pick target fruit from those currently on the board
	target_fruit = current_fruits[randi() % current_fruits.size()]
	
	# Apply fruit image + colour to each tile
	for i in range(tiles.size()):
		if i >= tile_sprites.size():
			break
		var f = current_fruits[i]
		var spr = tile_sprites[i]
		
		# Load SVG texture
		var tex = load(FRUIT_ASSETS.get(f, ""))
		if tex:
			spr.texture = tex
		spr.visible = true

		# Colour the tile mesh for instant visual cue
		var mesh = tiles[i].get_node_or_null("MeshInstance3D")
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = FRUIT_COLORS.get(f, Color.WHITE)
			mat.roughness = 0.5
			mesh.set_surface_override_material(0, mat)

		# Make sure tile is visible and at correct Y
		tiles[i].visible = true
		tiles[i].global_position.y = original_tile_y
		if i < tile_collisions.size() and tile_collisions[i]:
			tile_collisions[i].disabled = false

	if main_screen:
		main_screen.text = "MEMORISE! 👀"
		
	# Decrease time per phase but never below minimum
	var mem_time = max(memorize_min_time, base_memorize_time - (current_phase * 0.8))
	_change_state(State.MEMORIZE, mem_time)

func _start_target() -> void:
	# Hide images on tiles (flip face down)
	for spr in tile_sprites:
		spr.visible = false

	# Show target fruit on the big screen
	if main_screen:
		main_screen.text = "STAND ON:"

	if screen_sprite:
		var tex = load(FRUIT_ASSETS.get(target_fruit, ""))
		if tex:
			screen_sprite.texture = tex
		screen_sprite.visible = true
	
	var tgt_time = max(2.5, base_target_time - (current_phase * 0.5))
	_change_state(State.TARGET, tgt_time)

func _start_eliminate() -> void:
	if main_screen:
		main_screen.text = "ELIMINATION! 💀"

	# Hide screen fruit image
	if screen_sprite:
		screen_sprite.visible = false

	# Animate incorrect tiles falling then disappearing
	for i in range(tiles.size()):
		if current_fruits[i] != target_fruit:
			var tile = tiles[i]
			# Disable collision immediately so the player falls
			if i < tile_collisions.size() and tile_collisions[i]:
				tile_collisions[i].disabled = true
			# Tween tile downward then hide it — never leaves a visible ghost
			var tw = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(tile, "global_position:y", original_tile_y - 30.0, 0.8)
			tw.tween_callback(tile.hide)
		
	_change_state(State.ELIMINATE, 2.5)

func _start_reset() -> void:
	if main_screen:
		main_screen.text = "NEXT ROUND..."

	# Restore all tiles instantly at correct Y then show them
	for i in range(tiles.size()):
		tiles[i].global_position.y = original_tile_y
		tiles[i].visible = true
		if i < tile_collisions.size() and tile_collisions[i]:
			tile_collisions[i].disabled = false
		# Reset tile mesh colour back to neutral
		var mesh = tiles[i].get_node_or_null("MeshInstance3D")
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.8, 0.8)
			mat.roughness = 0.5
			mesh.set_surface_override_material(0, mat)
		# Hide sprite until next memorise phase
		if i < tile_sprites.size():
			tile_sprites[i].visible = false
		
	_change_state(State.RESET, 2.0)

func _finish_round() -> void:
	current_state = State.FINISHED
	if main_screen:
		main_screen.text = "SURVIVED! 🎉\nGO TO FINISH"

	# Enable a finish bridge or teleport finish zone
	var finish_bridge = get_node_or_null("MapGeometry/FinishBridge")
	if finish_bridge:
		finish_bridge.visible = true
		finish_bridge.use_collision = true
