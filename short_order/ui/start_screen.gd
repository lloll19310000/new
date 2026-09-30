extends Control
## The title screen: continue your saved diner or start a new one.

signal continue_pressed
signal new_pressed

var _t := 0.0

@onready var logo: Label = %Logo
@onready var continue_button: Button = %ContinueButton
@onready var new_button: Button = %NewButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	continue_button.pressed.connect(continue_pressed.emit)
	new_button.pressed.connect(new_pressed.emit)
	quit_button.pressed.connect(Sfx.quit_game)


func open(has_save: bool) -> void:
	continue_button.visible = has_save
	new_button.theme_type_variation = &"Button" if has_save else &"PrimaryButton"
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	logo.rotation = sin(_t * 1.3) * 0.015
	logo.pivot_offset = logo.size / 2.0
