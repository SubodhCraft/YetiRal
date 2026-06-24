extends Control

@onready var label_round_name: Label = %RoundNameLabel
@onready var label_timer: Label = %TimerLabel
@onready var progress_timer: ProgressBar = %TimerProgressBar
@onready var label_momo: Label = %MomoLabel
@onready var container_hearts: HBoxContainer = %HeartsContainer

const HEART_FULL: String = "❤️"

func set_round_name(name_str: String) -> void:
	if label_round_name:
		label_round_name.text = name_str.to_upper()

func update_timer(remaining: float, limit: float) -> void:
	if label_timer:
		var minutes = int(remaining) / 60
		var seconds = int(remaining) % 60
		label_timer.text = "%d:%02d" % [minutes, seconds]
		
	if progress_timer:
		progress_timer.max_value = limit
		progress_timer.value = remaining
		
		# Change progress bar color based on remaining time
		var ratio = remaining / limit
		var style: StyleBoxFlat = progress_timer.get_theme_stylebox("fill").duplicate()
		if style:
			if ratio < 0.25:
				style.bg_color = Color(0.9, 0.2, 0.2) # Urgent red
			elif ratio < 0.5:
				style.bg_color = Color(0.9, 0.6, 0.1) # Warning orange
			else:
				style.bg_color = Color(0.18, 0.8, 0.44) # Safe green
			progress_timer.add_theme_stylebox_override("fill", style)

func update_stats(lives: int, momos: int) -> void:
	# Update Momo counter
	if label_momo:
		label_momo.text = "🥟 %d" % momos
		
	# Update Hearts Container
	if container_hearts:
		# Clear existing heart labels
		for child in container_hearts.get_children():
			child.queue_free()
			
		# Add heart labels
		for i in range(max(0, lives)):
			var heart = Label.new()
			heart.text = HEART_FULL
			heart.add_theme_font_size_override("font_size", 32)
			container_hearts.add_child(heart)

func show_finished_message() -> void:
	if has_node("FinishedPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "FinishedPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.84, 0.0, 0.8) # Gold border
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "🏆 ROUND FINISHED!"
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "Waiting for other players..."
	sub_label.add_theme_font_size_override("font_size", 22)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	# Center it on the screen
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

func show_victory_message(xp_earned: int) -> void:
	if has_node("VictoryPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "VictoryPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.18, 0.8, 0.44, 0.9) # Safe green
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "🏆 ROUND VICTORY!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "+%d XP Earned" % xp_earned
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	# Center it on the screen
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

func show_time_up_message() -> void:
	if has_node("TimeUpPanel"):
		return
		
	var panel = PanelContainer.new()
	panel.name = "TimeUpPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.9, 0.2, 0.2, 0.9) # Urgent red
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "⏰ TIME'S UP!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var sub_label = Label.new()
	sub_label.text = "You ran out of time!"
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	# Center it on the screen
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
