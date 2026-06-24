extends BaseRound

const NUM_ROOMS = 5

var safe_paths: Array[int] = [] # 0 for left, 1 for right
var doors_opened: Dictionary = {}

func _ready() -> void:
	super._ready()
	round_name = "ROUND 7: LAVA DOORS"
	
	# Generate random paths
	for i in range(NUM_ROOMS):
		safe_paths.append(randi() % 2)
		
	# Setup bridges and doors
	for i in range(NUM_ROOMS):
		var room_idx = i + 1
		var bridge_l = get_node_or_null("MapGeometry/Room" + str(room_idx) + "/BridgeLeft")
		var bridge_r = get_node_or_null("MapGeometry/Room" + str(room_idx) + "/BridgeRight")
		
		if bridge_l and bridge_r:
			if safe_paths[i] == 0:
				# Left is safe
				bridge_l.visible = true
				bridge_l.use_collision = true
				bridge_r.visible = false
				bridge_r.use_collision = false
			else:
				# Right is safe
				bridge_l.visible = false
				bridge_l.use_collision = false
				bridge_r.visible = true
				bridge_r.use_collision = true
				
		var trigger_l = get_node_or_null("Triggers/Room" + str(room_idx) + "_Left")
		var trigger_r = get_node_or_null("Triggers/Room" + str(room_idx) + "_Right")
		
		if trigger_l:
			trigger_l.body_entered.connect(_on_door_entered.bind(room_idx, 0))
		if trigger_r:
			trigger_r.body_entered.connect(_on_door_entered.bind(room_idx, 1))

func _on_door_entered(body: Node3D, room_idx: int, side: int) -> void:
	if not body is CharacterBody3D:
		return
		
	var door_id = str(room_idx) + "_" + str(side)
	if doors_opened.has(door_id):
		return
		
	doors_opened[door_id] = true
	
	var door_name = "DoorLeft" if side == 0 else "DoorRight"
	var door_visual = get_node_or_null("MapGeometry/Room" + str(room_idx) + "/" + door_name)
	
	if door_visual:
		# Simple open animation: move it down
		var tween = create_tween()
		tween.tween_property(door_visual, "position:y", door_visual.position.y - 6.0, 0.4)
		# Wait to disable collision so player doesn't walk through while it's moving
		tween.tween_callback(func(): door_visual.use_collision = false)
