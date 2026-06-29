extends CanvasLayer

## YetiFactScreen — shown after every round for 6 seconds.
## Call show_fact(index) from BaseRound after win/lose.

signal fact_dismissed

const FACTS: Array[Dictionary] = [
	{
		"title": "DID YOU KNOW? — The Name",
		"body": "The word 'Yeti' comes from the Sherpa phrase 'Yeh-Teh' meaning 'that thing there.' Sherpas have reported encounters for centuries, long before Western explorers ever set foot on the Himalayas.",
		"source": "— Himalayan Sherpa oral tradition"
	},
	{
		"title": "DID YOU KNOW? — The Footprints",
		"body": "In 1951, British explorer Eric Shipton photographed enormous footprints near Mount Everest — 13 inches long and 8 inches wide. Scientists and explorers have debated their origin ever since, and no definitive explanation has been found.",
		"source": "— Eric Shipton's Himalayan expedition, 1951"
	},
	{
		"title": "DID YOU KNOW? — Sacred Relics",
		"body": "The Yeti is considered sacred in Buddhist Himalayan culture. The Pangboche Monastery in Nepal claims to have kept a mummified Yeti hand and scalp for over 300 years, treated as holy artifacts.",
		"source": "— Pangboche Monastery, Khumbu region, Nepal"
	},
	{
		"title": "DID YOU KNOW? — Hillary & Tenzing",
		"body": "Sir Edmund Hillary and Tenzing Norgay, the first humans to summit Everest in 1953, both reported seeing large, unexplained tracks in the snow during their historic climb.",
		"source": "— The Hunt for the Abominable Snowman, 1960"
	},
	{
		"title": "DID YOU KNOW? — Many Names",
		"body": "In Nepal, the Yeti is called 'Meh-Teh' (Man-Bear) or 'Dzu-Teh' (Big Thing). Different Himalayan regions and ethnic groups each have their own ancient name and legend for this creature.",
		"source": "— Himalayan ethnography & folklore"
	},
	{
		"title": "DID YOU KNOW? — The DNA Study",
		"body": "A 2017 Oxford University DNA study tested hair, bones, and tissue samples labelled 'Yeti' from across Asia. Most results matched a rare ancient polar-brown bear hybrid — though many researchers say the mystery is still open.",
		"source": "— Oxford University, Royal Society Open Science, 2017"
	},
	{
		"title": "DID YOU KNOW? — Russia's Investigation",
		"body": "In 2011, the Russian government held an official international conference on the Yeti in Siberia's Kemerovo region. Participants announced they had found 'irrefutable evidence' of the creature's presence in local caves.",
		"source": "— Kemerovo Regional Administration, Russia, 2011"
	},
	{
		"title": "DID YOU KNOW? — Bipedal Tracks",
		"body": "Yeti footprints are consistently described as bipedal — two-footed, like a human — with five toes and no claw marks, unlike any known bear. This distinctive track pattern is a primary reason researchers continue to investigate.",
		"source": "— International Cryptozoology Museum records"
	},
	{
		"title": "DID YOU KNOW? — The $10,000 Permit",
		"body": "In 1959, the United States State Department issued formal regulations for Yeti hunting expeditions. Hunters needed a $10,000 government permit and were strictly forbidden from killing or harming the creature.",
		"source": "— U.S. State Department Foreign Affairs Manual, 1959"
	},
	{
		"title": "DID YOU KNOW? — Indian Army Sighting",
		"body": "In April 2019, the Indian Army's official Twitter account posted photographs of mysterious footprints — 32×15 inches — discovered near Makalu Base Camp in Nepal, reigniting worldwide interest in the Himalayan Yeti.",
		"source": "— Indian Army Additional Directorate General of Public Information, 2019"
	},
]

@onready var overlay: ColorRect = $Overlay
@onready var card: PanelContainer = $Overlay/Center/Card
@onready var yeti_emoji: Label = $Overlay/Center/Card/VBox/Margin/InnerVBox/YetiEmoji
@onready var title_label: Label = $Overlay/Center/Card/VBox/Margin/InnerVBox/TitleLabel
@onready var body_label: Label = $Overlay/Center/Card/VBox/Margin/InnerVBox/BodyLabel
@onready var source_label: Label = $Overlay/Center/Card/VBox/Margin/InnerVBox/SourceLabel
@onready var timer_bar: ProgressBar = $Overlay/Center/Card/VBox/Margin/InnerVBox/TimerBar
@onready var dismiss_label: Label = $Overlay/Center/Card/VBox/Margin/InnerVBox/DismissLabel

var _active: bool = false
var _continue_btn: Button = null

func _ready() -> void:
	layer = 10
	visible = false
	
	# Hide the auto-dismiss timer bar
	if timer_bar:
		timer_bar.visible = false
		
	# Create and style Continue button dynamically
	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(160, 42)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.48, 0.48) # Teal theme
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.corner_radius_bottom_left = 10
	_continue_btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.24, 0.6, 0.6)
	style_hover.corner_radius_top_left = 10
	style_hover.corner_radius_top_right = 10
	style_hover.corner_radius_bottom_right = 10
	style_hover.corner_radius_bottom_left = 10
	_continue_btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.12, 0.35, 0.35)
	style_pressed.corner_radius_top_left = 10
	style_pressed.corner_radius_top_right = 10
	style_pressed.corner_radius_bottom_right = 10
	style_pressed.corner_radius_bottom_left = 10
	_continue_btn.add_theme_stylebox_override("pressed", style_pressed)
	
	_continue_btn.pressed.connect(_dismiss)
	
	var container = $Overlay/Center/Card/VBox/Margin/InnerVBox
	if container:
		# Add continue button before the dismiss label
		container.add_child(_continue_btn)
		
	if dismiss_label:
		dismiss_label.text = "Click Continue or press SPACE to proceed"
		# Move dismiss label to the bottom of container
		if container:
			container.move_child(dismiss_label, container.get_child_count() - 1)

func show_fact(index: int) -> void:
	var fact_index: int = clampi(index, 0, FACTS.size() - 1)
	var fact: Dictionary = FACTS[fact_index]

	title_label.text = fact["title"]
	body_label.text  = fact["body"]
	source_label.text = fact["source"]

	visible = true
	overlay.modulate.a = 0.0
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.5)

	_active  = true
	if _continue_btn:
		_continue_btn.grab_focus() # Allow keyboard navigation right away

func _process(_delta: float) -> void:
	# Removed auto-dismiss timer logic as per requirements.
	pass

func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("ui_accept"):
		_dismiss()

func _dismiss() -> void:
	if not _active:
		return
	_active = false
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		visible = false
		fact_dismissed.emit()
	)
