class_name SettingsBox
extends VBoxContainer
## Sound and screen settings, shared by the main menu and the pause menu.
## They're kept between games (see Sfx.save_settings).

var volume: HSlider
var sound: CheckButton
var fullscreen: CheckButton
var size_buttons := {}


func _init() -> void:
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	sound = CheckButton.new()
	sound.text = "Sound"
	sound.button_pressed = Sfx.sound_on
	sound.toggled.connect(Sfx.set_sound_on)
	add_child(sound)
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 10)
	var vl := Label.new()
	vl.text = "Volume"
	vl.theme_type_variation = &"BodyLabel"
	vl.custom_minimum_size = Vector2(90, 0)
	vrow.add_child(vl)
	volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = Sfx.volume
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.value_changed.connect(Sfx.set_volume)
	vrow.add_child(volume)
	add_child(vrow)
	fullscreen = CheckButton.new()
	fullscreen.text = "Full screen"
	fullscreen.button_pressed = Sfx.fullscreen
	fullscreen.toggled.connect(Sfx.set_fullscreen)
	add_child(fullscreen)
	# how big the interface is drawn
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	var sl := Label.new()
	sl.text = "Interface"
	sl.theme_type_variation = &"BodyLabel"
	sl.custom_minimum_size = Vector2(90, 0)
	srow.add_child(sl)
	var group := ButtonGroup.new()
	for opt in Sfx.UI_SCALES:
		var b := Button.new()
		b.text = opt[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"SmallButton"
		b.button_pressed = is_equal_approx(Sfx.ui_scale, opt[0])
		var v: float = opt[0]
		b.pressed.connect(func(): Sfx.set_ui_scale(v))
		srow.add_child(b)
		size_buttons[v] = b
	add_child(srow)
	var note := Label.new()
	note.theme_type_variation = &"MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(200, 0)
	note.text = "Keys: Space pauses, 1 2 3 4 set the speed, R turns things, Tab hides the side panel, Esc opens this menu."
	add_child(note)


func refresh() -> void:
	if sound == null:
		return
	sound.set_pressed_no_signal(Sfx.sound_on)
	volume.set_value_no_signal(Sfx.volume)
	fullscreen.set_pressed_no_signal(Sfx.fullscreen)
	for v in size_buttons:
		size_buttons[v].set_pressed_no_signal(is_equal_approx(Sfx.ui_scale, v))
