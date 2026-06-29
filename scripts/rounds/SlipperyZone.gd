## SlipperyZone.gd
## Represents a wet, muddy hazard zone near the Trishuli rapids.
## Attach this script to an Area3D node in the scene.
## When a Player or AI_Yeti walks into the zone, their friction is
## reduced dramatically, causing them to drift and slide uncontrollably.

class_name SlipperyZone
extends Area3D

## ─── EXPORTED TUNABLES ───────────────────────────────────────────────────────

## A multiplier in range [0..1]. Lower values = more slippery.
## 0.0 = perfect ice (no friction). 1.0 = no effect.
@export var slide_factor: float = 0.2

## ─── READY ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect the Area3D body signals to this script's handlers.
	# body_entered fires once when a PhysicsBody enters the overlapping volume.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## ─── SIGNAL HANDLERS ─────────────────────────────────────────────────────────

## Called once when any PhysicsBody3D enters this zone's collision shape.
func _on_body_entered(body: Node3D) -> void:
	# Only affect bodies in the "Player" or "AI_Yeti" group.
	# This prevents mud rocks from slowing down boulders or rafts.
	if body.is_in_group("Player") or body.is_in_group("AI_Yeti"):
		# Check the body actually implements the slippery interface.
		# Using has_method avoids hard coupling between scripts.
		if body.has_method("apply_slippery_effect"):
			body.apply_slippery_effect(slide_factor)

## Called once when any PhysicsBody3D leaves this zone's collision shape.
func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") or body.is_in_group("AI_Yeti"):
		if body.has_method("remove_slippery_effect"):
			body.remove_slippery_effect()
