extends Area3D

@export var ROTATION_SPEED: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Spin the Momo coin
	rotate_y(ROTATION_SPEED * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if multiplayer.has_multiplayer_peer():
			if body.is_multiplayer_authority():
				rpc("collect_coin", multiplayer.get_unique_id())
		else:
			if GameManager:
				GameManager.add_momo(1)
			if AudioManager and AudioManager.has_method("play_momo_collect"):
				AudioManager.play_momo_collect()
			queue_free()

@rpc("any_peer", "call_local", "reliable")
func collect_coin(by_peer_id: int) -> void:
	if GameManager:
		if GameManager.has_method("add_momo_to_peer"):
			GameManager.add_momo_to_peer(by_peer_id, 1)
		else:
			GameManager.add_momo(1)
	if AudioManager and AudioManager.has_method("play_momo_collect"):
		AudioManager.play_momo_collect()
	queue_free()
