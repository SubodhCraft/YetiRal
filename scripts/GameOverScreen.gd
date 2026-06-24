extends Control

@onready var label_momos: Label = %MomosCollectedLabel
@onready var btn_try_again: Button = %TryAgainBtn
@onready var btn_lobby: Button = %LobbyBtn

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if label_momos and GameManager:
		label_momos.text = "🥟 MOMOS COLLECTED: %d" % GameManager.momos
		
	if btn_try_again:
		btn_try_again.pressed.connect(_on_try_again_pressed)
	if btn_lobby:
		btn_lobby.pressed.connect(_on_lobby_pressed)

func _on_try_again_pressed() -> void:
	if GameManager:
		GameManager.start_game()

func _on_lobby_pressed() -> void:
	if GameManager:
		GameManager.return_to_dashboard()
