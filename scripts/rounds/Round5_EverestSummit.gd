extends BaseRound

@export var wind_push: float = 18.0        # How hard wind pushes player downhill (+Z)
@export var wind_cycle_time: float = 6.0   # Seconds between gusts

var wind_active: bool = false
var wind_timer: float = 0.0
var safe_zones: Array[Area3D] = []
var player_ref: CharacterBody3D = null
var warning_label: Label = null

func _ready() -> void:
	super._ready()
	round_name = "ROUND 5: EVEREST SUMMIT"
	wind_timer = wind_cycle_time

	# Gather all safe zones (behind boulders = shelter)
	var sz_parent = get_node_or_null("SafeZones")
	if sz_parent:
		for child in sz_parent.get_children():
			if child is Area3D:
				safe_zones.append(child)

	# Create warning label on HUD after 1 second (HUD needs time to be ready)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if hud:
			warning_label = Label.new()
			warning_label.text = "⚠ BLIZZARD GUST! Take shelter! ⚠"
			warning_label.add_theme_font_size_override("font_size", 32)
			warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			warning_label.offset_top = 120
			warning_label.offset_bottom = 160
			hud.add_child(warning_label)
			warning_label.hide()
	)

func _process(delta: float) -> void:
	super._process(delta)

	# Find player lazily
	if not is_instance_valid(player_ref):
		if multiplayer.has_multiplayer_peer():
			player_ref = get_node_or_null(str(multiplayer.get_unique_id())) as CharacterBody3D
		else:
			player_ref = get_node_or_null("Player3D") as CharacterBody3D

	# Cycle wind on/off
	wind_timer -= delta
	if wind_timer <= 0.0:
		wind_active = not wind_active
		wind_timer = wind_cycle_time
		if warning_label:
			if wind_active:
				warning_label.show()
			else:
				warning_label.hide()

	# Apply wind by pushing player velocity (CharacterBody3D has no external_force)
	if wind_active and is_instance_valid(player_ref):
		var in_safe_zone := false
		for zone in safe_zones:
			if zone.overlaps_body(player_ref):
				in_safe_zone = true
				break

		if not in_safe_zone:
			# Directly nudge external_velocity — pushes player downhill (+Z direction)
			player_ref.external_velocity.z += wind_push
